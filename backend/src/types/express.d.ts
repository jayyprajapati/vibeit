import { JwtPayload } from "../utils/jwt";

declare global {
  namespace Express {
    // Augment Express' Request to include the authenticated user payload.
    interface Request {
      user?: JwtPayload;
    }
  }
}

export {};
