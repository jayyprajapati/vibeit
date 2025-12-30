import { Schema, model, Document, Types } from "mongoose";

export interface IUser extends Document {
  _id: Types.ObjectId;
  email: string;
  createdAt: Date;
  dailyUsageLimit: number;
  usageToday: number;
}

const userSchema = new Schema<IUser>(
  {
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    createdAt: { type: Date, default: Date.now },
    dailyUsageLimit: { type: Number, default: 50 },
    usageToday: { type: Number, default: 0 },
  },
  {
    timestamps: false,
    versionKey: false,
  }
);

export const User = model<IUser>("User", userSchema);

export default User;
