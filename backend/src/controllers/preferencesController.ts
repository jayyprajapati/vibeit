import { Request, Response } from "express";
import User from "../models/User";

/**
 * Get user preferences
 * GET /me/preferences
 */
export const getPreferences = async (req: Request, res: Response) => {
    try {
        const userId = req.user?.userId;
        if (!userId) {
            return res.status(401).json({ error: "Unauthorized" });
        }

        const user = await User.findById(userId).select(
            "preferredMusicPlatform themeMode onboardingComplete"
        );

        if (!user) {
            return res.status(404).json({ error: "User not found" });
        }

        res.json({
            preferredMusicPlatform: user.preferredMusicPlatform || null,
            themeMode: user.themeMode || "light",
            onboardingComplete: user.onboardingComplete || false,
        });
    } catch (error) {
        console.error("Get preferences error:", error);
        res.status(500).json({ error: "Failed to get preferences" });
    }
};

/**
 * Update user preferences
 * PUT /me/preferences
 */
export const updatePreferences = async (req: Request, res: Response) => {
    try {
        const userId = req.user?.userId;
        if (!userId) {
            return res.status(401).json({ error: "Unauthorized" });
        }

        const { preferredMusicPlatform, themeMode, onboardingComplete } = req.body;

        const updateFields: Record<string, unknown> = {};

        // Validate and set preferredMusicPlatform
        if (preferredMusicPlatform !== undefined) {
            if (preferredMusicPlatform !== null && !["spotify", "ytm"].includes(preferredMusicPlatform)) {
                return res.status(400).json({ error: "Invalid preferredMusicPlatform. Must be 'spotify' or 'ytm'" });
            }
            updateFields.preferredMusicPlatform = preferredMusicPlatform;
        }

        // Validate and set themeMode
        if (themeMode !== undefined) {
            if (!["light", "dark", "system"].includes(themeMode)) {
                return res.status(400).json({ error: "Invalid themeMode. Must be 'light', 'dark', or 'system'" });
            }
            updateFields.themeMode = themeMode;
        }

        // Set onboardingComplete
        if (onboardingComplete !== undefined) {
            updateFields.onboardingComplete = Boolean(onboardingComplete);
        }

        if (Object.keys(updateFields).length === 0) {
            return res.status(400).json({ error: "No valid fields to update" });
        }

        const user = await User.findByIdAndUpdate(
            userId,
            { $set: updateFields },
            { new: true }
        ).select("preferredMusicPlatform themeMode onboardingComplete");

        if (!user) {
            return res.status(404).json({ error: "User not found" });
        }

        res.json({
            preferredMusicPlatform: user.preferredMusicPlatform || null,
            themeMode: user.themeMode || "light",
            onboardingComplete: user.onboardingComplete || false,
        });
    } catch (error) {
        console.error("Update preferences error:", error);
        res.status(500).json({ error: "Failed to update preferences" });
    }
};
