import { Router } from "express";
import { authMiddleware } from "../middleware/authMiddleware";
import { getExplore } from "../controllers/exploreController";

const router = Router();

router.get("/", authMiddleware, getExplore);

export default router;
