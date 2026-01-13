import { NextFunction, Request, Response } from "express";
import { searchSongs as searchMusicBrainzSongs } from "../services/musicbrainzService";

export const searchSongs = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const query = (req.query.q as string | undefined)?.trim() ?? "";

    if (!query) {
      return res.status(400).json({ error: "Query is required" });
    }

    const results = await searchMusicBrainzSongs(query);
    return res.json({ results });
  } catch (error) {
    const message = error instanceof Error ? error.message : "";
    if (message.includes("MUSICBRAINZ_FETCH_ERROR")) {
      return res.status(502).json({ error: "MusicBrainz search is currently unavailable. Please try again." });
    }

    return next(error);
  }
};
