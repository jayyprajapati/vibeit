import { Schema, model, Document, Types } from "mongoose";

export type MusicPlatform = "spotify" | "ytm";
export type ThemeMode = "light" | "dark" | "system";

export interface IUser extends Document {
  _id: Types.ObjectId;
  email: string;
  createdAt: Date;
  dailyUsageLimit: number;
  usageToday: number;
  // User preferences
  preferredMusicPlatform?: MusicPlatform;
  themeMode?: ThemeMode;
  onboardingComplete?: boolean;
}

const userSchema = new Schema<IUser>(
  {
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    createdAt: { type: Date, default: Date.now },
    dailyUsageLimit: { type: Number, default: 50 },
    usageToday: { type: Number, default: 0 },
    preferredMusicPlatform: { type: String, enum: ["spotify", "ytm"], default: undefined },
    themeMode: { type: String, enum: ["light", "dark", "system"], default: "light" },
    onboardingComplete: { type: Boolean, default: false },
  },
  {
    timestamps: false,
    versionKey: false,
  }
);

export const User = model<IUser>("User", userSchema);

export default User;
