import { Document, Schema, Types, model } from "mongoose";

export interface IYtmTrackSummary {
  title: string;
  artist: string | null;
  durationSeconds: number | null;
  videoId: string | null;
}

export interface IYtmPlaylist extends Document {
  userId: Types.ObjectId;
  ytmPlaylistId: string;
  name: string;
  itemCount: number;
  lastFetchedAt: Date;
  tracks: IYtmTrackSummary[];
  createdAt: Date;
  updatedAt: Date;
}

const trackSummarySchema = new Schema<IYtmTrackSummary>(
  {
    title: { type: String, required: true, trim: true },
    artist: { type: String, default: null, trim: true },
    durationSeconds: { type: Number, default: null, min: 0 },
    videoId: { type: String, default: null, trim: true },
  },
  {
    _id: false,
    versionKey: false,
  }
);

const ytmPlaylistSchema = new Schema<IYtmPlaylist>(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true, index: true },
    ytmPlaylistId: { type: String, required: true },
    name: { type: String, required: true },
    itemCount: { type: Number, required: true, min: 0 },
    lastFetchedAt: { type: Date, required: true },
    tracks: { type: [trackSummarySchema], default: [] },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

ytmPlaylistSchema.index({ userId: 1, ytmPlaylistId: 1 }, { unique: true });

export const YtmPlaylist = model<IYtmPlaylist>("YtmPlaylist", ytmPlaylistSchema);

export default YtmPlaylist;
