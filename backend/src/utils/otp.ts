import bcrypt from "bcryptjs";
import crypto from "crypto";

const OTP_LENGTH = 6;
const SALT_ROUNDS = 10;

export const generateOtp = (): string => {
  const min = 10 ** (OTP_LENGTH - 1);
  const max = 10 ** OTP_LENGTH - 1;
  return crypto.randomInt(min, max + 1).toString();
};

export const hashOtp = async (otp: string): Promise<string> => {
  return bcrypt.hash(otp, SALT_ROUNDS);
};

export const verifyOtpHash = async (otp: string, otpHash: string): Promise<boolean> => {
  return bcrypt.compare(otp, otpHash);
};

export const normalizeEmail = (email: string): string => email.trim().toLowerCase();
