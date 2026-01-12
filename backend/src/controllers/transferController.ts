import { NextFunction, Request, Response } from "express";
import { Types } from "mongoose";
import Playlist from "../models/Playlist";
import SpotifyAccount from "../models/SpotifyAccount";
import YtmAccount from "../models/YtmAccount";
import {
  addTracksToSpotifyPlaylist,
  createSpotifyPlaylist,
  fetchSpotifyPlaylistWithTracks,
  refreshAccessToken as refreshSpotifyToken,
  searchSpotifyTrackExact,
  SpotifyTokenExpiredError,
} from "../utils/spotify";
import {
  addTracksToYtmPlaylist,
  createYtmPlaylist,
  fetchYtmPlaylistWithTracks,
  refreshAccessToken as refreshYtmToken,
  searchYtmTrackExact,
  YtmTokenExpiredError,
} from "../utils/ytm";

const TOKEN_BUFFER_MS = 60_000;

type Platform = "SPOTIFY" | "YTM" | "VIBEIT";

type TransferTrack = { title: string; artist: string };

type PreviewEntry = { title: string; artist: string; matchedId?: string };

class AuthError extends Error {
  status: number;
  constructor(message: string, status = 401) {
    super(message);
    this.status = status;
  }
}

const ensureSpotifyAccessToken = async (
  userId: string,
  requireWrite: boolean
): Promise<string> => {
  const account = await SpotifyAccount.findOne({ userId });
  if (!account) throw new AuthError("Spotify account not linked");
  if (requireWrite && account.scopeLevel !== "WRITE") {
    throw new AuthError("Spotify write access required", 403);
  }

  const expiresSoon = account.expiresAt.getTime() <= Date.now() + TOKEN_BUFFER_MS;
  if (!expiresSoon) return account.accessToken;

  try {
    const refreshed = await refreshSpotifyToken(account.refreshToken);
    account.accessToken = refreshed.accessToken;
    account.refreshToken = refreshed.refreshToken || account.refreshToken;
    account.expiresAt = new Date(Date.now() + refreshed.expiresIn * 1000);
    await account.save();
    return account.accessToken;
  } catch (error) {
    console.error("[transfer][spotify] token refresh failed", error);
    throw new AuthError("Please reconnect Spotify");
  }
};

const ensureYtmAccessToken = async (
  userId: string,
  requireWrite: boolean
): Promise<string> => {
  const account = await YtmAccount.findOne({ userId });
  if (!account) throw new AuthError("YouTube Music account not linked");
  if (requireWrite && account.scopeLevel !== "WRITE") {
    throw new AuthError("YouTube Music write access required", 403);
  }

  const expiresSoon = account.expiresAt.getTime() <= Date.now() + TOKEN_BUFFER_MS;
  if (!expiresSoon) return account.accessToken;

  try {
    const refreshed = await refreshYtmToken(account.refreshToken);
    account.accessToken = refreshed.accessToken;
    account.refreshToken = refreshed.refreshToken || account.refreshToken;
    account.expiresAt = new Date(Date.now() + refreshed.expiresIn * 1000);
    await account.save();
    return account.accessToken;
  } catch (error) {
    console.error("[transfer][ytm] token refresh failed", error);
    throw new AuthError("Please reconnect YouTube Music");
  }
};

const tryLoadInternalPlaylist = async (
  playlistId: string,
  userId: string
): Promise<{ name: string; tracks: TransferTrack[] } | null> => {
  if (!Types.ObjectId.isValid(playlistId)) return null;
  const internal = await Playlist.findOne({ _id: playlistId, ownerId: userId });
  if (!internal) return null;

  return {
    name: internal.name,
    tracks: internal.tracks.map((track) => ({ title: track.title, artist: track.artist })),
  };
};

const loadSourcePlaylist = async (
  sourcePlatform: Platform,
  playlistId: string,
  userId: string,
  spotifyToken?: string,
  ytmToken?: string
): Promise<{ name: string; tracks: TransferTrack[] }> => {
  const internal = await tryLoadInternalPlaylist(playlistId, userId);
  if (sourcePlatform === "VIBEIT") {
    if (internal) return internal;
    throw new AuthError("Playlist not found", 404);
  }

  if (internal) return internal;

  if (sourcePlatform === "SPOTIFY") {
    if (!spotifyToken) throw new AuthError("Spotify access token required");
    const remote = await fetchSpotifyPlaylistWithTracks(spotifyToken, playlistId);
    const tracks = remote.tracks.map((track) => ({
      title: track.title.trim(),
      artist: (track.artists[0] || "").trim(),
    }));
    return { name: remote.name, tracks };
  }

  if (!ytmToken) throw new AuthError("YouTube Music access token required");
  const remote = await fetchYtmPlaylistWithTracks(ytmToken, playlistId);
  const tracks = remote.tracks.map((track) => ({
    title: track.title.trim(),
    artist: (track.artist || "").trim(),
  }));
  return { name: remote.name, tracks };
};

const resolveOnDestination = async (
  destination: Platform,
  accessToken: string,
  track: TransferTrack
): Promise<PreviewEntry | null> => {
  if (!track.title || !track.artist) {
    return null;
  }

  if (destination === "SPOTIFY") {
    const uri = await searchSpotifyTrackExact(accessToken, track.title, track.artist);
    return uri ? { ...track, matchedId: uri } : null;
  }

  const videoId = await searchYtmTrackExact(accessToken, track.title, track.artist);
  return videoId ? { ...track, matchedId: videoId } : null;
};

