/**
 * Catalog Matching Module
 * Phase 6: Strict exact matching for Spotify ↔ YouTube Music sync
 *
 * Replaces fuzzy token-based matching with deterministic exact matching.
 * Uses normalization from trackNormalization.ts for all comparisons.
 */

import {
  normalizeTrack,
  tracksMatch,
  checkMatch,
  NormalizedTrackData,
  MatchCheckResult,
} from "./trackNormalization";

export interface MatchCandidate {
  id: string;
  title: string;
  artist?: string | null;
  description?: string | null;
}

export interface MatchResult {
  id: string;
  matchedTitle: string;
  matchedArtist: string;
  normalizedData: NormalizedTrackData;
}

export interface MatchAttempt {
  candidate: MatchCandidate;
  normalizedData: NormalizedTrackData;
  result: MatchCheckResult;
}

/**
 * Find an exact match for a source track among candidates.
 *
 * STRICT matching rules:
 * - normalizedTitle must equal sourceNormalizedTitle
 * - normalizedArtist must equal sourceNormalizedArtist
 * - Version keywords must match exactly (both same or both null)
 *
 * If multiple candidates qualify, returns the FIRST one (API order).
 * If no exact match found, returns null.
 *
 * @param sourceTitle - Original title from source playlist
 * @param sourceArtist - Original artist from source playlist
 * @param candidates - Array of candidates from destination platform search
 * @returns MatchResult with matched track info, or null if no match
 */
export const findExactMatch = (
  sourceTitle: string,
  sourceArtist: string,
  candidates: MatchCandidate[]
): MatchResult | null => {
  const sourceNormalized = normalizeTrack(sourceTitle, sourceArtist);

  console.info("[catalog-match] searching for exact match", {
    sourceTitle,
    sourceArtist,
    sourceNormalized,
    candidateCount: candidates.length,
  });

  const attempts: MatchAttempt[] = [];

  for (const candidate of candidates) {
    const candidateNormalized = normalizeTrack(
      candidate.title,
      candidate.artist || ""
    );

    const matchResult = checkMatch(sourceNormalized, candidateNormalized);

    attempts.push({
      candidate,
      normalizedData: candidateNormalized,
      result: matchResult,
    });

    if (matchResult === "MATCH") {
      console.info("[catalog-match] exact match found", {
        sourceTitle,
        sourceArtist,
        matchedId: candidate.id,
        matchedTitle: candidate.title,
        matchedArtist: candidate.artist,
        sourceNormalized,
        candidateNormalized,
      });

      return {
        id: candidate.id,
        matchedTitle: candidate.title,
        matchedArtist: candidate.artist || "",
        normalizedData: candidateNormalized,
      };
    }
  }

  // Log why no match was found
  const versionMismatches = attempts.filter((a) => a.result === "VERSION_MISMATCH");
  const noMatches = attempts.filter((a) => a.result === "NO_MATCH");

  console.warn("[catalog-match] no exact match found", {
    sourceTitle,
    sourceArtist,
    sourceNormalized,
    candidatesEvaluated: candidates.length,
    versionMismatches: versionMismatches.length,
    noMatches: noMatches.length,
    attempts: attempts.map((a) => ({
      candidateTitle: a.candidate.title,
      candidateArtist: a.candidate.artist,
      normalized: a.normalizedData,
      result: a.result,
    })),
  });

  return null;
};

/**
 * Legacy function for backward compatibility.
 * Returns just the ID string instead of full MatchResult.
 *
 * @deprecated Use findExactMatch instead for full match information
 */
export const findBestMatch = (
  sourceTitle: string,
  sourceArtist: string,
  candidates: MatchCandidate[]
): string | null => {
  const result = findExactMatch(sourceTitle, sourceArtist, candidates);
  return result?.id || null;
};

/**
 * Check if any candidate has a version mismatch with the source.
 * Used to determine appropriate skip reason (NO_EXACT_MATCH vs METADATA_MISMATCH).
 *
 * @returns true if at least one candidate has matching title/artist but different version
 */
export const hasVersionMismatch = (
  sourceTitle: string,
  sourceArtist: string,
  candidates: MatchCandidate[]
): boolean => {
  const sourceNormalized = normalizeTrack(sourceTitle, sourceArtist);

  for (const candidate of candidates) {
    const candidateNormalized = normalizeTrack(
      candidate.title,
      candidate.artist || ""
    );

    if (checkMatch(sourceNormalized, candidateNormalized) === "VERSION_MISMATCH") {
      return true;
    }
  }

  return false;
};
