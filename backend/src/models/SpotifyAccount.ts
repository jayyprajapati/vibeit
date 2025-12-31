import { Document, Schema, Types, model } from "mongoose";

export interface ISpotifyAccount extends Document {
  userId: Types.ObjectId;
  accessToken: string;
  refreshToken: string;
  expiresAt: Date;
  createdAt: Date;
  updatedAt: Date;
}

const spotifyAccountSchema = new Schema<ISpotifyAccount>(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true, unique: true, index: true },
    accessToken: { type: String, required: true },
    refreshToken: { type: String, required: true },
    expiresAt: { type: Date, required: true },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

export const SpotifyAccount = model<ISpotifyAccount>("SpotifyAccount", spotifyAccountSchema);

export default SpotifyAccount;