const validatePayload = (sourcePlatform?: unknown, destinationPlatform?: unknown) => {
  const validSource = sourcePlatform === "SPOTIFY" || sourcePlatform === "YTM" || sourcePlatform === "VIBEIT";
  const validDest = destinationPlatform === "SPOTIFY" || destinationPlatform === "YTM";
  if (!validSource || !validDest) return false;
  if (sourcePlatform !== "VIBEIT" && sourcePlatform === destinationPlatform) return false;
  return true;
};

export const previewTransfer = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    const { sourcePlatform, destinationPlatform, playlistId } = req.body as {
      sourcePlatform?: Platform;
      destinationPlatform?: Platform;
      playlistId?: string;
    };

    if (!userId) return res.status(401).json({ error: "Unauthorized" });
    if (!validatePayload(sourcePlatform, destinationPlatform) || !playlistId) {
      return res.status(400).json({ error: "sourcePlatform, destinationPlatform, and playlistId are required" });
    }

    const srcPlatform = sourcePlatform as Platform;
    const destPlatform = destinationPlatform as Platform;

    const needsSpotify = srcPlatform === "SPOTIFY" || destPlatform === "SPOTIFY";
    const needsYtm = srcPlatform === "YTM" || destPlatform === "YTM";

    const spotifyToken = needsSpotify ? await ensureSpotifyAccessToken(userId, false) : undefined;
    const ytmToken = needsYtm ? await ensureYtmAccessToken(userId, false) : undefined;

    const source = await loadSourcePlaylist(srcPlatform, playlistId, userId, spotifyToken, ytmToken);

    const toAdd: PreviewEntry[] = [];
    const skipped: Array<{ title: string; artist: string; reason: string }> = [];

    for (const track of source.tracks) {
      if (!track.title || !track.artist) {
        skipped.push({ title: track.title || "(untitled)", artist: track.artist || "", reason: "MISSING_METADATA" });
        continue;
      }

      try {
        const match = await resolveOnDestination(destPlatform, destPlatform === "SPOTIFY" ? spotifyToken! : ytmToken!, track);
        if (match) {
          toAdd.push(match);
        } else {
          skipped.push({ title: track.title, artist: track.artist, reason: "NO_MATCH" });
        }
      } catch (error) {
        if (error instanceof SpotifyTokenExpiredError || error instanceof YtmTokenExpiredError) {
          return res.status(401).json({ error: error.message });
        }
        throw error;
      }
    }

    return res.json({
      playlistName: source.name,
      totalTracks: source.tracks.length,
      toAdd: toAdd.map(({ title, artist }) => ({ title, artist })),
      skipped,
    });
  } catch (error) {
    if (error instanceof AuthError) {
      return res.status(error.status).json({ error: error.message });
    }
    return next(error);
  }
};

export const executeTransfer = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    const { sourcePlatform, destinationPlatform, playlistId } = req.body as {
      sourcePlatform?: Platform;
      destinationPlatform?: Platform;
      playlistId?: string;
    };

    if (!userId) return res.status(401).json({ error: "Unauthorized" });
    if (!validatePayload(sourcePlatform, destinationPlatform) || !playlistId) {
      return res.status(400).json({ error: "sourcePlatform, destinationPlatform, and playlistId are required" });
    }

    const srcPlatform = sourcePlatform as Platform;
    const destPlatform = destinationPlatform as Platform;

    const spotifyToken =
      srcPlatform === "SPOTIFY" || destPlatform === "SPOTIFY"
        ? await ensureSpotifyAccessToken(userId, destPlatform === "SPOTIFY")
        : undefined;
    const ytmToken =
      srcPlatform === "YTM" || destPlatform === "YTM"
        ? await ensureYtmAccessToken(userId, destPlatform === "YTM")
        : undefined;

    const source = await loadSourcePlaylist(srcPlatform, playlistId, userId, spotifyToken, ytmToken);

    const resolved: PreviewEntry[] = [];
    const skipped: Array<{ title: string; artist: string; reason: string }> = [];

    for (const track of source.tracks) {
      if (!track.title || !track.artist) {
        skipped.push({ title: track.title || "(untitled)", artist: track.artist || "", reason: "MISSING_METADATA" });
        continue;
      }

      try {
        const match = await resolveOnDestination(destPlatform, destPlatform === "SPOTIFY" ? spotifyToken! : ytmToken!, track);
        if (match) {
          resolved.push(match);
        } else {
          skipped.push({ title: track.title, artist: track.artist, reason: "NO_MATCH" });
        }
      } catch (error) {
        if (error instanceof SpotifyTokenExpiredError || error instanceof YtmTokenExpiredError) {
          return res.status(401).json({ error: error.message });
        }
        throw error;
      }
    }

    let destinationPlaylistId: string;
    if (destPlatform === "SPOTIFY") {
      const uris = resolved.map((r) => r.matchedId!).filter(Boolean);
      destinationPlaylistId = await createSpotifyPlaylist(spotifyToken!, source.name);
      await addTracksToSpotifyPlaylist(spotifyToken!, destinationPlaylistId, uris);
    } else {
      const videoIds = resolved.map((r) => r.matchedId!).filter(Boolean);
      destinationPlaylistId = await createYtmPlaylist(ytmToken!, source.name);
      await addTracksToYtmPlaylist(ytmToken!, destinationPlaylistId, videoIds);
    }

    return res.status(201).json({
      playlistName: source.name,
      destinationPlaylistId,
      totalTracks: source.tracks.length,
      addedCount: resolved.length,
      skipped,
      toAdd: resolved.map(({ title, artist }) => ({ title, artist })),
    });
  } catch (error) {
    if (error instanceof AuthError) {
      return res.status(error.status).json({ error: error.message });
    }
    return next(error);
  }
};
