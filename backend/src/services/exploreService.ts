import fetch from "node-fetch";
import { randomUUID } from "crypto";
import env from "../config/env";
import Playlist, { ITrack } from "../models/Playlist";
import SpotifyPlaylist from "../models/SpotifyPlaylist";
import YtmPlaylist from "../models/YtmPlaylist";
import { searchSongs, Song } from "./musicbrainzService";
import { normalizeArtist, normalizeTitle, normalizeTrack, trackKey } from "../utils/trackNormalization";

const DAILY_CACHE_MS = 24 * 60 * 60 * 1000;
const MAX_IMPORTED_TRACKS = 250;
const MAX_SECTION_RESULTS = 24;

interface ExploreSection {
  title: string;
  subtitle?: string;
  songs: Song[];
}

interface LanguageSection extends ExploreSection {
  language: string;
  confidence: number;
}

interface Cached<T> {
  expiresAt: number;
  data: T;
}

const cache: Record<string, Cached<ExploreSection | LanguageSection[] | null> | undefined> = {};
const resolutionCache = new Map<string, { expiresAt: number; song: Song | null }>();

const cacheGetOrLoad = async <T>(key: string, loader: () => Promise<T>): Promise<T> => {
  const now = Date.now();
  const hit = cache[key] as Cached<T> | undefined;
  if (hit && hit.expiresAt > now) {
    return hit.data;
  }

  const data = await loader();
  cache[key] = { data: data as unknown as ExploreSection | LanguageSection[] | null, expiresAt: now + DAILY_CACHE_MS };
  return data;
};

const dedupeByRecordingId = (songs: Song[]): Song[] => {
  const seen = new Set<string>();
  const unique: Song[] = [];
  for (const song of songs) {
    const key = song.musicBrainzRecordingId;
    if (!key) continue;
    if (seen.has(key)) continue;
    seen.add(key);
    unique.push(song);
  }
  return unique;
};

const clampSection = (songs: Song[]): Song[] => songs.slice(0, MAX_SECTION_RESULTS);

const buildSongFromTrack = (track: ITrack): Song | null => {
  if (!track.musicBrainzRecordingId) return null;

  const normalizedTitle = track.normalizedTitle || normalizeTitle(track.title);
  const normalizedArtist = track.normalizedArtist || normalizeArtist(track.artist);
  const durationSeconds = Number.isFinite(track.duration)
    ? Math.max(1, Math.round(Number(track.duration)))
    : undefined;

  return {
    id: track.musicBrainzRecordingId,
    title: track.title,
    normalizedTitle,
    primaryArtist: track.artist,
    normalizedArtist,
    album: track.album || undefined,
    year: undefined,
    durationSeconds,
    musicBrainzRecordingId: track.musicBrainzRecordingId,
    source: "MUSICBRAINZ",
  };
};

const resolveTrackToSong = async (
  title: string,
  artist: string | null,
  album?: string | null
): Promise<Song | null> => {
  const normalized = normalizeTrack(title, artist || "");
  const key = trackKey(normalized);
  const now = Date.now();
  const cached = resolutionCache.get(key);
  if (cached && cached.expiresAt > now) {
    return cached.song;
  }

  const query = `${title} ${artist ?? ""}`.trim();
  if (!query) {
    resolutionCache.set(key, { song: null, expiresAt: now + DAILY_CACHE_MS });
    return null;
  }

  const results = await searchSongs(query);
  const match =
    results.find((song) =>
      song.normalizedTitle === normalized.normalizedTitle &&
      song.normalizedArtist === normalized.normalizedArtist
    ) ||
    results.find((song) => song.normalizedTitle === normalized.normalizedTitle) ||
    results[0];

  if (!match) {
    resolutionCache.set(key, { song: null, expiresAt: now + DAILY_CACHE_MS });
    return null;
  }

  const resolved: Song = {
    ...match,
    id: match.musicBrainzRecordingId || match.id || randomUUID(),
    album: match.album ?? album ?? undefined,
    source: "MUSICBRAINZ",
  };

  resolutionCache.set(key, { song: resolved, expiresAt: now + DAILY_CACHE_MS });
  return resolved;
};

