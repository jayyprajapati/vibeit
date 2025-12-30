import dotenv from "dotenv";

dotenv.config();

const DEFAULT_PORT = 3000;
const port = Number(process.env.PORT) || DEFAULT_PORT;
const mongoUri = process.env.MONGO_URI || "mongodb://127.0.0.1:27017/vibeit";
const jwtSecret = process.env.JWT_SECRET || "change-me-in-prod";
const otpExpiryMinutes = Number(process.env.OTP_EXPIRY_MINUTES) || 5;

export const env = {
  port,
  mongoUri,
  jwtSecret,
  otpExpiryMinutes,
};

export default env;
