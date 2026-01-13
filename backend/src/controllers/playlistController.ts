import { NextFunction, Request, Response } from "express";
import { Types } from "mongoose";
import Playlist, { IPlaylist } from "../models/Playlist";

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
  })),
});

const validatePlaylistId = (playlistId: string): boolean => Types.ObjectId.isValid(playlistId);

const validateTrackPayload = (payload: Record<string, unknown>) => {
  const title = (payload.title as string | undefined)?.trim() || "";
  const artist = (payload.artist as string | undefined)?.trim() || "";
  const album = (payload.album as string | undefined)?.trim() || "";
  const duration = Number(payload.duration);

  if (!title) return "Track title is required";
  if (!artist) return "Track artist is required";
  if (!album) return "Track album is required";
  if (!Number.isFinite(duration) || duration <= 0) return "Track duration must be a positive number";

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

    const track = {
      title: (req.body.title as string).trim(),
      artist: (req.body.artist as string).trim(),
      album: (req.body.album as string).trim(),
      duration: Number(req.body.duration),
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
