import { NextFunction, Request, Response } from "express";
import { getExplorePayload } from "../services/exploreService";

export const getExplore = async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const payload = await getExplorePayload();
    return res.json(payload);
  } catch (error) {
    return next(error);
  }
};
