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
} from "../utils/spotify";
import {
  YtmScopeLevel,
  YtmTokenExpiredError,
  addTracksToYtmPlaylist,
  fetchYtmPlaylistWithTracks,
  removeTracksFromYtmPlaylist,
  searchYtmTrackExact,
} from "../utils/ytm";

interface TrackKey {
  title: string;
  artist: string;
}

type Direction = "SPOTIFY_TO_YTM" | "YTM_TO_SPOTIFY";

type CaseLabel = "EQUAL" | "SUBSET" | "SUPERSET" | "PARTIAL";

type Mode = "APPEND_ONLY" | "FULL_SYNC";

const norm = (value: string) => value.trim().toLowerCase();

const toKey = (t: TrackKey) => `${norm(t.title)}::${norm(t.artist)}`;

const computeCase = (toAdd: TrackKey[], toRemove: TrackKey[]): CaseLabel => {
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

  const spotifyTracks: TrackKey[] = spotifyPlaylist.tracks
    .map((t) => ({ title: t.title, artist: t.artists[0] || "" }))
    .filter((t) => t.title.trim() && t.artist.trim());

  const ytmTracks: TrackKey[] = ytmPlaylist.tracks
    .map((t) => ({ title: t.title, artist: t.artist || "" }))
    .filter((t) => t.title.trim() && t.artist && t.artist.trim());

  const source = direction === "SPOTIFY_TO_YTM" ? spotifyTracks : ytmTracks;
  const dest = direction === "SPOTIFY_TO_YTM" ? ytmTracks : spotifyTracks;

  const destSet = new Set(dest.map(toKey));
  const sourceSet = new Set(source.map(toKey));

  const common = source.filter((t) => destSet.has(toKey(t)));
  const toAdd = source.filter((t) => !destSet.has(toKey(t)));
  const toRemove = dest.filter((t) => !sourceSet.has(toKey(t)));

  return { common, toAdd, toRemove, spotifyPlaylist, ytmPlaylist };
};

export const previewSync = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    const { playlistName, direction } = req.body as { playlistName?: string; direction?: Direction };

    if (!userId) return res.status(401).json({ error: "Unauthorized" });
    if (!playlistName || !direction) return res.status(400).json({ error: "playlistName and direction are required" });

    const { spotify, ytm } = await ensureLinked(userId);
    const { spotifyId, ytmId } = await findPlaylistIdsByName(userId, playlistName);

    if (!spotifyId || !ytmId) {
      return res.status(400).json({ error: "Playlist name must exist on both platforms" });
    }

    const { common, toAdd, toRemove } = await getTrackSets(
      direction,
      spotify.accessToken,
      ytm.accessToken,
      spotifyId,
      ytmId
    );

    const caseLabel = computeCase(toAdd, toRemove);

    return res.json({ case: caseLabel, common, toAdd, toRemove });
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
      spotify.accessToken,
      ytm.accessToken,
      spotifyId,
      ytmId
    );

    // Resolve adds
    const skippedTracks: Array<{ title: string; artist: string; reason: string }> = [];
    const addedUris: string[] = [];
    const addedVideoIds: string[] = [];

    for (const track of toAdd) {
      if (direction === "SPOTIFY_TO_YTM") {
        const videoId = await searchYtmTrackExact(ytm.accessToken, track.title, track.artist);
        if (!videoId) {
          skippedTracks.push({ ...track, reason: "NO_EXACT_MATCH" });
          continue;
        }
        addedVideoIds.push(videoId);
      } else {
        const uri = await searchSpotifyTrackExact(spotify.accessToken, track.title, track.artist);
        if (!uri) {
          skippedTracks.push({ ...track, reason: "NO_EXACT_MATCH" });
          continue;
        }
        addedUris.push(uri);
      }
    }

    // Resolve removals if FULL_SYNC
    const toRemoveUris: string[] = [];
    const toRemovePlaylistItemIds: string[] = [];
    if (mode === "FULL_SYNC") {
      const removeSet = new Set(toRemove.map(toKey));
      if (direction === "SPOTIFY_TO_YTM") {
        for (const t of ytmPlaylist.tracks) {
          const key = toKey({ title: t.title, artist: t.artist || "" });
          if (!removeSet.has(key)) continue;
          if (t.playlistItemId) {
            toRemovePlaylistItemIds.push(t.playlistItemId);
          }
        }
      } else {
        for (const t of spotifyPlaylist.tracks) {
          const key = toKey({ title: t.title, artist: t.artists[0] || "" });
          if (!removeSet.has(key)) continue;
          if (t.uri) {
            toRemoveUris.push(t.uri);
          }
        }
      }
    }

    if (direction === "SPOTIFY_TO_YTM") {
      await addTracksToYtmPlaylist(ytm.accessToken, ytmId, addedVideoIds);
      if (mode === "FULL_SYNC") {
        await removeTracksFromYtmPlaylist(ytm.accessToken, toRemovePlaylistItemIds);
      }
    } else {
      await addTracksToSpotifyPlaylist(spotify.accessToken, spotifyId, addedUris);
      if (mode === "FULL_SYNC") {
        await removeTracksFromSpotifyPlaylist(spotify.accessToken, spotifyId, toRemoveUris);
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
