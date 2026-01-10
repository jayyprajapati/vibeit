import dotenv from "dotenv";

dotenv.config();

const DEFAULT_PORT = 3000;
const port = Number(process.env.PORT) || DEFAULT_PORT;
const mongoUri = process.env.MONGO_URI || "mongodb://127.0.0.1:27017/vibeit";
const jwtSecret = process.env.JWT_SECRET || "change-me-in-prod";
const otpExpiryMinutes = Number(process.env.OTP_EXPIRY_MINUTES) || 5;
const spotifyClientId = process.env.SPOTIFY_CLIENT_ID || "";
const spotifyClientSecret = process.env.SPOTIFY_CLIENT_SECRET || "";
const spotifyRedirectUri = process.env.SPOTIFY_REDIRECT_URI || "";
const spotifyFrontendRedirect = process.env.SPOTIFY_FRONTEND_REDIRECT || "http://localhost:5173/platforms";
const googleClientId = process.env.GOOGLE_CLIENT_ID || "";
const googleClientSecret = process.env.GOOGLE_CLIENT_SECRET || "";
const ytmRedirectUri = process.env.YTM_REDIRECT_URI || "";
const ytmFrontendRedirect = process.env.YTM_FRONTEND_REDIRECT || "http://localhost:5173/platforms";

export const env = {
  port,
  mongoUri,
  jwtSecret,
  otpExpiryMinutes,
  spotifyClientId,
  spotifyClientSecret,
  spotifyRedirectUri,
  spotifyFrontendRedirect,
  googleClientId,
  googleClientSecret,
  ytmRedirectUri,
  ytmFrontendRedirect,
};

export default env;
