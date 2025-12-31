import { Request, Response } from "express";

const MOCK_TRACKS = [
  { id: "int-1", title: "Midnight Drive", artist: "Neon Skyline", album: "City Lights", duration: 214 },
  { id: "int-2", title: "Golden Hour", artist: "Aurora Lane", album: "Sunset Bloom", duration: 198 },
  { id: "int-3", title: "Echoes", artist: "Paper Trails", album: "Reflections", duration: 245 },
  { id: "int-4", title: "Ocean Air", artist: "Low Tide", album: "Coastline", duration: 221 },
  { id: "int-5", title: "Slow Burn", artist: "Flicker", album: "Embers", duration: 207 },
  { id: "int-6", title: "Northern Lights", artist: "Arctic Bloom", album: "Skyline", duration: 232 },
  { id: "int-7", title: "Paper Lanterns", artist: "Eastward", album: "Festival", duration: 188 },
  { id: "int-8", title: "Home Again", artist: "Grey Street", album: "Backyard Stories", duration: 204 },
  { id: "int-9", title: "Signal", artist: "Analog Kids", album: "Static", duration: 176 },
  { id: "int-10", title: "Afterglow", artist: "Moonrise", album: "Horizon", duration: 229 },
];

export const searchTracks = (req: Request, res: Response) => {
  const query = (req.query.q as string | undefined)?.trim().toLowerCase() || "";

  const results = query
    ? MOCK_TRACKS.filter((track) => {
        const haystack = `${track.title} ${track.artist} ${track.album}`.toLowerCase();
        return haystack.includes(query);
      })
    : MOCK_TRACKS;

  res.json({ tracks: results });
};
