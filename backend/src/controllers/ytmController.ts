import { NextFunction, Request, Response } from "express";
import { Types } from "mongoose";
import jwt from "jsonwebtoken";
import env from "../config/env";
import { YtmAccount } from "../models/YtmAccount";
import { YtmPlaylist, IYtmPlaylist } from "../models/YtmPlaylist";
import User from "../models/User";
import {
  YtmRemotePlaylist,
  YtmScopeLevel,
  YtmTokenExpiredError,
  YtmReauthRequiredError,
  buildYtmAuthUrl,
  exchangeCodeForToken,
  fetchYtmPlaylists,
  refreshAccessToken,
  fetchYtmPlaylistWithTracks,
} from "../utils/ytm";
import Playlist from "../models/Playlist";

const CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours
const TOKEN_EXPIRY_BUFFER_MS = 60 * 1000; // refresh 1 minute before expiry

interface YtmStatePayload {
  userId: string;
  redirectTo?: string;
  scopeLevel?: YtmScopeLevel;
}

interface PlaylistResponse {
  connected: boolean;
  playlists: Array<{
    id: string;
    name: string;
    itemCount: number;
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

class UsageLimitError extends Error {
  statusCode: number;

  constructor(message: string, statusCode = 429) {
    super(message);
    this.statusCode = statusCode;
    this.name = "UsageLimitError";
  }
}

const serializePlaylist = (playlist: IYtmPlaylist) => ({
  id: playlist.ytmPlaylistId,
  name: playlist.name,
  itemCount: playlist.itemCount,
  lastFetchedAt: playlist.lastFetchedAt,
});

const serializePlaylistDetail = (playlist: IYtmPlaylist) => ({
  id: playlist.ytmPlaylistId,
  name: playlist.name,
  itemCount: playlist.itemCount,
  lastFetchedAt: playlist.lastFetchedAt,
  tracks: playlist.tracks,
});

const decodeState = (state: string): YtmStatePayload | null => {
  try {
    const payload = jwt.verify(state, env.jwtSecret, { subject: "ytm-auth" }) as YtmStatePayload;
    if (!payload.userId) return null;
    return payload;
  } catch (error) {
    console.error("[ytm] Invalid state", error);
    return null;
  }
};

const encodeState = (payload: YtmStatePayload): string => {
  return jwt.sign(payload, env.jwtSecret, { expiresIn: "15m", subject: "ytm-auth" });
};

const buildRedirectUrl = (status: "success" | "error", message?: string, redirectOverride?: string) => {
  const target = redirectOverride || env.ytmFrontendRedirect;
  try {
    const url = new URL(target);
    url.searchParams.set("ytm_status", status);
    if (message) url.searchParams.set("message", message);
    return url.toString();
  } catch (error) {
    console.error("[ytm] Failed to build redirect URL", error);
    return null;
  }
};

const ensureAccessToken = async (userId: string) => {
  const account = await YtmAccount.findOne({ userId });
  if (!account) {
    throw new ReauthRequiredError("YouTube Music account not linked");
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
    if (error instanceof YtmReauthRequiredError) {
      console.warn("[ytm] Refresh token invalid, deleting stale account", error);
      await YtmAccount.deleteOne({ userId });
      throw new ReauthRequiredError("YouTube Music session expired. Please reconnect.");
    }

    console.error("[ytm] Token refresh failed", error);
    throw new ReauthRequiredError("Please reconnect YouTube Music");
  }
};

const incrementUsageOrThrow = async (userId: string) => {
  const user = await User.findById(userId);
  if (!user) {
    throw new Error("User not found");
  }

  if (user.usageToday >= user.dailyUsageLimit) {
    throw new UsageLimitError("Daily usage limit exceeded for YouTube Music");
  }

  user.usageToday += 1;
  await user.save();
};

const fetchAndCachePlaylists = async (userId: string, forceRemote: boolean): Promise<PlaylistResponse> => {
  const userObjectId = new Types.ObjectId(userId);
  const latest = await YtmPlaylist.findOne({ userId: userObjectId }).sort({ lastFetchedAt: -1 }).select("lastFetchedAt");
  const lastSyncedAt: Date | null = latest?.lastFetchedAt ?? null;
  const lastSyncedAtMs = lastSyncedAt ? lastSyncedAt.getTime() : 0;
  const hasFreshCache = !forceRemote && !!lastSyncedAt && Date.now() - lastSyncedAtMs < CACHE_TTL_MS;

  const returnCached = async (options?: Partial<PlaylistResponse>): Promise<PlaylistResponse> => {
    const cachedPlaylists = await YtmPlaylist.find({ userId: userObjectId }).sort({ name: 1 });
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
    const remotePlaylists: YtmRemotePlaylist[] = await fetchYtmPlaylists(accessToken);
    const now = new Date();

    if (remotePlaylists.length === 0) {
      await YtmPlaylist.deleteMany({ userId: userObjectId });
    } else {
      const operations = remotePlaylists.map((playlist: YtmRemotePlaylist) => ({
        updateOne: {
          filter: { userId: userObjectId, ytmPlaylistId: playlist.ytmPlaylistId },
          update: {
            $set: {
              userId: userObjectId,
              ytmPlaylistId: playlist.ytmPlaylistId,
              name: playlist.name,
              itemCount: playlist.itemCount,
              lastFetchedAt: now,
            },
          },
          upsert: true,
        },
      }));

      await YtmPlaylist.bulkWrite(operations, { ordered: false });
      const ids = remotePlaylists.map((p) => p.ytmPlaylistId);
      await YtmPlaylist.deleteMany({ userId: userObjectId, ytmPlaylistId: { $nin: ids } });
    }

    const updated = await YtmPlaylist.find({ userId: userObjectId }).sort({ name: 1 });
    return {
      connected: true,
      playlists: updated.map(serializePlaylist),
      fromCache: false,
      lastSyncedAt: now,
      nextScheduledSyncAt: new Date(now.getTime() + CACHE_TTL_MS),
    };
  } catch (error) {
    if (error instanceof YtmReauthRequiredError) {
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

    if (error instanceof YtmTokenExpiredError) {
      if (lastSyncedAt) {
        return returnCached({ refreshFailed: true, message: error.message });
      }
      throw new ReauthRequiredError("YouTube Music access token expired");
    }

    if (lastSyncedAt) {
      const message = error instanceof Error ? error.message : "Failed to refresh from YouTube Music";
      return returnCached({ refreshFailed: true, message });
    }

    throw error;
  }
};

export const getYtmAuthUrl = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    if (!env.googleClientId || !env.googleClientSecret || !env.ytmRedirectUri) {
      return res.status(500).json({ error: "YouTube Music configuration is missing" });
    }

    const requestedScope = (req.query.scope as string | undefined)?.toUpperCase() === "WRITE" ? "WRITE" : "READ";
    const state = encodeState({ userId, redirectTo: env.ytmFrontendRedirect, scopeLevel: requestedScope });
    const url = buildYtmAuthUrl(state, requestedScope);
    return res.json({ url });
  } catch (error) {
    return next(error);
  }
};

export const ytmCallback = async (req: Request, res: Response) => {
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
    const existing = await YtmAccount.findOne({ userId: payload.userId });
    const refreshToken = tokens.refreshToken || existing?.refreshToken;
    const scopeLevel: YtmScopeLevel = payload.scopeLevel === "WRITE" ? "WRITE" : existing?.scopeLevel || "READ";

    if (!refreshToken) {
      throw new Error("Google did not return a refresh token. Please reconnect.");
    }

    await YtmAccount.findOneAndUpdate(
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

    await YtmPlaylist.deleteMany({ userId: payload.userId });

    return redirectWithStatus("success", "ytm_connected", payload.redirectTo);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to complete YouTube Music auth";
    return redirectWithStatus("error", message, payload.redirectTo);
  }
};

export const getYtmPlaylists = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const account = await YtmAccount.findOne({ userId });
    if (!account) {
      return res.json({
        connected: false,
        playlists: [],
        fromCache: false,
        lastSyncedAt: null,
        nextScheduledSyncAt: null,
      });
    }

