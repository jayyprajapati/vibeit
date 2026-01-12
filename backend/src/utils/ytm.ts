import env from "../config/env";
import {
  SourceTrack,
  CandidateTrack,
  ResolutionResult,
  generateSearchQueries,
  resolveFromCandidates,
  logResolution,
} from "./trackResolver";

const TOKEN_URL = "https://oauth2.googleapis.com/token";
const AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth";
const API_BASE_URL = "https://www.googleapis.com/youtube/v3";
export type YtmScopeLevel = "READ" | "WRITE";
const YTM_SCOPE_READ = "https://www.googleapis.com/auth/youtube.readonly";
const YTM_SCOPE_WRITE = "https://www.googleapis.com/auth/youtube.force-ssl";
const EXCLUDED_PLAYLIST_NAMES = new Set([
  "liked videos",
  "watch later",
  "favorites",
  "uploads",
]);
const MUSIC_KEYWORDS = ["official audio", "lyrics", "song", "album"];

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

interface RawYtmPlaylist {
  ytmPlaylistId: string;
  name: string;
  itemCount: number;
  channelId: string;
}

interface PlaylistSampleItem {
  videoId: string;
  title: string;
  ownerChannelTitle: string | null;
  categoryId: string | null;
}

const parseIsoDurationToSeconds = (iso: string | null | undefined): number | null => {
  if (!iso) return null;

  const regex = /PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/i;
  const match = iso.match(regex);
  if (!match) return null;

  const hours = Number(match[1] || 0);
  const minutes = Number(match[2] || 0);
  const seconds = Number(match[3] || 0);

  const totalSeconds = hours * 3600 + minutes * 60 + seconds;
  return Number.isFinite(totalSeconds) && totalSeconds > 0 ? totalSeconds : null;
};

const fetchVideoDurations = async (
  accessToken: string,
  videoIds: string[]
): Promise<Record<string, number | null>> => {
  if (videoIds.length === 0) return {};

  const url = `${API_BASE_URL}/videos?part=contentDetails&id=${videoIds.join(",")}`;
  const resp = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });

  if (resp.status === 401) throw new YtmTokenExpiredError();
  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`YouTube videos duration lookup failed (${resp.status}): ${text}`);
  }

  const data = (await resp.json()) as Record<string, unknown>;
  const items = (data["items"] as Array<Record<string, unknown>> | undefined) || [];

  const durations: Record<string, number | null> = {};
  for (const item of items) {
    const id = item["id"] as string | undefined;
    const contentDetails = item["contentDetails"] as Record<string, unknown> | undefined;
    const isoDuration = (contentDetails?.["duration"] as string | undefined) || null;
    if (id) {
      durations[id] = parseIsoDurationToSeconds(isoDuration);
    }
  }

  return durations;
};

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

const fetchUserChannelId = async (accessToken: string): Promise<string> => {
  const url = `${API_BASE_URL}/channels?part=id&mine=true`;
  const resp = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });

  if (resp.status === 401) throw new YtmTokenExpiredError();
  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`YouTube channel lookup failed (${resp.status}): ${text}`);
  }

  const data = (await resp.json()) as Record<string, unknown>;
  const items = (data["items"] as Array<Record<string, unknown>> | undefined) || [];
  const channelId = items[0]?.["id"] as string | undefined;

  if (!channelId) {
    throw new Error("Unable to determine YouTube channel id for user");
  }

  return channelId;
};

