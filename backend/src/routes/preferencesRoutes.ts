import { Router } from "express";
import { getPreferences, updatePreferences } from "../controllers/preferencesController";
import { authMiddleware } from "../middleware/authMiddleware";

const router = Router();

// All routes require authentication
router.use(authMiddleware);

// GET /me/preferences - Get user preferences
router.get("/me/preferences", getPreferences);

// PUT /me/preferences - Update user preferences  
router.put("/me/preferences", updatePreferences);

export default router;