    // Only increment usage when we will actually hit the external API (no fresh cache)
    const userObjectId = new Types.ObjectId(userId);
    const latest = await YtmPlaylist.findOne({ userId: userObjectId }).sort({ lastFetchedAt: -1 }).select("lastFetchedAt");
    const lastSyncedAt = latest?.lastFetchedAt ?? null;
    const hasFreshCache = !!lastSyncedAt && Date.now() - lastSyncedAt.getTime() < CACHE_TTL_MS;
    if (!hasFreshCache) {
      await incrementUsageOrThrow(userId);
    }

    const response = await fetchAndCachePlaylists(userId, false);
    return res.json(response);
  } catch (error) {
    if (error instanceof UsageLimitError) {
      return res.status(error.statusCode).json({ error: error.message });
    }
    return next(error);
  }
};

export const syncYtmNow = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const account = await YtmAccount.findOne({ userId });
    if (!account) {
      return res.status(400).json({ error: "YouTube Music not connected" });
    }

    await incrementUsageOrThrow(userId);
    const response = await fetchAndCachePlaylists(userId, true);
    return res.json(response);
  } catch (error) {
    if (error instanceof UsageLimitError) {
      return res.status(error.statusCode).json({ error: error.message });
    }
    return next(error);
  }
};

export const getYtmPlaylistDetail = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    const playlistId = (req.params.ytmPlaylistId || "").trim();

    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    if (!playlistId) {
      return res.status(400).json({ error: "YouTube Music playlist id is required" });
    }

    await incrementUsageOrThrow(userId);

    const playlist = await YtmPlaylist.findOne({ userId, ytmPlaylistId: playlistId });
    if (!playlist) {
      return res.status(404).json({ error: "Playlist not found" });
    }

    const lastFetchedMs = playlist.lastFetchedAt?.getTime?.() ?? 0;
    const freshEnough = playlist.tracks && playlist.tracks.length > 0 && Date.now() - lastFetchedMs < CACHE_TTL_MS;

    if (freshEnough) {
      return res.json({ ...serializePlaylistDetail(playlist), fromCache: true });
    }

    const accessToken = await ensureAccessToken(userId);
    const remote = await fetchYtmPlaylistWithTracks(accessToken, playlistId);

    const mappedTracks = remote.tracks.map((track) => ({
      title: track.title || "Unknown title",
      artist: track.artist || "Unknown artist",
      durationSeconds: track.durationSeconds ?? null,
      videoId: track.videoId ?? null,
    }));

    playlist.name = remote.name || playlist.name;
    playlist.itemCount = remote.total || remote.tracks.length;
    playlist.tracks = mappedTracks;
    playlist.lastFetchedAt = new Date();
    await playlist.save();

    return res.json({ ...serializePlaylistDetail(playlist), fromCache: false });
  } catch (error) {
    if (error instanceof UsageLimitError) {
      return res.status(error.statusCode).json({ error: error.message });
    }

    if (error instanceof YtmReauthRequiredError) {
      return res.status(401).json({ error: error.message });
    }

    if (error instanceof ReauthRequiredError) {
      return res.status(401).json({ error: error.message });
    }

    if (error instanceof YtmTokenExpiredError) {
      return res.status(401).json({ error: "YouTube Music access token expired. Please reconnect." });
    }

    return next(error);
  }
};

