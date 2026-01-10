import { Router } from "express";
import { authMiddleware } from "../middleware/authMiddleware";
import { executeSync, previewSync } from "../controllers/syncController";

const router = Router();

router.post("/preview", authMiddleware, previewSync);
router.post("/execute", authMiddleware, executeSync);

export default router;
