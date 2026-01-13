import { NextFunction, Request, Response } from "express";
import { Types } from "mongoose";
import Playlist, { IPlaylist } from "../models/Playlist";
import { normalizeTrack } from "../utils/trackNormalization";

const serializePlaylist = (playlist: IPlaylist) => ({
  id: playlist._id.toString(),
  name: playlist.name,
  ownerId: playlist.ownerId.toString(),
  source: playlist.source,
  createdAt: playlist.createdAt,
  updatedAt: playlist.updatedAt,
  tracks: playlist.tracks.map((track) => ({
    id: track._id.toString(),
    title: track.title,
    artist: track.artist,
    album: track.album,
    duration: track.duration,
    musicBrainzRecordingId: track.musicBrainzRecordingId ?? null,
    normalizedTitle: track.normalizedTitle ?? null,
    normalizedArtist: track.normalizedArtist ?? null,
    source: track.source ?? null,
    createdAt: track.createdAt ?? null,
  })),
});

const validatePlaylistId = (playlistId: string): boolean => Types.ObjectId.isValid(playlistId);

const validateTrackPayload = (payload: Record<string, unknown>) => {
  const title = (payload.title as string | undefined)?.trim() || "";
  const artist = (payload.artist as string | undefined)?.trim() || "";
  const album = (payload.album as string | undefined)?.trim() || "";
  const duration = Number(payload.duration);
  const musicBrainzRecordingId = payload.musicBrainzRecordingId;
  const source = payload.source;

  if (!title) return "Track title is required";
  if (!artist) return "Track artist is required";
  if (!album) return "Track album is required";
  if (!Number.isFinite(duration) || duration <= 0) return "Track duration must be a positive number";
  if (musicBrainzRecordingId && typeof musicBrainzRecordingId !== "string") return "Invalid MusicBrainz recording id";
  if (source && typeof source !== "string") return "Invalid track source";

  return null;
};

export const createPlaylist = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    const rawName = (req.body?.name as string | undefined) || "";
    const name = rawName.trim();

    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    if (name.length === 0) {
      return res.status(400).json({ error: "Playlist name is required" });
    }

    if (name.length > 120) {
      return res.status(400).json({ error: "Playlist name must be 120 characters or fewer" });
    }

    const playlist = await Playlist.create({ name, ownerId: userId, source: "internal" });
    return res.status(201).json({ playlist: serializePlaylist(playlist) });
  } catch (error) {
    return next(error);
  }
};

export const listPlaylists = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const playlists = await Playlist.find({ ownerId: userId }).sort({ updatedAt: -1 });
    return res.json({ playlists: playlists.map(serializePlaylist) });
  } catch (error) {
    return next(error);
  }
};

export const getPlaylistById = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    const playlistId = req.params.id;

    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    if (!validatePlaylistId(playlistId)) {
      return res.status(400).json({ error: "Invalid playlist id" });
    }

    const playlist = await Playlist.findOne({ _id: playlistId, ownerId: userId });
    if (!playlist) {
      return res.status(404).json({ error: "Playlist not found" });
    }

    return res.json({ playlist: serializePlaylist(playlist) });
  } catch (error) {
    return next(error);
  }
};

export const addTrackToPlaylist = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    const playlistId = req.params.id;

    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    if (!validatePlaylistId(playlistId)) {
      return res.status(400).json({ error: "Invalid playlist id" });
    }

    const validationError = validateTrackPayload(req.body ?? {});
    if (validationError) {
      return res.status(400).json({ error: validationError });
    }

    const playlist = await Playlist.findOne({ _id: playlistId, ownerId: userId });
    if (!playlist) {
      return res.status(404).json({ error: "Playlist not found" });
    }

    const title = (req.body.title as string).trim();
    const artist = (req.body.artist as string).trim();
    const album = (req.body.album as string).trim();
    const duration = Number(req.body.duration);
    const musicBrainzRecordingId = (req.body.musicBrainzRecordingId as string | undefined)?.trim() || null;
    const source = (req.body.source as string | undefined)?.trim() || null;
    const normalized = normalizeTrack(title, artist);

    const track = {
      title,
      artist,
      album,
      duration,
      musicBrainzRecordingId,
      normalizedTitle: normalized.normalizedTitle,
      normalizedArtist: normalized.normalizedArtist,
      source: source || (musicBrainzRecordingId ? "MUSICBRAINZ" : null),
      createdAt: new Date(),
    };

    playlist.tracks.push(track);
    await playlist.save();

    return res.status(201).json({ playlist: serializePlaylist(playlist) });
  } catch (error) {
    return next(error);
  }
};

export const removeTrackFromPlaylist = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    const playlistId = req.params.id;
    const trackId = req.params.trackId;

    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    if (!validatePlaylistId(playlistId) || !validatePlaylistId(trackId)) {
      return res.status(400).json({ error: "Invalid id supplied" });
    }

    const playlist = await Playlist.findOne({ _id: playlistId, ownerId: userId });
    if (!playlist) {
      return res.status(404).json({ error: "Playlist not found" });
    }

    const track = playlist.tracks.id(trackId);
    if (!track) {
      return res.status(404).json({ error: "Track not found in playlist" });
    }

    track.deleteOne();
    await playlist.save();

    return res.json({ playlist: serializePlaylist(playlist) });
  } catch (error) {
    return next(error);
  }
};

export const deletePlaylist = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    const playlistId = req.params.id;

    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    if (!validatePlaylistId(playlistId)) {
      return res.status(400).json({ error: "Invalid playlist id" });
    }

    const result = await Playlist.deleteOne({ _id: playlistId, ownerId: userId });
    if (result.deletedCount === 0) {
      return res.status(404).json({ error: "Playlist not found" });
    }

    return res.status(204).send();
  } catch (error) {
    return next(error);
  }
};
