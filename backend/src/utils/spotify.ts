import env from "../config/env";

const TOKEN_URL = "https://accounts.spotify.com/api/token";
const API_BASE_URL = "https://api.spotify.com/v1";
const SPOTIFY_SCOPES = ["playlist-read-private", "playlist-read-collaborative"].join(" ");

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

const encodeClientCredentials = () => {
  const { spotifyClientId, spotifyClientSecret } = env;
  if (!spotifyClientId || !spotifyClientSecret) {
    throw new Error("Spotify client credentials are missing");
  }
  return Buffer.from(`${spotifyClientId}:${spotifyClientSecret}`).toString("base64");
};

export const buildSpotifyAuthUrl = (state: string): string => {
  if (!env.spotifyRedirectUri) {
    throw new Error("SPOTIFY_REDIRECT_URI is not configured");
  }

  const params = new URLSearchParams({
    client_id: env.spotifyClientId,
    response_type: "code",
    redirect_uri: env.spotifyRedirectUri,
    scope: SPOTIFY_SCOPES,
    state,
    show_dialog: "false",
  });

  return `https://accounts.spotify.com/authorize?${params.toString()}`;
};

const postToTokenEndpoint = async (body: URLSearchParams): Promise<SpotifyTokenResponse> => {
  const basic = encodeClientCredentials();
  const resp = await fetch(TOKEN_URL, {
    method: "POST",
    headers: {
      Authorization: `Basic ${basic}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: body.toString(),
  });

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`Spotify token request failed (${resp.status}): ${text}`);
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
