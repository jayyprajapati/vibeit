import { Router } from "express";
import { authMiddleware } from "../middleware/authMiddleware";
import {
  getSpotifyAuthUrl,
  getSpotifyPlaylists,
  spotifyCallback,
  syncSpotifyNow,
} from "../controllers/spotifyController";

const router = Router();

router.get("/auth-url", authMiddleware, getSpotifyAuthUrl);
router.get("/callback", spotifyCallback);
router.get("/playlists", authMiddleware, getSpotifyPlaylists);
router.post("/sync-now", authMiddleware, syncSpotifyNow);

export default router;
