import { Router } from "express";
import { authMiddleware } from "../middleware/authMiddleware";
import { searchSongs } from "../controllers/searchController";

const router = Router();

router.get("/songs", authMiddleware, searchSongs);

export default router;
