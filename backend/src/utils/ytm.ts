import env from "../config/env";

const TOKEN_URL = "https://oauth2.googleapis.com/token";
const AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth";
const API_BASE_URL = "https://www.googleapis.com/youtube/v3";
export type YtmScopeLevel = "READ" | "WRITE";
const YTM_SCOPE_READ = "https://www.googleapis.com/auth/youtube.readonly";
const YTM_SCOPE_WRITE = "https://www.googleapis.com/auth/youtube.force-ssl";

export interface YtmTokenResponse {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

export interface YtmRemotePlaylist {
  ytmPlaylistId: string;
  name: string;
  itemCount: number;
}

export class YtmTokenExpiredError extends Error {
  constructor(message = "YouTube Music access token expired") {
    super(message);
    this.name = "YtmTokenExpiredError";
  }
}

const postToTokenEndpoint = async (body: URLSearchParams): Promise<YtmTokenResponse> => {
  if (!env.googleClientId || !env.googleClientSecret) {
    throw new Error("Google client credentials are missing");
  }

  const resp = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  });

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`Google token request failed (${resp.status}): ${text}`);
  }

  const data = (await resp.json()) as Record<string, unknown>;
  const accessToken = data["access_token"] as string | undefined;
  const refreshToken = (data["refresh_token"] as string | undefined) || "";
  const expiresIn = (data["expires_in"] as number | undefined) ?? 3600;

  if (!accessToken) {
    throw new Error("Google token response missing access_token");
  }

  return {
    accessToken,
    refreshToken,
    expiresIn,
  };
};

export const buildYtmAuthUrl = (state: string, level: YtmScopeLevel = "READ"): string => {
  if (!env.ytmRedirectUri || !env.googleClientId) {
    throw new Error("YouTube Music OAuth is not configured");
  }

  const scope = level === "WRITE" ? YTM_SCOPE_WRITE : YTM_SCOPE_READ;

  const params = new URLSearchParams({
    client_id: env.googleClientId,
    redirect_uri: env.ytmRedirectUri,
    response_type: "code",
    scope,
    access_type: "offline",
    include_granted_scopes: "true",
    prompt: "consent",
    state,
  });

  return `${AUTH_URL}?${params.toString()}`;
};

export const exchangeCodeForToken = async (code: string): Promise<YtmTokenResponse> => {
  const body = new URLSearchParams({
    grant_type: "authorization_code",
    code,
    client_id: env.googleClientId,
    client_secret: env.googleClientSecret,
    redirect_uri: env.ytmRedirectUri,
  });

  return postToTokenEndpoint(body);
};

export const refreshAccessToken = async (refreshToken: string): Promise<YtmTokenResponse> => {
  const body = new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: refreshToken,
    client_id: env.googleClientId,
    client_secret: env.googleClientSecret,
  });

  const response = await postToTokenEndpoint(body);
  return {
    ...response,
    refreshToken: response.refreshToken || refreshToken,
  };
};

