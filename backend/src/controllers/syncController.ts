import { Request, Response, NextFunction } from "express";
import { Types } from "mongoose";
import SpotifyAccount from "../models/SpotifyAccount";
import SpotifyPlaylist from "../models/SpotifyPlaylist";
import YtmAccount from "../models/YtmAccount";
import YtmPlaylist from "../models/YtmPlaylist";
import {
  addTracksToSpotifyPlaylist,
  fetchSpotifyPlaylistWithTracks,
  removeTracksFromSpotifyPlaylist,
  searchSpotifyTrackExact,
  SpotifyScopeLevel,
  SpotifyTokenExpiredError,
  refreshAccessToken as refreshSpotifyAccessToken,
} from "../utils/spotify";
import {
  YtmScopeLevel,
  YtmTokenExpiredError,
  addTracksToYtmPlaylist,
  fetchYtmPlaylistWithTracks,
  removeTracksFromYtmPlaylist,
  searchYtmTrackExact,
  refreshAccessToken as refreshYtmAccessToken,
} from "../utils/ytm";
import {
  normalizeTrack,
  trackKey,
  NormalizedTrackData,
  VersionKeyword,
} from "../utils/trackNormalization";
import { updateArtistFrequency } from "../utils/trackResolver";

// Standardized skip reasons
export type SkipReason =
  | "NO_MATCH"           // No candidate scored above threshold
  | "ALREADY_PRESENT"    // Track already in destination
  | "SEARCH_FAILED"      // API search error
  | "RATE_LIMITED";      // API rate limit hit

interface NormalizedTrack {
  title: string;
  artist: string;
  normalizedTitle: string;
  normalizedArtist: string;
  versionKeyword: VersionKeyword;
  trackKey: string;
}

type Direction = "SPOTIFY_TO_YTM" | "YTM_TO_SPOTIFY";

type CaseLabel = "EQUAL" | "SUBSET" | "SUPERSET" | "PARTIAL";

type Mode = "APPEND_ONLY" | "FULL_SYNC";

const toPublicTrack = (track: NormalizedTrack) => ({ title: track.title, artist: track.artist });

const computeCase = (toAdd: NormalizedTrack[], toRemove: NormalizedTrack[]): CaseLabel => {
  if (toAdd.length === 0 && toRemove.length === 0) return "EQUAL";
  if (toAdd.length > 0 && toRemove.length === 0) return "SUBSET";
  if (toAdd.length === 0 && toRemove.length > 0) return "SUPERSET";
  return "PARTIAL";
};

const ensureLinked = async (userId: string) => {
  const spotify = await SpotifyAccount.findOne({ userId });
  const ytm = await YtmAccount.findOne({ userId });
  if (!spotify || !ytm) {
    const err = new Error("Both Spotify and YouTube Music must be connected");
    // Mark as auth-related to return 401 downstream
    // @ts-expect-error custom flag
    err.status = 401;
    throw err;
  }
  return { spotify, ytm };
};

const findPlaylistIdsByName = async (userId: string, playlistName: string) => {
  const userObjectId = new Types.ObjectId(userId);
  const spotify = await SpotifyPlaylist.findOne({ userId: userObjectId, name: playlistName });
  const ytm = await YtmPlaylist.findOne({ userId: userObjectId, name: playlistName });
  return { spotifyId: spotify?.spotifyPlaylistId || null, ytmId: ytm?.ytmPlaylistId || null };
};

const ensureSpotifyAccessToken = async (userId: string) => {
  const account = await SpotifyAccount.findOne({ userId });
  if (!account) {
    const err = new Error("Spotify account not linked");
    // @ts-expect-error add status for upstream handling
    err.status = 401;
    throw err;
  }

  const expiresSoon = account.expiresAt.getTime() <= Date.now() + 60_000;
  if (!expiresSoon) return account.accessToken;

  try {
    const refreshed = await refreshSpotifyAccessToken(account.refreshToken);
    account.accessToken = refreshed.accessToken;
    account.refreshToken = refreshed.refreshToken || account.refreshToken;
    account.expiresAt = new Date(Date.now() + refreshed.expiresIn * 1000);
    await account.save();
    return account.accessToken;
  } catch (error) {
    console.error("[sync][spotify] token refresh failed", error);
    const err = new Error("Please reconnect Spotify");
    // @ts-expect-error add status for upstream handling
    err.status = 401;
    throw err;
  }
};

