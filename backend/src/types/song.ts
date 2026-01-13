export interface Song {
  id: string;
  title: string;
  normalizedTitle: string;
  primaryArtist: string;
  normalizedArtist: string;
  album?: string;
  year?: number;
  source: "MUSICBRAINZ";
  musicBrainzRecordingId: string;
  durationSeconds?: number;
}
