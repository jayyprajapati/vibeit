import { NextFunction, Request, Response } from "express";
import { Types } from "mongoose";
import jwt from "jsonwebtoken";
import env from "../config/env";
import SpotifyAccount from "../models/SpotifyAccount";
import SpotifyPlaylist, { ISpotifyPlaylist } from "../models/SpotifyPlaylist";
import Playlist from "../models/Playlist";
import {
  SpotifyRemotePlaylist,
  SpotifyScopeLevel,
  buildSpotifyAuthUrl,
  exchangeCodeForToken,
  fetchSpotifyPlaylists,
  fetchSpotifyPlaylistWithTracks,
  refreshAccessToken,
  SpotifyTokenExpiredError,
} from "../utils/spotify";

const CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours
const TOKEN_EXPIRY_BUFFER_MS = 60 * 1000; // refresh 1 minute before expiry

interface SpotifyStatePayload {
  userId: string;
  redirectTo?: string;
  scopeLevel?: SpotifyScopeLevel;
}

interface PlaylistResponse {
  connected: boolean;
  playlists: Array<{
    id: string;
    name: string;
    trackCount: number;
    lastFetchedAt: Date;
  }>;
  fromCache: boolean;
  refreshFailed?: boolean;
  reauthRequired?: boolean;
  lastSyncedAt: Date | null;
  nextScheduledSyncAt: Date | null;
  message?: string;
}

class ReauthRequiredError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ReauthRequiredError";
  }
}

const serializePlaylist = (playlist: ISpotifyPlaylist) => ({
  id: playlist.spotifyPlaylistId,
  name: playlist.name,
  trackCount: playlist.trackCount,
  lastFetchedAt: playlist.lastFetchedAt,
});

const serializePlaylistDetail = (playlist: ISpotifyPlaylist) => ({
  id: playlist.spotifyPlaylistId,
  name: playlist.name,
  trackCount: playlist.trackCount,
  lastFetchedAt: playlist.lastFetchedAt,
  tracks: playlist.tracks,
});

const decodeState = (state: string): SpotifyStatePayload | null => {
  try {
    const payload = jwt.verify(state, env.jwtSecret, { subject: "spotify-auth" }) as SpotifyStatePayload;
    if (!payload.userId) return null;
    return payload;
  } catch (error) {
    console.error("[spotify] Invalid state", error);
    return null;
  }
};

const encodeState = (payload: SpotifyStatePayload): string => {
  return jwt.sign(payload, env.jwtSecret, { expiresIn: "15m", subject: "spotify-auth" });
};

const buildRedirectUrl = (status: "success" | "error", message?: string, redirectOverride?: string) => {
  const target = redirectOverride || env.spotifyFrontendRedirect;
  try {
    const url = new URL(target);
    url.searchParams.set("spotify_status", status);
    if (message) url.searchParams.set("message", message);
    return url.toString();
  } catch (error) {
    console.error("[spotify] Failed to build redirect URL", error);
    return null;
  }
};

const ensureAccessToken = async (userId: string) => {
  const account = await SpotifyAccount.findOne({ userId });
  if (!account) {
    throw new ReauthRequiredError("Spotify account not linked");
  }

  const expiresSoon = account.expiresAt.getTime() <= Date.now() + TOKEN_EXPIRY_BUFFER_MS;
  if (!expiresSoon) {
    return account.accessToken;
  }

  try {
    const refreshed = await refreshAccessToken(account.refreshToken);
    account.accessToken = refreshed.accessToken;
    account.refreshToken = refreshed.refreshToken || account.refreshToken;
    account.expiresAt = new Date(Date.now() + refreshed.expiresIn * 1000);
    await account.save();
    return account.accessToken;
  } catch (error) {
    console.error("[spotify] Token refresh failed", error);
    throw new ReauthRequiredError("Please reconnect Spotify");
  }
};

