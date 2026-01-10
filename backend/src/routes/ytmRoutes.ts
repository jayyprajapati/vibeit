import { Router } from "express";
import { authMiddleware } from "../middleware/authMiddleware";
import { getYtmAuthUrl, getYtmPlaylists, syncYtmNow, ytmCallback } from "../controllers/ytmController";

const router = Router();

router.get("/auth-url", authMiddleware, getYtmAuthUrl);
router.get("/callback", ytmCallback);
router.get("/playlists", authMiddleware, getYtmPlaylists);
router.post("/sync-now", authMiddleware, syncYtmNow);

export default router;