const ensureYtmAccessToken = async (userId: string) => {
  const account = await YtmAccount.findOne({ userId });
  if (!account) {
    const err = new Error("YouTube Music account not linked");
    // @ts-expect-error add status for upstream handling
    err.status = 401;
    throw err;
  }

  const expiresSoon = account.expiresAt.getTime() <= Date.now() + 60_000;
  if (!expiresSoon) return account.accessToken;

  try {
    const refreshed = await refreshYtmAccessToken(account.refreshToken);
    account.accessToken = refreshed.accessToken;
    account.refreshToken = refreshed.refreshToken || account.refreshToken;
    account.expiresAt = new Date(Date.now() + refreshed.expiresIn * 1000);
    await account.save();
    return account.accessToken;
  } catch (error) {
    console.error("[sync][ytm] token refresh failed", error);
    const err = new Error("Please reconnect YouTube Music");
    // @ts-expect-error add status for upstream handling
    err.status = 401;
    throw err;
  }
};

const getTrackSets = async (
  userId: string,
  direction: Direction,
  spotifyAccessToken: string,
  ytmAccessToken: string,
  spotifyPlaylistId: string,
  ytmPlaylistId: string
) => {
  const [spotifyPlaylist, ytmPlaylist] = await Promise.all([
    fetchSpotifyPlaylistWithTracks(spotifyAccessToken, spotifyPlaylistId),
    fetchYtmPlaylistWithTracks(ytmAccessToken, ytmPlaylistId),
  ]);

  // Update artist frequency cache for intelligent artist identification
  const allArtists: string[] = [];
  for (const t of spotifyPlaylist.tracks) {
    allArtists.push(...t.artists);
  }
  for (const t of ytmPlaylist.tracks) {
    if (t.artist) allArtists.push(t.artist);
  }
  updateArtistFrequency(userId, allArtists);

  const spotifyTracks: NormalizedTrack[] = spotifyPlaylist.tracks
    .map((t) => {
      const normalized = normalizeTrack(t.title, t.artists[0] || "");
      return {
        title: t.title,
        artist: t.artists[0] || "",
        normalizedTitle: normalized.normalizedTitle,
        normalizedArtist: normalized.normalizedArtist,
        versionKeyword: normalized.versionKeyword,
        trackKey: trackKey(normalized),
      };
    })
    .filter((t) => t.normalizedTitle && t.normalizedArtist);

  const ytmTracks: NormalizedTrack[] = ytmPlaylist.tracks
    .map((t) => {
      const normalized = normalizeTrack(t.title, t.artist || "");
      return {
        title: t.title,
        artist: t.artist || "",
        normalizedTitle: normalized.normalizedTitle,
        normalizedArtist: normalized.normalizedArtist,
        versionKeyword: normalized.versionKeyword,
        trackKey: trackKey(normalized),
      };
    })
    .filter((t) => t.normalizedTitle && t.normalizedArtist);

  const source = direction === "SPOTIFY_TO_YTM" ? spotifyTracks : ytmTracks;
  const dest = direction === "SPOTIFY_TO_YTM" ? ytmTracks : spotifyTracks;

  const destSet = new Set(dest.map((t) => t.trackKey));
  const sourceSet = new Set(source.map((t) => t.trackKey));

  const common = source.filter((t) => destSet.has(t.trackKey));
  const toAdd = source.filter((t) => !destSet.has(t.trackKey));
  const toRemove = dest.filter((t) => !sourceSet.has(t.trackKey));

  return { common, toAdd, toRemove, spotifyPlaylist, ytmPlaylist, destSet };
};