export const fetchYtmPlaylists = async (accessToken: string): Promise<YtmRemotePlaylist[]> => {
  const playlists: YtmRemotePlaylist[] = [];
  let pageToken: string | null = null;

  while (true) {
    const params = new URLSearchParams({
      part: "snippet,contentDetails",
      mine: "true",
      maxResults: "50",
    });

    if (pageToken) {
      params.set("pageToken", pageToken);
    }

    const url = `${API_BASE_URL}/playlists?${params.toString()}`;

    const resp = await fetch(url, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (resp.status === 401) {
      throw new YtmTokenExpiredError();
    }

    if (!resp.ok) {
      const text = await resp.text();
      throw new Error(`YouTube playlists request failed (${resp.status}): ${text}`);
    }

    const data = (await resp.json()) as Record<string, unknown>;
    const items = (data["items"] as Array<Record<string, unknown>> | undefined) || [];

    for (const item of items) {
      const id = item["id"] as string | undefined;
      const snippet = item["snippet"] as Record<string, unknown> | undefined;
      const title = snippet?.["title"] as string | undefined;
      const contentDetails = item["contentDetails"] as Record<string, unknown> | undefined;
      const count = (contentDetails?.["itemCount"] as number | undefined) ?? 0;

      if (id && title) {
        playlists.push({ ytmPlaylistId: id, name: title, itemCount: count });
      }
    }

    pageToken = (data["nextPageToken"] as string | null | undefined) || null;
    if (!pageToken) break;
  }

  return playlists;
};

interface YtmPlaylistTrack {
  title: string;
  artist: string | null;
  videoId: string;
  playlistItemId: string;
}

export const fetchYtmPlaylistWithTracks = async (
  accessToken: string,
  playlistId: string
): Promise<{ name: string; tracks: YtmPlaylistTrack[]; total: number }> => {
  const playlistUrl = `${API_BASE_URL}/playlists?part=snippet&id=${playlistId}`;
  const playlistResp = await fetch(playlistUrl, { headers: { Authorization: `Bearer ${accessToken}` } });
  if (playlistResp.status === 401) throw new YtmTokenExpiredError();
  if (!playlistResp.ok) {
    const text = await playlistResp.text();
    throw new Error(`YouTube playlist fetch failed (${playlistResp.status}): ${text}`);
  }

  const playlistData = (await playlistResp.json()) as Record<string, unknown>;
  const playlistName = ((playlistData["items"] as Array<Record<string, unknown>> | undefined)?.[0]?.["snippet"] as Record<string, unknown> | undefined)?.["title"] as string | undefined;

  const tracks: YtmPlaylistTrack[] = [];
  let pageToken: string | null = null;
  let total = 0;

  do {
    const params = new URLSearchParams({
      part: "snippet,contentDetails",
      playlistId,
      maxResults: "50",
    });
    if (pageToken) params.set("pageToken", pageToken);

    const url = `${API_BASE_URL}/playlistItems?${params.toString()}`;
    const resp = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
    if (resp.status === 401) throw new YtmTokenExpiredError();
    if (!resp.ok) {
      const text = await resp.text();
      throw new Error(`YouTube playlist items failed (${resp.status}): ${text}`);
    }

    const data = (await resp.json()) as Record<string, unknown>;
    const items = (data["items"] as Array<Record<string, unknown>> | undefined) || [];
    total += items.length;

    for (const item of items) {
      const snippet = item["snippet"] as Record<string, unknown> | undefined;
      const title = (snippet?.["title"] as string | undefined)?.trim() || "";
      const artist = (snippet?.["videoOwnerChannelTitle"] as string | undefined)?.trim() || null;
      const videoId = (snippet?.["resourceId"] as Record<string, unknown> | undefined)?.["videoId"] as string | undefined;
      const playlistItemId = item["id"] as string | undefined;

      if (videoId && playlistItemId) {
        tracks.push({ title, artist, videoId, playlistItemId });
      }
    }

    pageToken = (data["nextPageToken"] as string | null | undefined) || null;
  } while (pageToken);

  return {
    name: playlistName || "YouTube Music Playlist",
    tracks,
    total,
  };
};

export const searchYtmTrackExact = async (
  accessToken: string,
  title: string,
  artist: string
): Promise<string | null> => {
  const params = new URLSearchParams({
    part: "snippet",
    q: `${title} ${artist}`,
    type: "video",
    maxResults: "5",
  });

  const url = `${API_BASE_URL}/search?${params.toString()}`;
  const resp = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
  if (resp.status === 401) throw new YtmTokenExpiredError();
  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`YouTube search failed (${resp.status}): ${text}`);
  }

  const data = (await resp.json()) as Record<string, unknown>;
  const items = (data["items"] as Array<Record<string, unknown>> | undefined) || [];
  const titleLc = title.trim().toLowerCase();
  const artistLc = artist.trim().toLowerCase();

  for (const item of items) {
    const snippet = item["snippet"] as Record<string, unknown> | undefined;
    const vid = (item["id"] as Record<string, unknown> | undefined)?.["videoId"] as string | undefined;
    const name = (snippet?.["title"] as string | undefined)?.trim().toLowerCase();
    const channel = (snippet?.["channelTitle"] as string | undefined)?.trim().toLowerCase();
    if (vid && name && channel && name === titleLc && channel === artistLc) {
      return vid;
    }
  }

  return null;
};

export const addTracksToYtmPlaylist = async (
  accessToken: string,
  playlistId: string,
  videoIds: string[]
): Promise<void> => {
  for (const videoId of videoIds) {
    const resp = await fetch(`${API_BASE_URL}/playlistItems?part=snippet`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        snippet: {
          playlistId,
          resourceId: { kind: "youtube#video", videoId },
        },
      }),
    });

    if (resp.status === 401) throw new YtmTokenExpiredError();
    if (!resp.ok) {
      const text = await resp.text();
      throw new Error(`YouTube add track failed (${resp.status}): ${text}`);
    }
  }
};

export const removeTracksFromYtmPlaylist = async (
  accessToken: string,
  playlistItemIds: string[]
): Promise<void> => {
  for (const playlistItemId of playlistItemIds) {
    const resp = await fetch(`${API_BASE_URL}/playlistItems?id=${playlistItemId}`, {
      method: "DELETE",
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });

    if (resp.status === 401) throw new YtmTokenExpiredError();
    if (!resp.ok) {
      const text = await resp.text();
      throw new Error(`YouTube remove track failed (${resp.status}): ${text}`);
    }
  }
};
