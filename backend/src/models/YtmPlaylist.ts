import { Document, Schema, Types, model } from "mongoose";

export interface IYtmPlaylist extends Document {
  userId: Types.ObjectId;
  ytmPlaylistId: string;
  name: string;
  itemCount: number;
  lastFetchedAt: Date;
  createdAt: Date;
  updatedAt: Date;
}

const ytmPlaylistSchema = new Schema<IYtmPlaylist>(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true, index: true },
    ytmPlaylistId: { type: String, required: true },
    name: { type: String, required: true },
    itemCount: { type: Number, required: true, min: 0 },
    lastFetchedAt: { type: Date, required: true },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

ytmPlaylistSchema.index({ userId: 1, ytmPlaylistId: 1 }, { unique: true });

export const YtmPlaylist = model<IYtmPlaylist>("YtmPlaylist", ytmPlaylistSchema);

export default YtmPlaylist;
