import { Document, Schema, Types, model } from "mongoose";

export interface IYtmAccount extends Document {
  userId: Types.ObjectId;
  accessToken: string;
  refreshToken: string;
  expiresAt: Date;
  scopeLevel: "READ" | "WRITE";
  createdAt: Date;
  updatedAt: Date;
}

const ytmAccountSchema = new Schema<IYtmAccount>(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true, unique: true, index: true },
    accessToken: { type: String, required: true },
    refreshToken: { type: String, required: true },
    expiresAt: { type: Date, required: true },
    scopeLevel: { type: String, enum: ["READ", "WRITE"], default: "READ" },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

export const YtmAccount = model<IYtmAccount>("YtmAccount", ytmAccountSchema);

export default YtmAccount;