const loadInternalSongs = async (): Promise<{ songs: Song[]; recent: Array<{ song: Song; addedAt: Date }> }> => {
  const playlists = await Playlist.find().select("tracks createdAt updatedAt");
  const songs: Song[] = [];
  const recent: Array<{ song: Song; addedAt: Date }> = [];

  for (const playlist of playlists) {
    for (const track of playlist.tracks) {
      const song = buildSongFromTrack(track);
      if (!song) continue;
      songs.push(song);

      const addedAt = track.createdAt || playlist.updatedAt || playlist.createdAt;
      if (addedAt) {
        recent.push({ song, addedAt });
      }
    }
  }

  return { songs, recent };
};

const loadImportedSongs = async (): Promise<Song[]> => {
  const songs: Song[] = [];
  let attempts = 0;

  const spotifyPlaylists = await SpotifyPlaylist.find().select("tracks");
  for (const playlist of spotifyPlaylists) {
    for (const track of playlist.tracks) {
      if (attempts >= MAX_IMPORTED_TRACKS) return dedupeByRecordingId(songs);
      attempts += 1;
      const resolved = await resolveTrackToSong(track.name, track.artist ?? null);
      if (resolved) songs.push(resolved);
    }
  }

  const ytmPlaylists = await YtmPlaylist.find().select("tracks");
  for (const playlist of ytmPlaylists) {
    for (const track of playlist.tracks) {
      if (attempts >= MAX_IMPORTED_TRACKS) return dedupeByRecordingId(songs);
      attempts += 1;
      const resolved = await resolveTrackToSong(track.title, track.artist, track.title);
      if (resolved) songs.push(resolved);
    }
  }

  return dedupeByRecordingId(songs);
};

const fetchLastFmTopTracks = async (): Promise<Array<{ title: string; artist: string }>> => {
  if (!env.lastfmApiKey) return [];

  try {
    const url = new URL("https://ws.audioscrobbler.com/2.0/");
    url.searchParams.set("method", "chart.gettoptracks");
    url.searchParams.set("api_key", env.lastfmApiKey);
    url.searchParams.set("format", "json");
    url.searchParams.set("limit", "50");

    const resp = await fetch(url.toString());
    if (!resp.ok) return [];
    const data = (await resp.json()) as { tracks?: { track?: Array<{ name?: string; artist?: { name?: string } }> } };
    const list = data.tracks?.track ?? [];
    return list
      .map((item) => ({
        title: (item.name || "").trim(),
        artist: (item.artist?.name || "").trim(),
      }))
      .filter((item) => item.title && item.artist);
  } catch (error) {
    console.error("[explore] failed to fetch Last.fm top tracks", error);
    return [];
  }
};

const getPopularOnVibeit = async (): Promise<ExploreSection | null> => {
  return cacheGetOrLoad("popular", async () => {
    const { songs: internalSongs } = await loadInternalSongs();
    const importedSongs = await loadImportedSongs();
    const allSongs = [...internalSongs, ...importedSongs].filter((song) => song.musicBrainzRecordingId);

    if (allSongs.length === 0) return null;

    const counts = new Map<string, { song: Song; count: number }>();
    for (const song of allSongs) {
      const key = song.musicBrainzRecordingId;
      if (!key) continue;
      const existing = counts.get(key) ?? { song, count: 0 };
      counts.set(key, { song: existing.song, count: existing.count + 1 });
    }

    const sorted = Array.from(counts.values())
      .sort((a, b) => b.count - a.count)
      .map((entry) => entry.song);

    return {
      title: "Popular on VibeIt",
      subtitle: "Most saved across playlists and imports (daily cache)",
      songs: clampSection(dedupeByRecordingId(sorted)),
    };
  });
};

const getRecentlyAdded = async (): Promise<ExploreSection | null> => {
  return cacheGetOrLoad("recent", async () => {
    const { recent } = await loadInternalSongs();
    if (recent.length === 0) return null;

    const sorted = recent
      .filter((entry) => entry.song.musicBrainzRecordingId)
      .sort((a, b) => (b.addedAt?.getTime() || 0) - (a.addedAt?.getTime() || 0))
      .map((entry) => entry.song);

    return {
      title: "Recently added",
      subtitle: "Latest songs saved inside VibeIt",
      songs: clampSection(dedupeByRecordingId(sorted)),
    };
  });
};