const samplePlaylistItems = async (
  accessToken: string,
  playlistId: string,
  sampleSize = 5
): Promise<PlaylistSampleItem[]> => {
  const params = new URLSearchParams({
    part: "snippet,contentDetails",
    playlistId,
    maxResults: sampleSize.toString(),
  });

  const itemsResp = await fetch(`${API_BASE_URL}/playlistItems?${params.toString()}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (itemsResp.status === 401) throw new YtmTokenExpiredError();
  if (!itemsResp.ok) {
    const text = await itemsResp.text();
    throw new Error(`YouTube playlist items sample failed (${itemsResp.status}): ${text}`);
  }

  const data = (await itemsResp.json()) as Record<string, unknown>;
  const items = (data["items"] as Array<Record<string, unknown>> | undefined) || [];

  const samples: PlaylistSampleItem[] = [];
  const videoIds: string[] = [];

  for (const item of items) {
    const snippet = item["snippet"] as Record<string, unknown> | undefined;
    const resource = snippet?.["resourceId"] as Record<string, unknown> | undefined;
    const videoId = resource?.["videoId"] as string | undefined;
    if (!videoId) continue;

    const title = (snippet?.["title"] as string | undefined) || "";
    const ownerChannelTitle = (snippet?.["videoOwnerChannelTitle"] as string | undefined) || null;

    samples.push({ videoId, title, ownerChannelTitle, categoryId: null });
    videoIds.push(videoId);
  }

  if (videoIds.length === 0) return samples;

  const videosUrl = `${API_BASE_URL}/videos?part=snippet&id=${videoIds.join(",")}`;
  const videosResp = await fetch(videosUrl, { headers: { Authorization: `Bearer ${accessToken}` } });

  if (videosResp.status === 401) throw new YtmTokenExpiredError();
  if (!videosResp.ok) {
    const text = await videosResp.text();
    throw new Error(`YouTube videos lookup failed (${videosResp.status}): ${text}`);
  }

  const videosData = (await videosResp.json()) as Record<string, unknown>;
  const videos = (videosData["items"] as Array<Record<string, unknown>> | undefined) || [];
  const categoryById: Record<string, string | null> = {};

  for (const video of videos) {
    const id = video["id"] as string | undefined;
    const snippet = video["snippet"] as Record<string, unknown> | undefined;
    const categoryId = (snippet?.["categoryId"] as string | undefined) || null;
    if (id) categoryById[id] = categoryId;
  }

  return samples.map((sample) => ({
    ...sample,
    categoryId: categoryById[sample.videoId] ?? null,
  }));
};

const isMusicLike = (item: PlaylistSampleItem): boolean => {
  const title = item.title.toLowerCase();
  const owner = (item.ownerChannelTitle || "").trim().toLowerCase();
  const ownerIsTopic = owner.endsWith("- topic");
  const isMusicCategory = item.categoryId === "10";
  const hasKeyword = MUSIC_KEYWORDS.some((kw) => title.includes(kw));

  return ownerIsTopic || isMusicCategory || hasKeyword;
};

const isMusicPlaylist = async (accessToken: string, playlistId: string): Promise<boolean> => {
  try {
    const samples = await samplePlaylistItems(accessToken, playlistId, 5);
    if (samples.length === 0) return false;

    const musicLikeCount = samples.filter(isMusicLike).length;
    const ratio = musicLikeCount / samples.length;
    return ratio >= 0.6;
  } catch (error) {
    if (error instanceof YtmTokenExpiredError) throw error;
    console.warn(`[ytm] Music heuristic skipped for ${playlistId}:`, error);
    return false;
  }
};

export const fetchYtmPlaylists = async (accessToken: string): Promise<YtmRemotePlaylist[]> => {
  const playlists: RawYtmPlaylist[] = [];
  let pageToken: string | null = null;

  const userChannelId = await fetchUserChannelId(accessToken);

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
      const channelId = snippet?.["channelId"] as string | undefined;
      const contentDetails = item["contentDetails"] as Record<string, unknown> | undefined;
      const count = (contentDetails?.["itemCount"] as number | undefined) ?? 0;

      if (id && title && channelId) {
        playlists.push({
          ytmPlaylistId: id,
          name: title,
          itemCount: count,
          channelId,
        });
      }
    }

    pageToken = (data["nextPageToken"] as string | null | undefined) || null;
    if (!pageToken) break;
  }

  const filtered: YtmRemotePlaylist[] = [];

  for (const playlist of playlists) {
    const normalizedTitle = playlist.name.trim().toLowerCase();
    if (playlist.channelId !== userChannelId) continue;
    if (EXCLUDED_PLAYLIST_NAMES.has(normalizedTitle)) continue;

    const looksMusic = await isMusicPlaylist(accessToken, playlist.ytmPlaylistId);
    if (!looksMusic) continue;

    filtered.push({
      ytmPlaylistId: playlist.ytmPlaylistId,
      name: playlist.name,
      itemCount: playlist.itemCount,
    });
  }

  return filtered;
};

interface YtmPlaylistTrack {
  title: string;
  artist: string | null;
  videoId: string;
  playlistItemId: string;
  durationSeconds: number | null;
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

    const pageTracks: YtmPlaylistTrack[] = [];
    const videoIds: string[] = [];

    for (const item of items) {
      const snippet = item["snippet"] as Record<string, unknown> | undefined;
      const title = (snippet?.["title"] as string | undefined)?.trim() || "";
      const artist = (snippet?.["videoOwnerChannelTitle"] as string | undefined)?.trim() || null;
      const videoId = (snippet?.["resourceId"] as Record<string, unknown> | undefined)?.["videoId"] as string | undefined;
      const playlistItemId = item["id"] as string | undefined;

      if (videoId && playlistItemId) {
        pageTracks.push({ title, artist, videoId, playlistItemId, durationSeconds: null });
        videoIds.push(videoId);
      }
    }

    if (videoIds.length > 0) {
      try {
        const durations = await fetchVideoDurations(accessToken, videoIds);
        for (const track of pageTracks) {
          track.durationSeconds = durations[track.videoId] ?? null;
        }
      } catch (error) {
        if (error instanceof YtmTokenExpiredError) throw error;
        console.warn("[ytm] Failed to fetch durations for page", { videoCount: videoIds.length, error });
      }
    }

    tracks.push(...pageTracks);

    pageToken = (data["nextPageToken"] as string | null | undefined) || null;
  } while (pageToken);

  return {
    name: playlistName || "YouTube Music Playlist",
    tracks,
    total,
  };
};

/**
 * Search YouTube and resolve the best matching track using scoring.
 * Uses multiple search queries as fallback for maximum match rate.
 *
 * @returns Video ID of the best match, or null if no acceptable match found
 */
export const searchYtmTrackExact = async (
  accessToken: string,
  title: string,
  artist: string
): Promise<string | null> => {
  const source: SourceTrack = { title, artist };
  const queries = generateSearchQueries(source);

  console.log(`[ytm-search] Resolving: "${title}" by "${artist}"`);
  console.log(`[ytm-search] Will try ${queries.length} queries`);

  // Try each query until we find a good match
  for (const query of queries) {
    console.log(`[ytm-search] Trying query: "${query}"`);

    const result = await searchYtmWithQuery(accessToken, source, query);

    if (result.success) {
      logResolution(source, result, "ytm");
      return result.matchedId;
    }

    // If we got candidates but no match, log and continue to next query
    if (result.candidatesEvaluated > 0) {
      console.log(`[ytm-search] Query "${query}" returned ${result.candidatesEvaluated} candidates, best score: ${result.score}`);
    }
  }

  // All queries exhausted, no match found
  console.warn(`[ytm-search] ✗ FAILED to resolve: "${title}" by "${artist}" after ${queries.length} queries`);
  return null;
};

/**
 * Execute a single YouTube search query and score the results.
 */
const searchYtmWithQuery = async (
  accessToken: string,
  source: SourceTrack,
  query: string
): Promise<ResolutionResult> => {
  const params = new URLSearchParams({
    part: "snippet",
    q: query,
    type: "video",
    videoCategoryId: "10", // Music category
    maxResults: "15",      // Get more candidates for better matching
  });

  const url = `${API_BASE_URL}/search?${params.toString()}`;

  try {
    const resp = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });

    if (resp.status === 401) throw new YtmTokenExpiredError();

    if (!resp.ok) {
      const text = await resp.text();
      console.error(`[ytm-search] API error: ${resp.status} - ${text}`);
      return {
        success: false,
        matchedId: null,
        matchedTitle: null,
        matchedChannel: null,
        score: 0,
        confidence: "rejected",
        queryUsed: query,
        candidatesEvaluated: 0,
        candidatesRejected: 0,
        allScores: [],
      };
    }

    const data = (await resp.json()) as Record<string, unknown>;
    const items = (data["items"] as Array<Record<string, unknown>> | undefined) || [];

    // Convert to CandidateTrack format
    const candidates = items
      .map((item): CandidateTrack | null => {
        const snippet = item["snippet"] as Record<string, unknown> | undefined;
        const videoId = (item["id"] as Record<string, unknown> | undefined)?.["videoId"] as string | undefined;
        const videoTitle = (snippet?.["title"] as string | undefined) || "";
        const channelTitle = (snippet?.["channelTitle"] as string | undefined) || "";
        const description = (snippet?.["description"] as string | undefined) || "";

        if (!videoId) return null;

        return {
          id: videoId,
          title: videoTitle,
          channel: channelTitle,
          description,
        };
      })
      .filter((c): c is CandidateTrack => c !== null);

    // Use scoring-based resolution
    return resolveFromCandidates(source, candidates, query);

  } catch (error) {
    if (error instanceof YtmTokenExpiredError) throw error;

    console.error(`[ytm-search] Search failed for query "${query}":`, error);
    return {
      success: false,
      matchedId: null,
      matchedTitle: null,
      matchedChannel: null,
      score: 0,
      confidence: "rejected",
      queryUsed: query,
      candidatesEvaluated: 0,
      candidatesRejected: 0,
      allScores: [],
    };
  }
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

export const createYtmPlaylist = async (accessToken: string, name: string): Promise<string> => {
  const params = new URLSearchParams({ part: "snippet,status" });
  const resp = await fetch(`${API_BASE_URL}/playlists?${params.toString()}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      snippet: { title: name },
      status: { privacyStatus: "private" },
    }),
  });

  if (resp.status === 401) throw new YtmTokenExpiredError();
  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`YouTube Music playlist create failed (${resp.status}): ${text}`);
  }

  const data = (await resp.json()) as Record<string, unknown>;
  const id = (data["id"] as string | undefined) ||
    ((data["result"] as Record<string, unknown> | undefined)?.["id"] as string | undefined);

  if (!id) {
    throw new Error("YouTube Music playlist create response missing id");
  }

  return id;
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