const fetchAndCachePlaylists = async (
  userId: string,
  forceRemote: boolean
): Promise<PlaylistResponse> => {
  const userObjectId = new Types.ObjectId(userId);
  const latest = await SpotifyPlaylist.findOne({ userId: userObjectId }).sort({ lastFetchedAt: -1 }).select("lastFetchedAt");
  const lastSyncedAt: Date | null = latest?.lastFetchedAt ?? null;
  const lastSyncedAtMs = lastSyncedAt ? lastSyncedAt.getTime() : 0;
  const hasFreshCache = !forceRemote && !!lastSyncedAt && Date.now() - lastSyncedAtMs < CACHE_TTL_MS;

  const returnCached = async (options?: Partial<PlaylistResponse>): Promise<PlaylistResponse> => {
    const cachedPlaylists = await SpotifyPlaylist.find({ userId: userObjectId }).sort({ name: 1 });
    return {
      connected: true,
      playlists: cachedPlaylists.map(serializePlaylist),
      fromCache: true,
      lastSyncedAt,
      nextScheduledSyncAt: lastSyncedAt ? new Date(lastSyncedAtMs + CACHE_TTL_MS) : null,
      ...options,
    };
  };

  if (hasFreshCache) {
    return returnCached();
  }

  try {
    const accessToken = await ensureAccessToken(userId);
    const remotePlaylists = await fetchSpotifyPlaylists(accessToken);
    const now = new Date();

    if (remotePlaylists.length === 0) {
      await SpotifyPlaylist.deleteMany({ userId: userObjectId });
    } else {
      const operations = remotePlaylists.map((playlist: SpotifyRemotePlaylist) => ({
        updateOne: {
          filter: { userId: userObjectId, spotifyPlaylistId: playlist.spotifyPlaylistId },
          update: {
            $set: {
              userId: userObjectId,
              spotifyPlaylistId: playlist.spotifyPlaylistId,
              name: playlist.name,
              trackCount: playlist.trackCount,
              lastFetchedAt: now,
              tracks: [],
            },
          },
          upsert: true,
        },
      }));

      await SpotifyPlaylist.bulkWrite(operations, { ordered: false });
      const ids = remotePlaylists.map((p) => p.spotifyPlaylistId);
      await SpotifyPlaylist.deleteMany({ userId: userObjectId, spotifyPlaylistId: { $nin: ids } });
    }

    const updated = await SpotifyPlaylist.find({ userId: userObjectId }).sort({ name: 1 });
    return {
      connected: true,
      playlists: updated.map(serializePlaylist),
      fromCache: false,
      lastSyncedAt: now,
      nextScheduledSyncAt: new Date(now.getTime() + CACHE_TTL_MS),
    };
  } catch (error) {
    if (error instanceof ReauthRequiredError) {
      if (lastSyncedAt) {
        return returnCached({ reauthRequired: true, refreshFailed: true, message: error.message });
      }

      return {
        connected: true,
        playlists: [],
        fromCache: false,
        reauthRequired: true,
        refreshFailed: true,
        lastSyncedAt,
        nextScheduledSyncAt: lastSyncedAt ? new Date(lastSyncedAtMs + CACHE_TTL_MS) : null,
        message: error.message,
      };
    }

    if (lastSyncedAt) {
      const message = error instanceof Error ? error.message : "Failed to refresh from Spotify";
      return returnCached({ refreshFailed: true, message });
    }

    throw error;
  }
};

export const getSpotifyAuthUrl = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    if (!env.spotifyClientId || !env.spotifyClientSecret || !env.spotifyRedirectUri) {
      return res.status(500).json({ error: "Spotify configuration is missing" });
    }

    const requestedScope = (req.query.scope as string | undefined)?.toUpperCase() === "WRITE" ? "WRITE" : "READ";
    const state = encodeState({ userId, redirectTo: env.spotifyFrontendRedirect, scopeLevel: requestedScope });
    const url = buildSpotifyAuthUrl(state, requestedScope);
    return res.json({ url });
  } catch (error) {
    return next(error);
  }
};

export const spotifyCallback = async (req: Request, res: Response) => {
  const { code, state, error } = req.query as Record<string, string | undefined>;

  const redirectWithStatus = (status: "success" | "error", message?: string, redirectOverride?: string) => {
    const redirectUrl = buildRedirectUrl(status, message, redirectOverride);
    if (redirectUrl) {
      return res.redirect(redirectUrl);
    }
    return res.status(status === "success" ? 200 : 400).json({ status, message });
  };

  if (error) {
    return redirectWithStatus("error", error);
  }

  if (!code || !state) {
    return redirectWithStatus("error", "Missing code or state");
  }

  const payload = decodeState(state);
  if (!payload?.userId) {
    return redirectWithStatus("error", "Invalid auth session");
  }

  try {
    const tokens = await exchangeCodeForToken(code);
    const expiresAt = new Date(Date.now() + tokens.expiresIn * 1000);
    const existing = await SpotifyAccount.findOne({ userId: payload.userId });
    const refreshToken = tokens.refreshToken || existing?.refreshToken;
    const scopeLevel: SpotifyScopeLevel = payload.scopeLevel === "WRITE" ? "WRITE" : existing?.scopeLevel || "READ";

    if (!refreshToken) {
      throw new Error("Spotify did not return a refresh token. Please reconnect.");
    }

    await SpotifyAccount.findOneAndUpdate(
      { userId: payload.userId },
      {
        userId: payload.userId,
        accessToken: tokens.accessToken,
        refreshToken,
        expiresAt,
        scopeLevel,
      },
      { upsert: true, new: true }
    );

    await SpotifyPlaylist.deleteMany({ userId: payload.userId });

    return redirectWithStatus("success", "spotify_connected", payload.redirectTo);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to complete Spotify auth";
    return redirectWithStatus("error", message, payload.redirectTo);
  }
};

export const getSpotifyPlaylists = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const account = await SpotifyAccount.findOne({ userId });
    if (!account) {
      return res.json({
        connected: false,
        playlists: [],
        fromCache: false,
        lastSyncedAt: null,
        nextScheduledSyncAt: null,
      });
    }

    const response = await fetchAndCachePlaylists(userId, false);
    return res.json(response);
  } catch (error) {
    return next(error);
  }
};

