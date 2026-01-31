import env from "../config/env";
import {
  SourceTrack,
  CandidateTrack,
  generateSearchQueries,
  resolveFromCandidates,
  logResolution,
} from "./trackResolver";

const TOKEN_URL = "https://accounts.spotify.com/api/token";
const API_BASE_URL = "https://api.spotify.com/v1";
export type SpotifyScopeLevel = "READ" | "WRITE";

const SPOTIFY_SCOPES_READ = ["playlist-read-private", "playlist-read-collaborative"];
const SPOTIFY_SCOPES_WRITE = [
  "playlist-read-private",
  "playlist-read-collaborative",
  "playlist-modify-private",
  "playlist-modify-public",
];

export interface SpotifyTokenResponse {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

export interface SpotifyRemotePlaylist {
  spotifyPlaylistId: string;
  name: string;
  trackCount: number;
}

export interface SpotifyRemoteTrack {
  title: string;
  artists: string[];
  album: string | null;
  durationMs: number | null;
  uri?: string;
}

export class SpotifyTokenExpiredError extends Error {
  constructor(message = "Spotify access token expired") {
    super(message);
    this.name = "SpotifyTokenExpiredError";
  }
}

export class SpotifyReauthRequiredError extends Error {
  constructor(message = "Spotify session expired. Please reconnect.") {
    super(message);
    this.name = "SpotifyReauthRequiredError";
  }
}

const encodeClientCredentials = () => {
  const { spotifyClientId, spotifyClientSecret } = env;
  if (!spotifyClientId || !spotifyClientSecret) {
    throw new Error("Spotify client credentials are missing");
  }
  return Buffer.from(`${spotifyClientId}:${spotifyClientSecret}`).toString("base64");
};

export const buildSpotifyAuthUrl = (state: string, level: SpotifyScopeLevel = "READ"): string => {
  if (!env.spotifyRedirectUri) {
    throw new Error("SPOTIFY_REDIRECT_URI is not configured");
  }

  const scopes = level === "WRITE" ? SPOTIFY_SCOPES_WRITE : SPOTIFY_SCOPES_READ;

  const params = new URLSearchParams({
    client_id: env.spotifyClientId,
    response_type: "code",
    redirect_uri: env.spotifyRedirectUri,
    scope: scopes.join(" "),
    state,
    show_dialog: "false",
  });

  return `https://accounts.spotify.com/authorize?${params.toString()}`;
};

const parseTokenError = async (resp: Response): Promise<{ message: string; reauth: boolean }> => {
  const status = resp.status;
  const raw = await resp.text();

  let errorCode: string | undefined;
  let description: string | undefined;

  try {
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    errorCode = (parsed["error"] as string | undefined) || undefined;
    description = (parsed["error_description"] as string | undefined) || undefined;
  } catch (parseError) {
    console.warn("[spotify] Failed to parse token error response", parseError);
  }

  const normalizedDesc = description?.toLowerCase?.() || "";
  const reauth = (status === 400 || status === 401 || status === 403) &&
    (errorCode === "invalid_grant" || normalizedDesc.includes("invalid_grant"));

  const messageParts = [
    `Spotify token request failed (${status})`,
    description || errorCode || raw || "Unknown error",
  ];

  return {
    message: messageParts.filter(Boolean).join(": "),
    reauth,
  };
};

const postToTokenEndpoint = async (body: URLSearchParams): Promise<SpotifyTokenResponse> => {
  const basic = encodeClientCredentials();
  let resp: Response;

  try {
    resp = await fetch(TOKEN_URL, {
      method: "POST",
      headers: {
        Authorization: `Basic ${basic}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: body.toString(),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown network error";
    throw new Error(`Spotify token request failed: ${message}`);
  }

  if (!resp.ok) {
    const { message, reauth } = await parseTokenError(resp);
    if (reauth) {
      throw new SpotifyReauthRequiredError(message);
    }
    throw new Error(message);
  }

  const data = (await resp.json()) as Record<string, unknown>;
  const accessToken = data["access_token"] as string | undefined;
  const refreshToken = (data["refresh_token"] as string | undefined) || "";
  const expiresIn = (data["expires_in"] as number | undefined) ?? 3600;

  if (!accessToken) {
    throw new Error("Spotify token response missing access_token");
  }

  return {
    accessToken,
    refreshToken,
    expiresIn,
  };
};

export const exchangeCodeForToken = async (code: string): Promise<SpotifyTokenResponse> => {
  const body = new URLSearchParams({
    grant_type: "authorization_code",
    code,
    redirect_uri: env.spotifyRedirectUri,
  });

  return postToTokenEndpoint(body);
};

export const refreshAccessToken = async (refreshToken: string): Promise<SpotifyTokenResponse> => {
  const body = new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: refreshToken,
  });

  const response = await postToTokenEndpoint(body);
  return {
    ...response,
    refreshToken: response.refreshToken || refreshToken,
  };
};

const SEARCH_BASE_URL = `${API_BASE_URL}/search`;

/**
 * Search Spotify and resolve the best matching track using scoring.
 * Uses multiple search queries as fallback for maximum match rate.
 *
 * @returns Spotify URI of the best match, or null if no acceptable match found
 */
export const searchSpotifyTrackExact = async (
  accessToken: string,
  title: string,
  artist: string
): Promise<string | null> => {
  const source: SourceTrack = { title, artist };
  const queries = generateSearchQueries(source);

  console.log(`[spotify-search] Resolving: "${title}" by "${artist}"`);

  // Try each query until we find a good match
  for (const query of queries) {
    const result = await searchSpotifyWithQuery(accessToken, source, query);

    if (result.success) {
      logResolution(source, result, "spotify");
      return result.matchedId;
    }
  }

  // All queries exhausted, no match found
  console.warn(`[spotify-search] ✗ FAILED to resolve: "${title}" by "${artist}"`);
  return null;
};

/**
 * Execute a single Spotify search query and score the results.
 */
const searchSpotifyWithQuery = async (
  accessToken: string,
  source: SourceTrack,
  query: string
) => {
  const encodedQuery = encodeURIComponent(query);
  const url = `${SEARCH_BASE_URL}?q=${encodedQuery}&type=track&limit=15`;

  try {
    const data = await fetchSpotifyJson(url, accessToken);
    const tracks = ((data["tracks"] as Record<string, unknown> | undefined)?.["items"] as Array<Record<string, unknown>> | undefined) || [];

    // Convert to CandidateTrack format
    const candidates = tracks
      .map((t): CandidateTrack | null => {
        const name = (t["name"] as string | undefined) || "";
        const artistsArr = (t["artists"] as Array<Record<string, unknown>> | undefined) || [];
        const primary = (artistsArr[0]?.["name"] as string | undefined) || "";
        const uri = t["uri"] as string | undefined;
        const allArtists = artistsArr
          .map((a) => (a["name"] as string | undefined) || "")
          .filter(Boolean)
          .join(" ");

        if (!uri) return null;

        return {
          id: uri,
          title: name,
          channel: primary,           // Primary artist as "channel"
          description: allArtists,    // All artists for matching
        };
      })
      .filter((c): c is CandidateTrack => c !== null);

    // Use scoring-based resolution
    return resolveFromCandidates(source, candidates, query);

  } catch (error) {
    if (error instanceof SpotifyTokenExpiredError) throw error;

    console.error(`[spotify-search] Search failed for query "${query}":`, error);
    return {
      success: false,
      matchedId: null,
      matchedTitle: null,
      matchedChannel: null,
      score: 0,
      confidence: "rejected" as const,
      queryUsed: query,
      candidatesEvaluated: 0,
      candidatesRejected: 0,
      allScores: [],
    };
  }
};

export const addTracksToSpotifyPlaylist = async (
  accessToken: string,
  playlistId: string,
  uris: string[]
): Promise<void> => {
  if (uris.length === 0) return;
  const url = `${API_BASE_URL}/playlists/${playlistId}/tracks`;
  const resp = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ uris }),
  });

  if (resp.status === 401) {
    throw new SpotifyTokenExpiredError();
  }

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`Spotify add tracks failed (${resp.status}): ${text}`);
  }
};

export const createSpotifyPlaylist = async (
  accessToken: string,
  name: string
): Promise<string> => {
  const url = `${API_BASE_URL}/me/playlists`;
  const resp = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      name,
      public: false,
      description: "Created by VibeIt transfer",
    }),
  });

  if (resp.status === 401) {
    throw new SpotifyTokenExpiredError();
  }

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`Spotify create playlist failed (${resp.status}): ${text}`);
  }

  const data = (await resp.json()) as Record<string, unknown>;
  const playlistId = (data["id"] as string | undefined) || null;
  if (!playlistId) {
    throw new Error("Spotify create playlist response missing id");
  }

  return playlistId;
};

export const removeTracksFromSpotifyPlaylist = async (
  accessToken: string,
  playlistId: string,
  uris: string[]
): Promise<void> => {
  if (uris.length === 0) return;
  const url = `${API_BASE_URL}/playlists/${playlistId}/tracks`;
  const resp = await fetch(url, {
    method: "DELETE",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ tracks: uris.map((uri) => ({ uri })) }),
  });

  if (resp.status === 401) {
    throw new SpotifyTokenExpiredError();
  }

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`Spotify remove tracks failed (${resp.status}): ${text}`);
  }
};

export const fetchSpotifyPlaylists = async (
  accessToken: string
): Promise<SpotifyRemotePlaylist[]> => {
  const playlists: SpotifyRemotePlaylist[] = [];
  let nextUrl: string | null = `${API_BASE_URL}/me/playlists?limit=50`;

  while (nextUrl) {
    const resp = await fetch(nextUrl, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (resp.status === 401) {
      throw new Error("Spotify access token expired");
    }

    if (!resp.ok) {
      const text = await resp.text();
      throw new Error(`Spotify playlists request failed (${resp.status}): ${text}`);
    }

    const data = (await resp.json()) as Record<string, unknown>;
    const items = (data["items"] as Array<Record<string, unknown>> | undefined) || [];
    for (const item of items) {
      const id = item["id"] as string | undefined;
      const name = item["name"] as string | undefined;
      const tracks = (item["tracks"] as Record<string, unknown> | undefined) || {};
      const total = (tracks["total"] as number | undefined) ?? 0;

      if (id && name) {
        playlists.push({
          spotifyPlaylistId: id,
          name,
          trackCount: total,
        });
      }
    }

    nextUrl = (data["next"] as string | null | undefined) || null;
  }

  return playlists;
};

const fetchSpotifyJson = async (url: string, accessToken: string): Promise<Record<string, unknown>> => {
  const resp = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (resp.status === 401) {
    throw new SpotifyTokenExpiredError();
  }

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`Spotify request failed (${resp.status}): ${text}`);
  }

  return (await resp.json()) as Record<string, unknown>;
};

export const fetchSpotifyPlaylistWithTracks = async (
  accessToken: string,
  playlistId: string
): Promise<{ name: string; tracks: SpotifyRemoteTrack[]; total: number }> => {
  const firstUrl = `${API_BASE_URL}/playlists/${playlistId}?fields=name,tracks(items(track(name,artists(name),album(name),duration_ms)),next,limit,offset,total)`;
  let data = await fetchSpotifyJson(firstUrl, accessToken);

  const name = (data["name"] as string | undefined) || "Spotify Playlist";
  const tracks: SpotifyRemoteTrack[] = [];
  let nextUrl = (data["tracks"] as Record<string, unknown> | undefined)?.["next"] as string | null | undefined;

  const collect = (items: Array<Record<string, unknown>> | undefined) => {
    if (!items) return;
    for (const item of items) {
      const track = item["track"] as Record<string, unknown> | undefined;
      if (!track) continue;
      const title = (track["name"] as string | undefined) || "";
      const artistsArr = (track["artists"] as Array<Record<string, unknown>> | undefined) || [];
      const artists = artistsArr
        .map((artist) => (artist["name"] as string | undefined)?.trim())
        .filter((a): a is string => !!a && a.length > 0);
      const albumName = (track["album"] as Record<string, unknown> | undefined)?.["name"] as string | undefined;
      const durationMs = (track["duration_ms"] as number | undefined) ?? null;
      const uri = track["uri"] as string | undefined;

      tracks.push({
        title: title.trim(),
        artists,
        album: albumName?.trim() ?? null,
        durationMs,
        uri,
      });
    }
  };

  const trackObj = (data["tracks"] as Record<string, unknown> | undefined) || {};
  collect((trackObj["items"] as Array<Record<string, unknown>> | undefined) || []);

  while (nextUrl) {
    data = await fetchSpotifyJson(nextUrl, accessToken);
    const items = (data["items"] as Array<Record<string, unknown>> | undefined) || [];
    collect(items);
    nextUrl = (data["next"] as string | null | undefined) || null;
  }

  const total = (trackObj["total"] as number | undefined) ?? tracks.length;
  return { name, tracks, total };
};
