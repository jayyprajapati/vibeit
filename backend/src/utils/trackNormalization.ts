const normalizeWhitespace = (value: string) => value.replace(/\s+/g, " ").trim();

const stripFromDescriptors = (value: string) => {
  let result = value;
  // Remove bracketed descriptors like (from ...), [from ...]
  result = result.replace(/\s*\(from[^\)]*\)/gi, "");
  result = result.replace(/\s*\[from[^\]]*\]/gi, "");
  // Remove suffixed "- from ..." phrases
  result = result.replace(/\s*[-–—]?\s*from\s+.*$/gi, "");
  return result;
};

const stripNoiseTokens = (value: string) => {
  const noise = ["from", "original motion picture soundtrack", "remastered", "remix"];
  let result = value;
  for (const token of noise) {
    const re = new RegExp(`\\b${token.replace(/[-/\\^$*+?.()|[\]{}]/g, "\\$&")}\\b`, "gi");
    result = result.replace(re, "");
  }
  return result;
};

export const normalizeTitle = (title: string): string => {
  const lower = (title || "").toLowerCase();
  const stripped = stripFromDescriptors(lower);
  const withoutNoise = stripNoiseTokens(stripped);
  return normalizeWhitespace(withoutNoise);
};

export const normalizeArtist = (artist: string): string => normalizeWhitespace((artist || "").toLowerCase());

export const trackIdentity = (title: string, artist: string): string => `${normalizeTitle(title)}::${normalizeArtist(artist)}`;
