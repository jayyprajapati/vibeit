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
import { normalizeArtist, normalizeTitle, trackIdentity } from "../utils/trackNormalization";

interface NormalizedTrack {
  title: string;
  artist: string;
  normalizedTitle: string;
  normalizedArtist: string;
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

  const spotifyTracks: NormalizedTrack[] = spotifyPlaylist.tracks
    .map((t) => ({
      title: t.title,
      artist: t.artists[0] || "",
      normalizedTitle: normalizeTitle(t.title),
      normalizedArtist: normalizeArtist(t.artists[0] || ""),
    }))
    .filter((t) => t.normalizedTitle && t.normalizedArtist);

  const ytmTracks: NormalizedTrack[] = ytmPlaylist.tracks
    .map((t) => ({
      title: t.title,
      artist: t.artist || "",
      normalizedTitle: normalizeTitle(t.title),
      normalizedArtist: normalizeArtist(t.artist || ""),
    }))
    .filter((t) => t.normalizedTitle && t.normalizedArtist);

  const source = direction === "SPOTIFY_TO_YTM" ? spotifyTracks : ytmTracks;
  const dest = direction === "SPOTIFY_TO_YTM" ? ytmTracks : spotifyTracks;

  const destSet = new Set(dest.map((t) => trackIdentity(t.title, t.artist)));
  const sourceSet = new Set(source.map((t) => trackIdentity(t.title, t.artist)));

  const common = source.filter((t) => destSet.has(trackIdentity(t.title, t.artist)));
  const toAdd = source.filter((t) => !destSet.has(trackIdentity(t.title, t.artist)));
  const toRemove = dest.filter((t) => !sourceSet.has(trackIdentity(t.title, t.artist)));

  return { common, toAdd, toRemove, spotifyPlaylist, ytmPlaylist };
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

    const { common, toAdd, toRemove } = await getTrackSets(
      direction,
      spotifyAccessToken,
      ytmAccessToken,
      spotifyId,
      ytmId
    );

    const resolvedAdds: NormalizedTrack[] = [];
    const skippedTracks: Array<{ title: string; artist: string; reason: string; normalizedTitle: string }> = [];

    for (const track of toAdd) {
      const matchId =
        direction === "SPOTIFY_TO_YTM"
          ? await searchYtmTrackExact(ytmAccessToken, track.title, track.artist)
          : await searchSpotifyTrackExact(spotifyAccessToken, track.title, track.artist);

      if (matchId) {
        resolvedAdds.push(track);
      } else {
        skippedTracks.push({
          title: track.title,
          artist: track.artist,
          normalizedTitle: track.normalizedTitle,
          reason: "NO_EXACT_MATCH",
        });
        console.warn("[sync][preview] skip no exact match", {
          title: track.title,
          normalizedTitle: track.normalizedTitle,
          artist: track.artist,
        });
      }
    }

    const caseLabel = computeCase(resolvedAdds, toRemove);

    return res.json({
      case: caseLabel,
      common: common.map(toPublicTrack),
      toAdd: resolvedAdds.map(toPublicTrack),
      toRemove: toRemove.map(toPublicTrack),
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

    const { toAdd, toRemove, spotifyPlaylist, ytmPlaylist } = await getTrackSets(
      direction,
      spotifyAccessToken,
      ytmAccessToken,
      spotifyId,
      ytmId
    );

    // Resolve adds
    const skippedTracks: Array<{ title: string; artist: string; reason: string; normalizedTitle?: string }> = [];
    const addedUris: string[] = [];
    const addedVideoIds: string[] = [];

    for (const track of toAdd) {
      if (direction === "SPOTIFY_TO_YTM") {
        const videoId = await searchYtmTrackExact(ytmAccessToken, track.title, track.artist);
        if (!videoId) {
          skippedTracks.push({ ...toPublicTrack(track), normalizedTitle: track.normalizedTitle, reason: "NO_EXACT_MATCH" });
          console.warn("[sync][execute] skip no exact match", {
            title: track.title,
            normalizedTitle: track.normalizedTitle,
            artist: track.artist,
          });
          continue;
        }
        addedVideoIds.push(videoId);
      } else {
        const uri = await searchSpotifyTrackExact(spotifyAccessToken, track.title, track.artist);
        if (!uri) {
          skippedTracks.push({ ...toPublicTrack(track), normalizedTitle: track.normalizedTitle, reason: "NO_EXACT_MATCH" });
          console.warn("[sync][execute] skip no exact match", {
            title: track.title,
            normalizedTitle: track.normalizedTitle,
            artist: track.artist,
          });
          continue;
        }
        addedUris.push(uri);
      }
    }

    // Resolve removals if FULL_SYNC
    const toRemoveUris: string[] = [];
    const toRemovePlaylistItemIds: string[] = [];
    if (mode === "FULL_SYNC") {
      const removeSet = new Set(toRemove.map((t) => trackIdentity(t.title, t.artist)));
      if (direction === "SPOTIFY_TO_YTM") {
        for (const t of ytmPlaylist.tracks) {
          const key = trackIdentity(t.title, t.artist || "");
          if (!removeSet.has(key)) continue;
          if (t.playlistItemId) {
            toRemovePlaylistItemIds.push(t.playlistItemId);
          }
        }
      } else {
        for (const t of spotifyPlaylist.tracks) {
          const key = trackIdentity(t.title, t.artists[0] || "");
          if (!removeSet.has(key)) continue;
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
