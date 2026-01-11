/**
 * Deterministic Track Normalization Module
 * Phase 6: Strict normalization for Spotify ↔ YouTube Music sync
 *
 * All normalization is deterministic and explainable.
 * Version keywords are preserved for explicit matching.
 */

// Version keywords that indicate a specific track variant
const VERSION_KEYWORDS = ["remix", "live", "remaster", "remastered", "acoustic"] as const;
export type VersionKeyword = (typeof VERSION_KEYWORDS)[number] | null;

// Patterns for version keyword detection (at end of title)
const VERSION_KEYWORD_PATTERN = /\s*-\s*(remix|live|remaster(?:ed)?|acoustic)$/i;

// YouTube/metadata suffix patterns to remove (case-insensitive)
const METADATA_SUFFIX_PATTERNS = [
  /\s*-\s*topic$/i,
  /\s*-\s*official\s*(audio|video)$/i,
  /\s*-\s*lyric\s*video$/i,
  /\s*-\s*lyrics$/i,
  /\s*-\s*audio$/i,
  /\s*-\s*visualizer$/i,
];

// Bracketed content patterns
const BRACKET_PATTERNS = [
  /\([^)]*\)/g, // (...)
  /\[[^\]]*\]/g, // [...]
];

// Artist separators for extracting primary artist
const ARTIST_SEPARATORS = /[,&]|\bfeat\.?\b|\bft\.?\b|\bx\b|\bvs\.?\b/i;

export interface NormalizedTrackData {
  normalizedTitle: string;
  normalizedArtist: string;
  versionKeyword: VersionKeyword;
}

/**
 * Normalize whitespace: trim and collapse multiple spaces
 */
const normalizeWhitespace = (value: string): string => value.replace(/\s+/g, " ").trim();

/**
 * Remove bracketed content from a string
 */
const removeBrackets = (value: string): string => {
  let result = value;
  for (const pattern of BRACKET_PATTERNS) {
    result = result.replace(pattern, " ");
  }
  return result;
};

/**
 * Remove YouTube/metadata suffixes from a string
 */
const removeMetadataSuffixes = (value: string): string => {
  let result = value;
  let changed = true;

  // Apply patterns repeatedly until no more changes
  while (changed) {
    changed = false;
    for (const pattern of METADATA_SUFFIX_PATTERNS) {
      const newResult = result.replace(pattern, "");
      if (newResult !== result) {
        result = newResult;
        changed = true;
      }
    }
  }

  return result;
};

/**
 * Extract version keyword from title (e.g., "Song - Live" -> "live")
 * Returns null if no version keyword found
 */
const extractVersionKeyword = (title: string): VersionKeyword => {
  const match = title.match(VERSION_KEYWORD_PATTERN);
  if (!match) return null;

  const keyword = match[1].toLowerCase();
  // Normalize "remastered" to "remaster" for consistency
  if (keyword === "remastered") return "remaster";
  return keyword as VersionKeyword;
};

/**
 * Remove version keyword suffix from title
 */
const removeVersionKeyword = (title: string): string => {
  return title.replace(VERSION_KEYWORD_PATTERN, "");
};

/**
 * Normalize a track title following strict deterministic rules.
 *
 * Order of operations:
 * 1. Convert to lowercase
 * 2. Remove bracketed content: (...) and [...]
 * 3. Remove YouTube/metadata suffixes (- Topic, - Official Audio, etc.)
 * 4. Extract version keyword (remix, live, remaster, acoustic)
 * 5. Remove version keyword from normalized title
 * 6. Trim whitespace and collapse multiple spaces
 */
export const normalizeTitle = (title: string): string => {
  let result = (title || "").toLowerCase();
  result = removeBrackets(result);
  result = removeMetadataSuffixes(result);
  result = removeVersionKeyword(result);
  result = normalizeWhitespace(result);
  return result;
};

/**
 * Extract primary artist from artist string.
 * Takes only the first artist before any separator (, & feat. ft. x vs.)
 */
