import fetch from "node-fetch";
import { randomUUID } from "crypto";
import { normalizeArtist, normalizeTitle } from "../utils/trackNormalization";
import { Song } from "../types/song";

interface MusicBrainzArtistCredit {
  name?: string;
  artist?: {
    id?: string;
    name?: string;
    sortName?: string;
  };
}

interface MusicBrainzRelease {
  title?: string;
  date?: string;
}

interface MusicBrainzRecording {
  id: string;
  title?: string;
  length?: number;
  disambiguation?: string;
  "artist-credit"?: Array<MusicBrainzArtistCredit | string>;
  releases?: MusicBrainzRelease[];
  isrcs?: string[];
}

interface QueryContext {
  normalized: string;
  tokens: string[];
  versionKeywords: Set<string>;
}

const MUSICBRAINZ_BASE_URL = "https://musicbrainz.org/ws/2/recording";
const MUSICBRAINZ_FETCH_ERROR = "MUSICBRAINZ_FETCH_ERROR";
const CACHE_TTL_MS = 10 * 60 * 1000; // 10 minutes
const RATE_LIMIT_INTERVAL_MS = 1000; // 1 request per second
const RESULT_LIMIT = 10;
const SOURCE: Song["source"] = "MUSICBRAINZ";

const VERSION_KEYWORDS = ["live", "remix", "remaster", "acoustic"];

const cache = new Map<string, { expiresAt: number; results: Song[] }>();
let lastRequestAt = 0;

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

const normalizeQuery = (value: string): string => value.toLowerCase().replace(/\s+/g, " ").trim();

const tokensFrom = (value: string): string[] =>
  normalizeQuery(value)
    .split(" ")
    .filter(Boolean);

const detectVersionKeyword = (value: string | undefined): string | null => {
  if (!value) return null;
  const lower = value.toLowerCase();
  for (const keyword of VERSION_KEYWORDS) {
    if (lower.includes(keyword)) {
      return keyword;
    }
  }
  return null;
};

const extractPrimaryArtist = (credits: Array<MusicBrainzArtistCredit | string> | undefined): string | null => {
  if (!credits || credits.length === 0) return null;
  const first = credits[0];
  if (typeof first === "string") {
    return first;
  }
  return first.name || first.artist?.name || null;
};

const extractAlbum = (releases: MusicBrainzRelease[] | undefined): { album?: string; year?: number } => {
  if (!releases || releases.length === 0) return {};
  const release = releases.find((rel) => Boolean(rel.title)) ?? releases[0];
  const album = release.title?.trim();

  const date = release.date || "";
  const yearMatch = date.match(/^(\d{4})/);
  const year = yearMatch ? Number(yearMatch[1]) : undefined;

  return { album, year };
};

const stripArtistFromQuery = (query: string, normalizedArtist: string): string => {
  if (!normalizedArtist) return query;
  const withoutArtist = query.replace(normalizedArtist, "").replace(/\s+/g, " ").trim();
  if (withoutArtist.length > 0) return withoutArtist;

  const artistTokens = new Set(normalizedArtist.split(" "));
  const remainingTokens = tokensFrom(query).filter((token) => !artistTokens.has(token));
  return remainingTokens.join(" ");
};

const computeTokenOverlap = (aTokens: string[], bTokens: string[]): number => {
  if (aTokens.length === 0 || bTokens.length === 0) return 0;
  const aSet = new Set(aTokens);
  const bSet = new Set(bTokens);
  let overlap = 0;
  for (const token of aSet) {
    if (bSet.has(token)) overlap += 1;
  }
  return overlap / Math.max(aTokens.length, bTokens.length);
};

const computeTitleScore = (normalizedTitle: string, query: string, queryTokens: string[]): number => {
  if (!normalizedTitle || !query) return 0;
  if (normalizedTitle === query) return 40;
  if (normalizedTitle.startsWith(query)) return 30;

  const titleTokens = normalizedTitle.split(" ").filter(Boolean);
  const overlap = computeTokenOverlap(titleTokens, queryTokens);
  if (overlap >= 0.7) return 20;
  return 0;
};

const computeArtistScore = (normalizedArtist: string, query: string, queryTokens: string[]): number => {
  if (!normalizedArtist) return 0;
  if (query.includes(normalizedArtist)) return 30;

  const artistTokens = normalizedArtist.split(" ").filter(Boolean);
  const overlap = computeTokenOverlap(artistTokens, queryTokens);
  if (overlap >= 0.5) return 20;
  return 0;
};

const computeQualityScore = (versionKeyword: string | null, queryHasVersionKeyword: boolean): number => {
  if (!versionKeyword) return 20;
  return queryHasVersionKeyword ? 10 : 0;
};