export const syncSpotifyNow = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const account = await SpotifyAccount.findOne({ userId });
    if (!account) {
      return res.status(400).json({ error: "Spotify not connected" });
    }

    const response = await fetchAndCachePlaylists(userId, true);
    return res.json(response);
  } catch (error) {
    return next(error);
  }
};

export const getSpotifyPlaylistDetail = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    const playlistId = (req.params.spotifyPlaylistId || "").trim();

    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    if (!playlistId) {
      return res.status(400).json({ error: "Spotify playlist id is required" });
    }

    const playlist = await SpotifyPlaylist.findOne({
      userId,
      spotifyPlaylistId: playlistId,
    });

    if (!playlist) {
      return res.status(404).json({ error: "Playlist not found" });
    }

    const lastFetchedMs = playlist.lastFetchedAt?.getTime?.() ?? 0;
    const freshEnough = playlist.tracks.length > 0 && Date.now() - lastFetchedMs < CACHE_TTL_MS;

    if (freshEnough) {
      return res.json({ ...serializePlaylistDetail(playlist), fromCache: true });
    }

    const accessToken = await ensureAccessToken(userId);
    const remote = await fetchSpotifyPlaylistWithTracks(accessToken, playlistId);

    const mappedTracks = remote.tracks.map((track) => ({
      name: track.title || "Unknown track",
      artist: track.artists.join(", ") || "Unknown artist",
    }));

    playlist.name = remote.name;
    playlist.trackCount = remote.total || remote.tracks.length;
    playlist.tracks = mappedTracks;
    playlist.lastFetchedAt = new Date();
    await playlist.save();

    return res.json({ ...serializePlaylistDetail(playlist), fromCache: false });
  } catch (error) {
    if (error instanceof ReauthRequiredError) {
      return res.status(401).json({ error: error.message });
    }

    if (error instanceof SpotifyTokenExpiredError) {
      return res.status(401).json({ error: "Spotify access token expired. Please reconnect." });
    }

    return next(error);
  }
};

export const importSpotifyPlaylist = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    const spotifyPlaylistId = (req.params.spotifyPlaylistId || "").trim();

    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    if (!spotifyPlaylistId) {
      return res.status(400).json({ error: "Spotify playlist id is required" });
    }

    const attemptImport = async (accessToken: string) => {
      const remote = await fetchSpotifyPlaylistWithTracks(accessToken, spotifyPlaylistId);

      const skippedTracks: Array<{ name: string; reason: string }> = [];
      const mappedTracks = remote.tracks.map((track) => {
        const title = track.title.trim();
        const artist = track.artists.join(", ").trim();
        const durationSeconds = track.durationMs ? Math.round(track.durationMs / 1000) : 0;
        const album = (track.album?.trim() || "Unknown Album").trim();

        if (!title) {
          skippedTracks.push({ name: "(untitled track)", reason: "Missing title" });
          return null;
        }

        if (!artist) {
          skippedTracks.push({ name: title, reason: "Missing artist" });
          return null;
        }

        if (!Number.isFinite(durationSeconds) || durationSeconds <= 0) {
          skippedTracks.push({ name: title, reason: "Missing duration" });
          return null;
        }

        return {
          title,
          artist,
          album,
          duration: durationSeconds,
        };
      });

      const tracks = mappedTracks.filter((t): t is NonNullable<typeof t> => t !== null);

      const playlist = await Playlist.create({
        name: remote.name,
        ownerId: userId,
        source: "internal",
        tracks,
      });

      return {
        playlistId: playlist._id.toString(),
        playlistName: remote.name,
        importedCount: tracks.length,
        skippedCount: skippedTracks.length,
        skippedTracks,
        totalTracks: remote.tracks.length,
      };
    };

    let accessToken = await ensureAccessToken(userId);
    let refreshed = false;

    while (true) {
      try {
        const summary = await attemptImport(accessToken);
        return res.status(201).json(summary);
      } catch (error) {
        if (!refreshed && error instanceof SpotifyTokenExpiredError) {
          const account = await SpotifyAccount.findOne({ userId });
          if (!account) {
            throw new ReauthRequiredError("Spotify account not linked");
          }

          const refreshedTokens = await refreshAccessToken(account.refreshToken);
          account.accessToken = refreshedTokens.accessToken;
          account.refreshToken = refreshedTokens.refreshToken || account.refreshToken;
          account.expiresAt = new Date(Date.now() + refreshedTokens.expiresIn * 1000);
          await account.save();
          accessToken = account.accessToken;
          refreshed = true;
          continue;
        }

        throw error;
      }
    }
  } catch (error) {
    if (error instanceof ReauthRequiredError) {
      return res.status(401).json({ error: error.message });
    }

    if (error instanceof SpotifyTokenExpiredError) {
      return res.status(401).json({ error: "Spotify access token expired. Please reconnect." });
    }

    return next(error);
  }
};
