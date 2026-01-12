import { Router } from "express";
import { authMiddleware } from "../middleware/authMiddleware";
import { executeTransfer, previewTransfer } from "../controllers/transferController";

const router = Router();

router.use(authMiddleware);
router.post("/preview", previewTransfer);
router.post("/execute", executeTransfer);

export default router;
