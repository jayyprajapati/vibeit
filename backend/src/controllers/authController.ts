import { NextFunction, Request, Response } from "express";
import Otp from "../models/Otp";
import User, { IUser } from "../models/User";
import env from "../config/env";
import { generateOtp, hashOtp, normalizeEmail, verifyOtpHash } from "../utils/otp";
import { signToken } from "../utils/jwt";

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const validateEmail = (email: string): boolean => EMAIL_REGEX.test(email);

const serializeUser = (user: IUser) => ({
  id: user._id.toString(),
  email: user.email,
  createdAt: user.createdAt,
  dailyUsageLimit: user.dailyUsageLimit,
  usageToday: user.usageToday,
});

export const requestOtp = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const rawEmail = (req.body?.email as string | undefined) || "";
    const email = normalizeEmail(rawEmail);

    if (!validateEmail(email)) {
      return res.status(400).json({ error: "Invalid email" });
    }

    const otp = generateOtp();
    const otpHash = await hashOtp(otp);
    const expiresAt = new Date(Date.now() + env.otpExpiryMinutes * 60 * 1000);

    await Otp.deleteMany({ email });
    await Otp.create({ email, otpHash, expiresAt });

    console.log(`[OTP] ${email} -> ${otp}`);

    return res.json({ message: "OTP generated" });
  } catch (error) {
    return next(error);
  }
};

export const verifyOtp = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const rawEmail = (req.body?.email as string | undefined) || "";
    const otp = (req.body?.otp as string | undefined) || "";
    const email = normalizeEmail(rawEmail);

    if (!validateEmail(email) || otp.length === 0) {
      return res.status(400).json({ error: "Email and OTP are required" });
    }

    const record = await Otp.findOne({ email }).sort({ expiresAt: -1 });
    if (!record) {
      return res.status(400).json({ error: "OTP not found. Please request a new one." });
    }

    if (record.expiresAt.getTime() < Date.now()) {
      await Otp.deleteMany({ email });
      return res.status(400).json({ error: "OTP has expired" });
    }

    const isValid = await verifyOtpHash(otp, record.otpHash);
    if (!isValid) {
      return res.status(400).json({ error: "Invalid OTP" });
    }

    await Otp.deleteMany({ email });

    let user = await User.findOne({ email });
    if (!user) {
      user = await User.create({ email });
    }

    const token = signToken({ userId: user._id.toString(), email: user.email });

    return res.json({ token, user: serializeUser(user) });
  } catch (error) {
    return next(error);
  }
};

export const getMe = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ error: "User not found" });
    }

    return res.json({ user: serializeUser(user) });
  } catch (error) {
    return next(error);
  }
};