const computeMetadataConfidence = (hasRelease: boolean, hasYear: boolean, hasIsrc: boolean): number => {
  let score = 0;
  if (hasRelease && hasYear) score += 5;
  if (hasIsrc) score += 5;
  return score;
};

const ensureRateLimit = async () => {
  const elapsed = Date.now() - lastRequestAt;
  if (elapsed < RATE_LIMIT_INTERVAL_MS) {
    await sleep(RATE_LIMIT_INTERVAL_MS - elapsed);
  }
  lastRequestAt = Date.now();
};

const fetchRecordings = async (query: string): Promise<MusicBrainzRecording[]> => {
  await ensureRateLimit();

  try {
    const url = new URL(MUSICBRAINZ_BASE_URL);
    url.searchParams.set("query", query);
    url.searchParams.set("fmt", "json");
    url.searchParams.set("limit", "25");

    const response = await fetch(url.toString(), {
      headers: {
        "User-Agent": "VibeIt/1.0 (contact@vibeit.app)",
      },
    });

    if (!response.ok) {
      throw new Error(`${MUSICBRAINZ_FETCH_ERROR}:status_${response.status}`);
    }

    const data = (await response.json()) as { recordings?: MusicBrainzRecording[] };
    return data.recordings ?? [];
  } catch (error) {
    const reason = error instanceof Error ? error.message : "unknown";
    throw new Error(`${MUSICBRAINZ_FETCH_ERROR}:${reason}`);
  }
};

const buildQueryContext = (query: string): QueryContext => {
  const normalized = normalizeQuery(query);
  const tokens = tokensFrom(query);
  const versionKeywords = new Set<string>();

  for (const token of tokens) {
    if (VERSION_KEYWORDS.includes(token)) {
      versionKeywords.add(token);
    }
  }

  return { normalized, tokens, versionKeywords };
};

const mapRecordingToSong = (recording: MusicBrainzRecording, context: QueryContext): { song: Song; score: number } | null => {
  const title = (recording.title || "").trim();
  const primaryArtist = extractPrimaryArtist(recording["artist-credit"]);

  if (!title || !primaryArtist) {
    return null;
  }

  const versionKeyword = detectVersionKeyword(recording.title) || detectVersionKeyword(recording.disambiguation);
  const queryHasVersion = context.versionKeywords.size > 0;

  if (versionKeyword && !queryHasVersion) {
    return null;
  }

  const normalizedTitle = normalizeTitle(title);
  const normalizedArtist = normalizeArtist(primaryArtist);

  const queryTitlePortion = stripArtistFromQuery(context.normalized, normalizedArtist);
  const queryTokens = tokensFrom(queryTitlePortion || context.normalized);

  const titleScore = computeTitleScore(normalizedTitle, queryTitlePortion || context.normalized, queryTokens);
  const artistScore = computeArtistScore(normalizedArtist, context.normalized, context.tokens);
  const qualityScore = computeQualityScore(versionKeyword, queryHasVersion);

  const { album, year } = extractAlbum(recording.releases);
  const hasRelease = Boolean(album);
  const hasYear = typeof year === "number";
  const hasIsrc = Array.isArray(recording.isrcs) && recording.isrcs.length > 0;

  const metadataScore = computeMetadataConfidence(hasRelease, hasYear, hasIsrc);
  const totalScore = titleScore + artistScore + qualityScore + metadataScore;

  if (totalScore < 60) {
    return null;
  }

  const durationSeconds = recording.length ? Math.max(1, Math.round(recording.length / 1000)) : undefined;

  const song: Song = {
    id: randomUUID(),
    title,
    normalizedTitle,
    primaryArtist,
    normalizedArtist,
    album,
    year,
    source: SOURCE,
    musicBrainzRecordingId: recording.id,
    durationSeconds,
  };

  return { song, score: totalScore };
};

export const searchSongs = async (query: string): Promise<Song[]> => {
  const normalizedQuery = normalizeQuery(query);
  if (!normalizedQuery) return [];

  const cached = cache.get(normalizedQuery);
  const now = Date.now();
  if (cached && cached.expiresAt > now) {
    return cached.results;
  }

  const recordings = await fetchRecordings(query);
  const context = buildQueryContext(query);

  const scoredSongs: Array<{ song: Song; score: number }> = [];
  for (const recording of recordings) {
    const mapped = mapRecordingToSong(recording, context);
    if (mapped) scoredSongs.push(mapped);
  }

  scoredSongs.sort((a, b) => b.score - a.score);

  const results = scoredSongs.slice(0, RESULT_LIMIT).map((item) => item.song);
  cache.set(normalizedQuery, { expiresAt: now + CACHE_TTL_MS, results });
  return results;
};
