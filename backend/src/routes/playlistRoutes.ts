import { Router } from "express";
import { authMiddleware } from "../middleware/authMiddleware";
import {
  addTrackToPlaylist,
  createPlaylist,
  getPlaylistById,
  listPlaylists,
  removeTrackFromPlaylist,
} from "../controllers/playlistController";

const router = Router();

router.use(authMiddleware);

router.post("/", createPlaylist);
router.get("/", listPlaylists);
router.get("/:id", getPlaylistById);
router.post("/:id/tracks", addTrackToPlaylist);
router.delete("/:id/tracks/:trackId", removeTrackFromPlaylist);

export default router;
