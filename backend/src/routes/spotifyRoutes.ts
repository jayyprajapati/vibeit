import { Router } from "express";
import { authMiddleware } from "../middleware/authMiddleware";
import {
  getSpotifyAuthUrl,
  getSpotifyPlaylists,
  getSpotifyPlaylistDetail,
  importSpotifyPlaylist,
  spotifyCallback,
  syncSpotifyNow,
  disconnectSpotify,
} from "../controllers/spotifyController";

const router = Router();

router.get("/auth-url", authMiddleware, getSpotifyAuthUrl);
router.get("/callback", spotifyCallback);
router.get("/playlists", authMiddleware, getSpotifyPlaylists);
router.get("/playlists/:spotifyPlaylistId", authMiddleware, getSpotifyPlaylistDetail);
router.post("/sync-now", authMiddleware, syncSpotifyNow);
router.post("/import/:spotifyPlaylistId", authMiddleware, importSpotifyPlaylist);
router.delete("/disconnect", authMiddleware, disconnectSpotify);

export default router;