const getTrendingWorldwide = async (): Promise<ExploreSection | null> => {
  return cacheGetOrLoad("trending", async () => {
    const topTracks = await fetchLastFmTopTracks();
    if (topTracks.length === 0) return null;

    const resolved: Song[] = [];
    for (const track of topTracks) {
      const song = await resolveTrackToSong(track.title, track.artist);
      if (song) resolved.push(song);
    }

    const songs = clampSection(dedupeByRecordingId(resolved));
    if (songs.length === 0) return null;

    return {
      title: "Trending worldwide",
      subtitle: "Resolved from Last.fm top tracks",
      songs,
    };
  });
};

const SCRIPT_PATTERNS: Record<string, RegExp> = {
  devanagari: /[\u0900-\u097F]/u,
  cyrillic: /[\u0400-\u04FF]/u,
  arabic: /[\u0600-\u06FF]/u,
  hangul: /[\u1100-\u11FF\u3130-\u318F\uAC00-\uD7AF]/u,
  hiragana: /[\u3040-\u309F]/u,
  katakana: /[\u30A0-\u30FF]/u,
};

const LANGUAGE_LABELS: Record<string, { title: string; subtitle: string }> = {
  devanagari: { title: "Language picks: Hindi", subtitle: "Best-effort based on script" },
  cyrillic: { title: "Language picks: Cyrillic", subtitle: "Best-effort based on script" },
  arabic: { title: "Language picks: Arabic", subtitle: "Best-effort based on script" },
  hangul: { title: "Language picks: Korean", subtitle: "Best-effort based on script" },
  hiragana: { title: "Language picks: Japanese", subtitle: "Best-effort based on script" },
  katakana: { title: "Language picks: Japanese", subtitle: "Best-effort based on script" },
};

const detectScriptConfidence = (value: string): { script: string | null; confidence: number } => {
  const clean = value.replace(/[^\p{L}\s]/gu, "");
  const totalChars = clean.length || 1;
  let bestScript: string | null = null;
  let bestScore = 0;

  for (const [script, pattern] of Object.entries(SCRIPT_PATTERNS)) {
    const flags = pattern.flags.includes("g") ? pattern.flags : `${pattern.flags}g`;
    const regex = new RegExp(pattern.source, flags.includes("u") ? flags : `${flags}u`);
    const matches = clean.match(regex) ?? [];
    const score = matches.length / totalChars;
    if (score > bestScore) {
      bestScore = score;
      bestScript = script;
    }
  }

  return { script: bestScript, confidence: bestScore };
};

const getLanguagePicks = async (seeds: Song[]): Promise<LanguageSection[] | null> => {
  return cacheGetOrLoad("language-picks", async () => {
    const buckets = new Map<string, { songs: Song[]; confidence: number[] }>();

    for (const song of seeds) {
      const text = `${song.title} ${song.primaryArtist}`;
      const { script, confidence } = detectScriptConfidence(text);
      if (!script || confidence < 0.35) continue;
      const bucket = buckets.get(script) ?? { songs: [], confidence: [] };
      if (!bucket.songs.find((s) => s.musicBrainzRecordingId === song.musicBrainzRecordingId)) {
        bucket.songs.push(song);
        bucket.confidence.push(confidence);
      }
      buckets.set(script, bucket);
    }

    const sections: LanguageSection[] = [];
    for (const [script, bucket] of buckets.entries()) {
      if (bucket.songs.length < 4) continue;
      const label = LANGUAGE_LABELS[script];
      if (!label) continue;
      const confidence = bucket.confidence.reduce((a, b) => a + b, 0) / bucket.confidence.length;
      sections.push({
        title: label.title,
        subtitle: `${label.subtitle}; may be imperfect`,
        language: script,
        confidence: Number(confidence.toFixed(2)),
        songs: clampSection(bucket.songs),
      });
    }

    if (sections.length === 0) return null;
    return sections;
  });
};

export interface ExplorePayload {
  popular?: ExploreSection | null;
  recent?: ExploreSection | null;
  trendingWorldwide?: ExploreSection | null;
  languagePicks?: LanguageSection[] | null;
}

export const getExplorePayload = async (): Promise<ExplorePayload> => {
  const [popular, recent, trending] = await Promise.all([
    getPopularOnVibeit(),
    getRecentlyAdded(),
    getTrendingWorldwide(),
  ]);

  const seeds = dedupeByRecordingId([
    ...(popular?.songs ?? []),
    ...(recent?.songs ?? []),
    ...(trending?.songs ?? []),
  ]);

  const languagePicks = seeds.length === 0 ? null : await getLanguagePicks(seeds);

  return {
    popular,
    recent,
    trendingWorldwide: trending,
    languagePicks,
  };
};