export const previewSync = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    const { playlistName, direction } = req.body as { playlistName?: string; direction?: Direction };

    if (!userId) return res.status(401).json({ error: "Unauthorized" });
    if (!playlistName || !direction) return res.status(400).json({ error: "playlistName and direction are required" });

    const { spotify, ytm } = await ensureLinked(userId);
    const spotifyAccessToken = await ensureSpotifyAccessToken(userId);
    const ytmAccessToken = await ensureYtmAccessToken(userId);
    const { spotifyId, ytmId } = await findPlaylistIdsByName(userId, playlistName);

    if (!spotifyId || !ytmId) {
      return res.status(400).json({ error: "Playlist name must exist on both platforms" });
    }

    const { common, toAdd, toRemove, spotifyPlaylist, ytmPlaylist } = await getTrackSets(
      userId,
      direction,
      spotifyAccessToken,
      ytmAccessToken,
      spotifyId,
      ytmId
    );

    const sourceCount = direction === "SPOTIFY_TO_YTM" ? spotifyPlaylist.tracks.length : ytmPlaylist.tracks.length;
    const destinationCount = direction === "SPOTIFY_TO_YTM" ? ytmPlaylist.tracks.length : spotifyPlaylist.tracks.length;
    console.info("[sync][preview] counts", {
      direction,
      sourceCount,
      destinationCount,
      toAdd: toAdd.length,
      toRemove: toRemove.length,
    });

    const catalogResolvedAdds: NormalizedTrack[] = [];
    const skippedTracks: Array<{ title: string; artist: string; reason: string; normalizedTitle: string }> = [];

    for (const track of toAdd) {
      const matchId =
        direction === "SPOTIFY_TO_YTM"
          ? await searchYtmTrackExact(ytmAccessToken, track.title, track.artist)
          : await searchSpotifyTrackExact(spotifyAccessToken, track.title, track.artist);

      if (matchId) {
        catalogResolvedAdds.push(track);
      } else {
        skippedTracks.push({
          title: track.title,
          artist: track.artist,
          normalizedTitle: track.normalizedTitle,
          reason: "NO_MATCH" as SkipReason,
        });
        console.warn("[sync][preview] skip no exact match", {
          title: track.title,
          normalizedTitle: track.normalizedTitle,
          artist: track.artist,
        });
      }
    }

    console.info("[sync][preview] catalog resolution", {
      matches: catalogResolvedAdds.length,
      skipped: skippedTracks.length,
    });

    const caseLabel = computeCase(toAdd, toRemove);

    return res.json({
      case: caseLabel,
      note: "Tracks will be searched in the destination platform catalog before adding.",
      summary: {
        sourceCount,
        destinationCount,
        toAddCount: toAdd.length,
        toRemoveCount: toRemove.length,
        catalogMatches: catalogResolvedAdds.length,
        catalogSkips: skippedTracks.length,
      },

      common: common.map(toPublicTrack),
      // Candidates needing catalog resolution (diff result)
      toAddCandidates: toAdd.map(toPublicTrack),
      // Tracks that matched a catalog entry and would be added
      toAdd: catalogResolvedAdds.map(toPublicTrack),
      toRemove: toRemove.map(toPublicTrack),
      catalogResolvedAdds: catalogResolvedAdds.map(toPublicTrack),
      skippedTracks,
    });
  } catch (error) {
    if ((error as any)?.status === 401) {
      return res.status(401).json({ error: (error as Error).message });
    }
    if (error instanceof SpotifyTokenExpiredError || error instanceof YtmTokenExpiredError) {
      return res.status(401).json({ error: error.message });
    }
    return next(error);
  }
};

