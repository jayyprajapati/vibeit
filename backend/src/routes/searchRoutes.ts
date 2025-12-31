import { Router } from "express";
import { authMiddleware } from "../middleware/authMiddleware";
import { searchTracks } from "../controllers/searchController";

const router = Router();

router.get("/tracks", authMiddleware, searchTracks);

export default router;
