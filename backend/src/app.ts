import express, { NextFunction, Request, Response } from "express";
import cors from "cors";
import authRoutes from "./routes/authRoutes";
import { authMiddleware } from "./middleware/authMiddleware";
import { getMe } from "./controllers/authController";

const app = express();

app.use(cors());
app.use(express.json());

app.get("/health", (_: Request, res: Response) => {
  res.json({ status: "ok" });
});

app.use("/auth", authRoutes);
app.get("/me", authMiddleware, getMe);

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