export const executeSync = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    const { playlistName, direction, mode } = req.body as {
      playlistName?: string;
      direction?: Direction;
      mode?: Mode;
    };

    if (!userId) return res.status(401).json({ error: "Unauthorized" });
    if (!playlistName || !direction || !mode) {
      return res.status(400).json({ error: "playlistName, direction, and mode are required" });
    }

    const { spotify, ytm } = await ensureLinked(userId);
    const spotifyAccessToken = await ensureSpotifyAccessToken(userId);
    const ytmAccessToken = await ensureYtmAccessToken(userId);

    // Guard scope
    const hasWrite = direction === "SPOTIFY_TO_YTM" ? ytm.scopeLevel === "WRITE" : spotify.scopeLevel === "WRITE";
    if (!hasWrite) {
      return res.status(403).json({ error: "Write access required. Manage access from Profile." });
    }

    const { spotifyId, ytmId } = await findPlaylistIdsByName(userId, playlistName);
    if (!spotifyId || !ytmId) {
      return res.status(400).json({ error: "Playlist name must exist on both platforms" });
    }

    const { toAdd, toRemove, spotifyPlaylist, ytmPlaylist, destSet } = await getTrackSets(
      userId,
      direction,
      spotifyAccessToken,
      ytmAccessToken,
      spotifyId,
      ytmId
    );

    const sourceCount = direction === "SPOTIFY_TO_YTM" ? spotifyPlaylist.tracks.length : ytmPlaylist.tracks.length;
    const destinationCount = direction === "SPOTIFY_TO_YTM" ? ytmPlaylist.tracks.length : spotifyPlaylist.tracks.length;
    console.info("[sync][execute] counts", {
      direction,
      sourceCount,
      destinationCount,
      toAdd: toAdd.length,
      toRemove: toRemove.length,
      mode,
    });

    // Resolve adds via destination catalog search with duplicate prevention
    const skippedTracks: Array<{ title: string; artist: string; reason: SkipReason; normalizedTitle?: string }> = [];
    const addedUris: string[] = [];
    const addedVideoIds: string[] = [];
    let catalogMatches = 0;
    let duplicatesSkipped = 0;

    // Use a mutable copy of destSet to track what we're adding during execution
    const existingTrackKeys = new Set(destSet);

    for (const track of toAdd) {
      // DUPLICATE PREVENTION: Check if track already exists in destination
      if (existingTrackKeys.has(track.trackKey)) {
        skippedTracks.push({
          title: track.title,
          artist: track.artist,
          normalizedTitle: track.normalizedTitle,
          reason: "ALREADY_PRESENT",
        });
        console.warn("[sync][execute] skip already present", {
          title: track.title,
          normalizedTitle: track.normalizedTitle,
          artist: track.artist,
          trackKey: track.trackKey,
        });
        duplicatesSkipped += 1;
        continue;
      }

      if (direction === "SPOTIFY_TO_YTM") {
        try {
          const videoId = await searchYtmTrackExact(ytmAccessToken, track.title, track.artist);
          if (!videoId) {
            skippedTracks.push({
              title: track.title,
              artist: track.artist,
              normalizedTitle: track.normalizedTitle,
              reason: "NO_MATCH",
            });
            console.warn("[sync][execute] skip no exact match", {
              title: track.title,
              normalizedTitle: track.normalizedTitle,
              artist: track.artist,
            });
            continue;
          }
          addedVideoIds.push(videoId);
          catalogMatches += 1;
          // Mark as added to prevent duplicates within same sync operation
          existingTrackKeys.add(track.trackKey);
        } catch (error) {
          skippedTracks.push({
            title: track.title,
            artist: track.artist,
            normalizedTitle: track.normalizedTitle,
            reason: "SEARCH_FAILED",
          });
          console.error("[sync][execute] search failed", {
            title: track.title,
            artist: track.artist,
            error,
          });
        }
      } else {
        try {
          const uri = await searchSpotifyTrackExact(spotifyAccessToken, track.title, track.artist);
          if (!uri) {
            skippedTracks.push({
              title: track.title,
              artist: track.artist,
              normalizedTitle: track.normalizedTitle,
              reason: "NO_MATCH",
            });
            console.warn("[sync][execute] skip no exact match", {
              title: track.title,
              normalizedTitle: track.normalizedTitle,
              artist: track.artist,
            });
            continue;
          }
          addedUris.push(uri);
          catalogMatches += 1;
          // Mark as added to prevent duplicates within same sync operation
          existingTrackKeys.add(track.trackKey);
        } catch (error) {
          skippedTracks.push({
            title: track.title,
            artist: track.artist,
            normalizedTitle: track.normalizedTitle,
            reason: "SEARCH_FAILED",
          });
          console.error("[sync][execute] search failed", {
            title: track.title,
            artist: track.artist,
            error,
          });
        }
      }
    }

    console.info("[sync][execute] catalog resolution", {
      matches: catalogMatches,
      skipped: skippedTracks.length,
      duplicatesSkipped,
    });

    // Resolve removals if FULL_SYNC
    const toRemoveUris: string[] = [];
    const toRemovePlaylistItemIds: string[] = [];
    if (mode === "FULL_SYNC") {
      const removeKeySet = new Set(toRemove.map((t) => t.trackKey));
      if (direction === "SPOTIFY_TO_YTM") {
        for (const t of ytmPlaylist.tracks) {
          const normalized = normalizeTrack(t.title, t.artist || "");
          const key = trackKey(normalized);
          if (!removeKeySet.has(key)) continue;
          if (t.playlistItemId) {
            toRemovePlaylistItemIds.push(t.playlistItemId);
          }
        }
      } else {
        for (const t of spotifyPlaylist.tracks) {
          const normalized = normalizeTrack(t.title, t.artists[0] || "");
          const key = trackKey(normalized);
          if (!removeKeySet.has(key)) continue;
          if (t.uri) {
            toRemoveUris.push(t.uri);
          }
        }
      }
    }

    if (direction === "SPOTIFY_TO_YTM") {
      await addTracksToYtmPlaylist(ytmAccessToken, ytmId, addedVideoIds);
      if (mode === "FULL_SYNC") {
        await removeTracksFromYtmPlaylist(ytmAccessToken, toRemovePlaylistItemIds);
      }
    } else {
      await addTracksToSpotifyPlaylist(spotifyAccessToken, spotifyId, addedUris);
      if (mode === "FULL_SYNC") {
        await removeTracksFromSpotifyPlaylist(spotifyAccessToken, spotifyId, toRemoveUris);
      }
    }

    return res.json({
      addedCount: direction === "SPOTIFY_TO_YTM" ? addedVideoIds.length : addedUris.length,
      removedCount: mode === "FULL_SYNC" ? (direction === "SPOTIFY_TO_YTM" ? toRemovePlaylistItemIds.length : toRemoveUris.length) : 0,
      skippedCount: skippedTracks.length,
      duplicatesSkipped,
      skippedTracks,
    });
  } catch (error) {
    if ((error as any)?.status === 401) {
      return res.status(401).json({ error: (error as Error).message });
    }
    if (error instanceof SpotifyTokenExpiredError || error instanceof YtmTokenExpiredError) {
      return res.status(401).json({ error: error.message });
    }
    return next(error);
  }
};
