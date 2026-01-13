import { Schema, model, Document, Types } from "mongoose";

export interface ITrack extends Types.Subdocument {
  _id: Types.ObjectId;
  title: string;
  artist: string;
  album: string;
  duration: number;
  musicBrainzRecordingId?: string | null;
  normalizedTitle?: string | null;
  normalizedArtist?: string | null;
  source?: string | null;
  createdAt?: Date;
}

export interface IPlaylist extends Document {
  _id: Types.ObjectId;
  name: string;
  ownerId: Types.ObjectId;
  tracks: Types.DocumentArray<ITrack>;
  source: "internal";
  createdAt: Date;
  updatedAt: Date;
}

const trackSchema = new Schema<ITrack>(
  {
    title: { type: String, required: true, trim: true },
    artist: { type: String, required: true, trim: true },
    album: { type: String, required: true, trim: true },
    duration: { type: Number, required: true, min: 1 },
    musicBrainzRecordingId: { type: String, default: null, trim: true },
    normalizedTitle: { type: String, default: null, trim: true },
    normalizedArtist: { type: String, default: null, trim: true },
    source: { type: String, default: null, trim: true },
    createdAt: { type: Date, default: Date.now },
  },
  {
    _id: true,
    versionKey: false,
  }
);

const playlistSchema = new Schema<IPlaylist>(
  {
    name: { type: String, required: true, trim: true },
    ownerId: { type: Schema.Types.ObjectId, ref: "User", required: true, index: true },
    tracks: { type: [trackSchema], default: [] },
    source: { type: String, enum: ["internal"], default: "internal" },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

export const Playlist = model<IPlaylist>("Playlist", playlistSchema);

export default Playlist;