const extractPrimaryArtist = (artist: string): string => {
  const parts = artist.split(ARTIST_SEPARATORS);
  return parts[0] || artist;
};

/**
 * Normalize an artist name following strict deterministic rules.
 *
 * Order of operations:
 * 1. Extract primary artist only
 * 2. Convert to lowercase
 * 3. Remove "- Topic" suffix
 * 4. Remove punctuation (keep only alphanumeric and spaces)
 * 5. Trim whitespace and collapse multiple spaces
 */
export const normalizeArtist = (artist: string): string => {
  let result = extractPrimaryArtist(artist || "");
  result = result.toLowerCase();
  result = result.replace(/\s*-\s*topic$/i, "");
  result = result.replace(/[^\w\s]/g, " ");
  result = normalizeWhitespace(result);
  return result;
};

/**
 * Normalize a track (title + artist) and extract version keyword.
 * This is the primary normalization function to use.
 */
export const normalizeTrack = (title: string, artist: string): NormalizedTrackData => {
  // Extract version keyword BEFORE any normalization to preserve it
  const titleLower = (title || "").toLowerCase();
  const titleWithoutBrackets = removeBrackets(titleLower);
  const titleWithoutMetadata = removeMetadataSuffixes(titleWithoutBrackets);
  const versionKeyword = extractVersionKeyword(titleWithoutMetadata);

  return {
    normalizedTitle: normalizeTitle(title),
    normalizedArtist: normalizeArtist(artist),
    versionKeyword,
  };
};

/**
 * Generate a unique track identity key.
 * Format: "normalizedTitle::normalizedArtist"
 *
 * This key is the ONLY basis for equality checks.
 * Does NOT include: album, duration, popularity, platform IDs, or version keyword
 */
export const trackKey = (data: NormalizedTrackData): string => {
  return `${data.normalizedTitle}::${data.normalizedArtist}`;
};

/**
 * Legacy function for backward compatibility.
 * Generates track identity from raw title and artist.
 */
export const trackIdentity = (title: string, artist: string): string => {
  const data = normalizeTrack(title, artist);
  return trackKey(data);
};

/**
 * Check if two normalized tracks match.
 *
 * STRICT mode rules:
 * - Exact equality on normalizedTitle
 * - Exact equality on normalizedArtist
 * - Version keywords must match exactly:
 *   - BOTH have same keyword → match
 *   - BOTH have null → match
 *   - One has keyword, other doesn't → NO match
 *   - Different keywords → NO match
 */
export const tracksMatch = (source: NormalizedTrackData, dest: NormalizedTrackData): boolean => {
  // Title must match exactly
  if (source.normalizedTitle !== dest.normalizedTitle) {
    return false;
  }

  // Artist must match exactly
  if (source.normalizedArtist !== dest.normalizedArtist) {
    return false;
  }

  // Version keywords must match exactly
  if (source.versionKeyword !== dest.versionKeyword) {
    return false;
  }

  return true;
};

/**
 * Check if two tracks match with version keyword mismatch tolerance.
 * Used for detecting METADATA_MISMATCH skip reason.
 *
 * Returns:
 * - 'MATCH' if tracks match completely
 * - 'VERSION_MISMATCH' if title/artist match but version differs
 * - 'NO_MATCH' if title or artist don't match
 */
export type MatchCheckResult = "MATCH" | "VERSION_MISMATCH" | "NO_MATCH";

export const checkMatch = (source: NormalizedTrackData, dest: NormalizedTrackData): MatchCheckResult => {
  if (source.normalizedTitle !== dest.normalizedTitle) {
    return "NO_MATCH";
  }

  if (source.normalizedArtist !== dest.normalizedArtist) {
    return "NO_MATCH";
  }

  if (source.versionKeyword !== dest.versionKeyword) {
    return "VERSION_MISMATCH";
  }

  return "MATCH";
};
