import { Document, Schema, Types, model } from "mongoose";

export interface ISpotifyTrackSummary {
  name: string;
  artist: string;
}

export interface ISpotifyPlaylist extends Document {
  userId: Types.ObjectId;
  spotifyPlaylistId: string;
  name: string;
  trackCount: number;
  lastFetchedAt: Date;
  tracks: ISpotifyTrackSummary[];
  createdAt: Date;
  updatedAt: Date;
}

const trackSummarySchema = new Schema<ISpotifyTrackSummary>(
  {
    name: { type: String, required: true, trim: true },
    artist: { type: String, required: true, trim: true },
  },
  {
    _id: false,
    versionKey: false,
  }
);

const spotifyPlaylistSchema = new Schema<ISpotifyPlaylist>(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true, index: true },
    spotifyPlaylistId: { type: String, required: true },
    name: { type: String, required: true },
    trackCount: { type: Number, required: true, min: 0 },
    lastFetchedAt: { type: Date, required: true },
    tracks: { type: [trackSummarySchema], default: [] },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

spotifyPlaylistSchema.index({ userId: 1, spotifyPlaylistId: 1 }, { unique: true });

export const SpotifyPlaylist = model<ISpotifyPlaylist>("SpotifyPlaylist", spotifyPlaylistSchema);

export default SpotifyPlaylist;
