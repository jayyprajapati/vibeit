import express, { NextFunction, Request, Response } from "express";
import cors from "cors";
import authRoutes from "./routes/authRoutes";
import playlistRoutes from "./routes/playlistRoutes";
import searchRoutes from "./routes/searchRoutes";
import spotifyRoutes from "./routes/spotifyRoutes";
import ytmRoutes from "./routes/ytmRoutes";
import syncRoutes from "./routes/syncRoutes";
import transferRoutes from "./routes/transferRoutes";
import exploreRoutes from "./routes/exploreRoutes";
import preferencesRoutes from "./routes/preferencesRoutes";
import { authMiddleware } from "./middleware/authMiddleware";
import { getMe, getPlatformAccess } from "./controllers/authController";

const app = express();

app.use(cors());
app.use(express.json());

app.get("/health", (_: Request, res: Response) => {
  res.json({ status: "ok" });
});

app.use("/auth", authRoutes);
app.get("/me", authMiddleware, getMe);
app.get("/me/platform-access", authMiddleware, getPlatformAccess);
app.use("/", preferencesRoutes);  // Mounts /me/preferences routes
app.use("/playlists", playlistRoutes);
app.use("/search", searchRoutes);
app.use("/spotify", spotifyRoutes);
app.use("/ytm", ytmRoutes);
app.use("/sync", syncRoutes);
app.use("/transfer", transferRoutes);
app.use("/explore", exploreRoutes);

// Catch-all for unknown routes so errors flow through the central handler.
app.use((_: Request, res: Response, next: NextFunction) => {
  res.status(404);
  const error = new Error("Not Found");
  next(error);
});

// Centralized error handler to keep responses consistent.
// eslint-disable-next-line @typescript-eslint/no-unused-vars
app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
  const statusCode = res.statusCode && res.statusCode !== 200 ? res.statusCode : 500;
  const message = err instanceof Error ? err.message : "Internal Server Error";

  res.status(statusCode).json({ error: message });
});

export default app;