export const importYtmPlaylist = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    const ytmPlaylistId = (req.params.ytmPlaylistId || "").trim();

    if (!userId) return res.status(401).json({ error: "Unauthorized" });
    if (!ytmPlaylistId) {
      return res.status(400).json({ error: "YouTube Music playlist id is required" });
    }

    const attemptImport = async (accessToken: string) => {
      const remote = await fetchYtmPlaylistWithTracks(accessToken, ytmPlaylistId);

      const skippedTracks: Array<{ name: string; reason: string }> = [];
      const mapped = remote.tracks.map((track) => {
        const title = track.title.trim();
        const artist = (track.artist || "").trim();
        const duration = track.durationSeconds ?? 0;
        const album = "Unknown Album";

        if (!title) {
          skippedTracks.push({ name: "(untitled track)", reason: "Missing title" });
          return null;
        }

        if (!artist) {
          skippedTracks.push({ name: title, reason: "Missing artist" });
          return null;
        }

        if (!Number.isFinite(duration) || duration <= 0) {
          skippedTracks.push({ name: title, reason: "Missing duration" });
          return null;
        }

        return { title, artist, album, duration };
      });

      const tracks = mapped.filter((t): t is NonNullable<typeof t> => t !== null);

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
        if (!refreshed && error instanceof YtmTokenExpiredError) {
          const account = await YtmAccount.findOne({ userId });
          if (!account) {
            throw new ReauthRequiredError("YouTube Music account not linked");
          }

          try {
            const refreshedTokens = await refreshAccessToken(account.refreshToken);
            account.accessToken = refreshedTokens.accessToken;
            account.refreshToken = refreshedTokens.refreshToken || account.refreshToken;
            account.expiresAt = new Date(Date.now() + refreshedTokens.expiresIn * 1000);
            await account.save();
            accessToken = account.accessToken;
            refreshed = true;
            continue;
          } catch (refreshError) {
            if (refreshError instanceof YtmReauthRequiredError) {
              throw new ReauthRequiredError(refreshError.message);
            }
            throw refreshError;
          }
        }

        throw error;
      }
    }
  } catch (error) {
    if (error instanceof UsageLimitError) {
      return res.status(error.statusCode).json({ error: error.message });
    }
    if (error instanceof YtmReauthRequiredError) {
      return res.status(401).json({ error: error.message });
    }
    if (error instanceof ReauthRequiredError) {
      return res.status(401).json({ error: error.message });
    }
    if (error instanceof YtmTokenExpiredError) {
      return res.status(401).json({ error: error.message });
    }
    return next(error);
  }
};

export const disconnectYtm = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const userObjectId = new Types.ObjectId(userId);
    await Promise.all([
      YtmAccount.deleteOne({ userId }),
      YtmPlaylist.deleteMany({ userId: userObjectId }),
    ]);

    return res.json({ disconnected: true });
  } catch (error) {
    return next(error);
  }
};
