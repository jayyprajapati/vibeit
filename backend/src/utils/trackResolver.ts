/**
 * Intelligent Track Resolution Module
 * Robust matching for Spotify ↔ YouTube Music sync
 *
 * Features:
 * - Advanced title parsing and cleanup
 * - Bad-variant exclusion (remix, slowed, low freq, etc.)
 * - Good-variant prioritization (official audio, topic channels)
 * - Frequency-based artist identification
 * - Multi-stage search with fallbacks
 * - Explainable scoring system
 */

// ============================================================================
// BAD VARIANTS - These should be EXCLUDED or heavily penalized
// ============================================================================

const BAD_VARIANT_PATTERNS = [
    /\blow\s*freq(uency)?\b/i,
    /\bslowed(\s*(and|\+|&)\s*reverb)?\b/i,
    /\breverb(ed)?\b/i,
    /\bnightcore\b/i,
    /\bkaraoke\b/i,
    /\binstrumental\b/i,
    /\b8\s*d\s*audio\b/i,
    /\bbassboosted\b/i,
    /\bbass\s*boosted\b/i,
    /\bspeed\s*up\b/i,
    /\bsped\s*up\b/i,
    /\bchipmunk\b/i,
    /\bpitched\b/i,
    /\blofi\b/i,
    /\blo-?fi\b/i,
];

// Patterns that indicate a cover or non-original version
const COVER_PATTERNS = [
    /\bcover\b/i,
    /\bversion\s+by\b/i,
    /\bperformed\s+by\b/i,
    /\btribute\b/i,
    /\bin\s+the\s+style\s+of\b/i,
];

// Remix pattern - only penalize if source doesn't have remix
const REMIX_PATTERN = /\bremix\b/i;
const LIVE_PATTERN = /\blive\b/i;
const ACOUSTIC_PATTERN = /\bacoustic\b/i;

// ============================================================================
// GOOD VARIANTS - These should be prioritized
// ============================================================================

const GOOD_INDICATORS = {
    topicChannel: /\s*-\s*topic$/i,
    vevoChannel: /vevo$/i,
    officialAudio: /\bofficial\s*(audio|song)\b/i,
    officialVideo: /\bofficial\s*(music\s*)?video\b/i,
    fromAlbum: /\bfrom\s+(the\s+)?album\b/i,
};

// ============================================================================
// TITLE SEPARATORS AND NOISE REMOVAL
// ============================================================================

// Common separators in YouTube titles
const TITLE_SEPARATORS = /\s*[|•:–—]\s*/g;

// Patterns to strip from titles before matching
const TITLE_NOISE_PATTERNS = [
    // Parenthetical/bracketed content (but extract first)
    /\([^)]*\)/g,
    /\[[^\]]*\]/g,
    /\{[^}]*\}/g,

    // Common suffixes
    /\s*-\s*topic$/i,
    /\s*vevo$/i,
    /\s*-\s*official\s*(audio|video|music\s*video)?$/i,
    /\s*-\s*audio$/i,
    /\s*-\s*lyric(s)?\s*(video)?$/i,
    /\s*-\s*visuali[sz]er$/i,
    /\s*-\s*full\s*(song|video|audio)$/i,
    /\s*\|\s*.*$/,  // Everything after pipe

    // Quality/format indicators
    /\b(hd|hq|4k|1080p|720p)\b/gi,
    /\bfull\s*(song|video|audio)\b/gi,
    /\bnew\s*(song|video|audio)\s*\d*\b/gi,

    // Year indicators at end
    /\s*\(\d{4}\)\s*$/,
    /\s*\d{4}\s*$/,
];

// Noise words to filter during tokenization
const NOISE_WORDS = new Set([
    "the", "a", "an", "and", "or", "of", "in", "on", "at", "to", "for",
    "with", "by", "from", "up", "out", "is", "it", "as", "be", "are",
    "was", "were", "been", "being", "have", "has", "had", "do", "does",
    "did", "will", "would", "could", "should", "may", "might", "must",
    "ft", "feat", "featuring", "prod", "produced", "presents",
    "song", "audio", "video", "music", "official", "full",
]);

// ============================================================================
// TOKENIZATION
// ============================================================================

/**
 * Aggressively clean a title for matching.
 * Removes noise, separators, and extracts core content.
 */
export const cleanTitle = (title: string): string => {
    if (!title) return "";

    let cleaned = title.toLowerCase();

    // Remove noise patterns
    for (const pattern of TITLE_NOISE_PATTERNS) {
        cleaned = cleaned.replace(pattern, " ");
    }

    // Split on separators and take first meaningful segment
    const segments = cleaned.split(TITLE_SEPARATORS).filter(Boolean);
    if (segments.length > 1) {
        // Usually the song title is the first or second segment after artist
        cleaned = segments.slice(0, 2).join(" ");
    }

    // Normalize whitespace
    cleaned = cleaned.replace(/\s+/g, " ").trim();

    return cleaned;
};

/**
 * Tokenize a string into cleaned, lowercase tokens.
 */
export const tokenize = (text: string): string[] => {
    if (!text) return [];

    const cleaned = text.toLowerCase().replace(/[^a-z0-9\s]/g, " ");

    const tokens = cleaned
        .split(/\s+/)
        .filter((t) => t.length >= 2)
        .filter((t) => !NOISE_WORDS.has(t));

    return tokens;
};

/**
 * Calculate what percentage of tokensA are found in tokensB.
 */
export const tokenOverlap = (tokensA: string[], tokensB: string[]): number => {
    if (tokensA.length === 0) return 0;

    const setB = new Set(tokensB);
    const matches = tokensA.filter((t) => setB.has(t)).length;

    return Math.round((matches / tokensA.length) * 100);
};

/**
 * Calculate bidirectional token similarity (Jaccard-like).
 */
export const tokenSimilarity = (tokensA: string[], tokensB: string[]): number => {
    if (tokensA.length === 0 && tokensB.length === 0) return 100;
    if (tokensA.length === 0 || tokensB.length === 0) return 0;

    const setA = new Set(tokensA);
    const setB = new Set(tokensB);

    const intersection = tokensA.filter((t) => setB.has(t)).length;
    const union = new Set([...tokensA, ...tokensB]).size;

    return Math.round((intersection / union) * 100);
};

// ============================================================================
// BAD VARIANT DETECTION
// ============================================================================

export interface VariantAnalysis {
    isBadVariant: boolean;
    isRemix: boolean;
    isLive: boolean;
    isAcoustic: boolean;
    isCover: boolean;
    badPatternMatched: string | null;
}

/**
 * Analyze a title for bad variants that should be excluded.
 */
export const analyzeVariant = (title: string): VariantAnalysis => {
    const titleLower = title.toLowerCase();

    // Check for bad patterns
    for (const pattern of BAD_VARIANT_PATTERNS) {
        if (pattern.test(titleLower)) {
            return {
                isBadVariant: true,
                isRemix: REMIX_PATTERN.test(titleLower),
                isLive: LIVE_PATTERN.test(titleLower),
                isAcoustic: ACOUSTIC_PATTERN.test(titleLower),
                isCover: COVER_PATTERNS.some((p) => p.test(titleLower)),
                badPatternMatched: pattern.source,
            };
        }
    }

    // Check for covers
    for (const pattern of COVER_PATTERNS) {
        if (pattern.test(titleLower)) {
            return {
                isBadVariant: true,
                isRemix: false,
                isLive: false,
                isAcoustic: false,
                isCover: true,
                badPatternMatched: pattern.source,
            };
        }
    }

    return {
        isBadVariant: false,
        isRemix: REMIX_PATTERN.test(titleLower),
        isLive: LIVE_PATTERN.test(titleLower),
        isAcoustic: ACOUSTIC_PATTERN.test(titleLower),
        isCover: false,
        badPatternMatched: null,
    };
};

// ============================================================================
// GOOD INDICATOR DETECTION
// ============================================================================

export interface GoodIndicators {
    isTopicChannel: boolean;
    isVevoChannel: boolean;
    hasOfficialAudio: boolean;
    hasOfficialVideo: boolean;
    totalBonus: number;
}

/**
 * Analyze for positive quality indicators.
 */
export const analyzeGoodIndicators = (
    title: string,
    channel: string
): GoodIndicators => {
    const titleLower = title.toLowerCase();
    const channelLower = channel.toLowerCase();

    const isTopicChannel = GOOD_INDICATORS.topicChannel.test(channelLower);
    const isVevoChannel = GOOD_INDICATORS.vevoChannel.test(channelLower);
    const hasOfficialAudio = GOOD_INDICATORS.officialAudio.test(titleLower);
    const hasOfficialVideo = GOOD_INDICATORS.officialVideo.test(titleLower);

    let totalBonus = 0;
    if (isTopicChannel) totalBonus += 25; // Topic channels are auto-generated, very reliable
    if (isVevoChannel) totalBonus += 20; // VEVO is official
    if (hasOfficialAudio) totalBonus += 15;
    if (hasOfficialVideo) totalBonus += 10;

    return {
        isTopicChannel,
        isVevoChannel,
        hasOfficialAudio,
        hasOfficialVideo,
        totalBonus: Math.min(totalBonus, 35), // Cap total bonus
    };
};

// ============================================================================
// ARTIST FREQUENCY CACHE
// ============================================================================

// Global cache for artist frequency across user's library
const artistFrequencyCache = new Map<string, Map<string, number>>();

/**
 * Build artist frequency map from playlist data.
 * Called when playlists are fetched.
 */
export const updateArtistFrequency = (
    userId: string,
    artists: string[]
): void => {
    if (!artistFrequencyCache.has(userId)) {
        artistFrequencyCache.set(userId, new Map());
    }

    const userCache = artistFrequencyCache.get(userId)!;

    for (const artist of artists) {
        const normalized = artist.toLowerCase().trim();
        if (normalized.length < 2) continue;

        const count = userCache.get(normalized) || 0;
        userCache.set(normalized, count + 1);
    }
};

/**
 * Get artist frequency score (0-100).
 * Higher = more common in user's library = more likely to be correct artist.
 */
export const getArtistFrequencyScore = (userId: string, artist: string): number => {
    const userCache = artistFrequencyCache.get(userId);
    if (!userCache || userCache.size === 0) return 50; // Neutral if no data

    const normalized = artist.toLowerCase().trim();
    const count = userCache.get(normalized) || 0;

    if (count === 0) return 10; // Unknown artist - very low
    if (count === 1) return 30;
    if (count <= 3) return 50;
    if (count <= 10) return 70;
    return 90; // Very common artist
};

/**
 * Extract potential artist names from a noisy title.
 */
export const extractPotentialArtists = (title: string): string[] => {
    // Split on common separators
    const parts = title
        .split(/\s*[-|•:×x]\s*/i)
        .map((p) => p.trim())
        .filter((p) => p.length > 1);

    // Also check for "ft." or "feat." patterns
    const featMatch = title.match(/(?:ft\.?|feat\.?|featuring)\s+([^,\-|]+)/i);
    if (featMatch) {
        parts.push(featMatch[1].trim());
    }

    return parts;
};

// ============================================================================
// SCORING
// ============================================================================

export interface ScoreBreakdown {
    titleSimilarity: number;
    artistMatch: number;
    goodIndicatorBonus: number;
    badVariantPenalty: number;
    versionMismatchPenalty: number;
    artistFrequencyBonus: number;
}

export interface ScoringResult {
    candidateId: string;
    candidateTitle: string;
    candidateChannel: string;
    score: number;
    confidence: "high" | "medium" | "low" | "rejected";
    breakdown: ScoreBreakdown;
    variantAnalysis: VariantAnalysis;
    goodIndicators: GoodIndicators;
    rejected: boolean;
    rejectionReason: string | null;
}

export interface SourceTrack {
    title: string;
    artist: string;
    userId?: string; // For frequency-based scoring
}

export interface CandidateTrack {
    id: string;
    title: string;
    channel: string;
    description?: string;
}

/**
 * Score a candidate track against a source track.
 * Returns detailed breakdown with rejection logic.
 */
export const scoreCandidate = (
    source: SourceTrack,
    candidate: CandidateTrack
): ScoringResult => {
    // Analyze for bad variants FIRST
    const variantAnalysis = analyzeVariant(candidate.title);
    const sourceVariant = analyzeVariant(source.title);

    // IMMEDIATE REJECTION for bad variants (unless source is also that variant)
    if (variantAnalysis.isBadVariant && !sourceVariant.isBadVariant) {
        return createRejectedResult(
            candidate,
            `Bad variant detected: ${variantAnalysis.badPatternMatched}`,
            variantAnalysis
        );
    }

    // Version mismatch penalty (remix, live, acoustic)
    let versionMismatchPenalty = 0;
    if (variantAnalysis.isRemix !== sourceVariant.isRemix) {
        versionMismatchPenalty += 40;
    }
    if (variantAnalysis.isLive !== sourceVariant.isLive) {
        versionMismatchPenalty += 30;
    }
    if (variantAnalysis.isAcoustic !== sourceVariant.isAcoustic) {
        versionMismatchPenalty += 25;
    }

    // Clean and tokenize
    const sourceCleanTitle = cleanTitle(source.title);
    const candidateCleanTitle = cleanTitle(candidate.title);

    const sourceTitleTokens = tokenize(sourceCleanTitle);
    const candidateTitleTokens = tokenize(candidateCleanTitle);
    const sourceArtistTokens = tokenize(source.artist);

    // Title similarity
    const titleSimilarity = tokenSimilarity(sourceTitleTokens, candidateTitleTokens);

    // Artist matching - check in title, channel, and description
    const candidateChannelTokens = tokenize(candidate.channel);
    const candidateDescTokens = tokenize(candidate.description || "");
    const allCandidateTokens = [...candidateTitleTokens, ...candidateChannelTokens, ...candidateDescTokens];

    const artistMatch = tokenOverlap(sourceArtistTokens, allCandidateTokens);

    // Good indicators
    const goodIndicators = analyzeGoodIndicators(candidate.title, candidate.channel);

    // Artist frequency bonus (if userId provided)
    let artistFrequencyBonus = 0;
    if (source.userId) {
        const potentialArtists = extractPotentialArtists(candidate.title);
        const channelScore = getArtistFrequencyScore(source.userId, candidate.channel);
        const titleScores = potentialArtists.map((a) => getArtistFrequencyScore(source.userId!, a));
        const maxTitleScore = titleScores.length > 0 ? Math.max(...titleScores) : 0;
        artistFrequencyBonus = Math.round((channelScore + maxTitleScore) / 20); // 0-10 bonus
    }

    // Calculate final score
    const baseScore =
        (titleSimilarity * 0.50) + // 50% weight on title match
        (artistMatch * 0.30) + // 30% weight on artist match
        goodIndicators.totalBonus +
        artistFrequencyBonus;

    const penalties = versionMismatchPenalty;
    const finalScore = Math.max(0, Math.min(100, baseScore - penalties));

    // Determine confidence
    let confidence: "high" | "medium" | "low" | "rejected";
    if (finalScore >= 70) {
        confidence = "high";
    } else if (finalScore >= 55) {
        confidence = "medium";
    } else if (finalScore >= 40) {
        confidence = "low";
    } else {
        confidence = "rejected";
    }

    return {
        candidateId: candidate.id,
        candidateTitle: candidate.title,
        candidateChannel: candidate.channel,
        score: Math.round(finalScore),
        confidence,
        breakdown: {
            titleSimilarity,
            artistMatch,
            goodIndicatorBonus: goodIndicators.totalBonus,
            badVariantPenalty: 0, // Didn't reject, so no penalty applied
            versionMismatchPenalty,
            artistFrequencyBonus,
        },
        variantAnalysis,
        goodIndicators,
        rejected: false,
        rejectionReason: null,
    };
};

const createRejectedResult = (
    candidate: CandidateTrack,
    reason: string,
    variantAnalysis: VariantAnalysis
): ScoringResult => ({
    candidateId: candidate.id,
    candidateTitle: candidate.title,
    candidateChannel: candidate.channel,
    score: 0,
    confidence: "rejected",
    breakdown: {
        titleSimilarity: 0,
        artistMatch: 0,
        goodIndicatorBonus: 0,
        badVariantPenalty: 100,
        versionMismatchPenalty: 0,
        artistFrequencyBonus: 0,
    },
    variantAnalysis,
    goodIndicators: {
        isTopicChannel: false,
        isVevoChannel: false,
        hasOfficialAudio: false,
        hasOfficialVideo: false,
        totalBonus: 0,
    },
    rejected: true,
    rejectionReason: reason,
});

// ============================================================================
// RESOLUTION
// ============================================================================

export interface ResolutionResult {
    success: boolean;
    matchedId: string | null;
    matchedTitle: string | null;
    matchedChannel: string | null;
    score: number;
    confidence: "high" | "medium" | "low" | "rejected";
    queryUsed: string;
    candidatesEvaluated: number;
    candidatesRejected: number;
    allScores: ScoringResult[];
}

const ACCEPTANCE_THRESHOLD = 40;

/**
 * Resolve the best matching candidate from a list.
 * Filters out bad variants first, then scores remaining.
 */
export const resolveFromCandidates = (
    source: SourceTrack,
    candidates: CandidateTrack[],
    queryUsed: string
): ResolutionResult => {
    if (candidates.length === 0) {
        return createEmptyResult(queryUsed);
    }

    // Score all candidates
    const allScores = candidates.map((c) => scoreCandidate(source, c));

    // Separate rejected from valid
    const rejected = allScores.filter((s) => s.rejected);
    const valid = allScores.filter((s) => !s.rejected);

    // Sort valid by score descending
    valid.sort((a, b) => b.score - a.score);

    // Get best valid candidate
    if (valid.length > 0 && valid[0].score >= ACCEPTANCE_THRESHOLD) {
        const best = valid[0];
        return {
            success: true,
            matchedId: best.candidateId,
            matchedTitle: best.candidateTitle,
            matchedChannel: best.candidateChannel,
            score: best.score,
            confidence: best.confidence === "rejected" ? "low" : best.confidence,
            queryUsed,
            candidatesEvaluated: candidates.length,
            candidatesRejected: rejected.length,
            allScores,
        };
    }

    // No valid match above threshold
    return {
        success: false,
        matchedId: null,
        matchedTitle: null,
        matchedChannel: null,
        score: valid.length > 0 ? valid[0].score : 0,
        confidence: "rejected",
        queryUsed,
        candidatesEvaluated: candidates.length,
        candidatesRejected: rejected.length,
        allScores,
    };
};

const createEmptyResult = (queryUsed: string): ResolutionResult => ({
    success: false,
    matchedId: null,
    matchedTitle: null,
    matchedChannel: null,
    score: 0,
    confidence: "rejected",
    queryUsed,
    candidatesEvaluated: 0,
    candidatesRejected: 0,
    allScores: [],
});

// ============================================================================
// SEARCH QUERY GENERATION
// ============================================================================

/**
 * Generate multiple search queries with different strategies.
 */
export const generateSearchQueries = (source: SourceTrack): string[] => {
    const queries: string[] = [];
    const { title, artist } = source;

    // Clean the title
    const cleanedTitle = cleanTitle(title);

    // Get just the core title (first segment before separators)
    const coreTitle = title
        .split(/\s*[-|•:]\s*/)[0]
        .replace(/\([^)]*\)/g, "")
        .replace(/\[[^\]]*\]/g, "")
        .trim();

    // Strategy 1: Full original title + artist
    queries.push(`${title} ${artist}`);

    // Strategy 2: Cleaned title + artist
    if (cleanedTitle !== title.toLowerCase()) {
        queries.push(`${cleanedTitle} ${artist}`);
    }

    // Strategy 3: Core title + artist
    if (coreTitle.toLowerCase() !== cleanedTitle) {
        queries.push(`${coreTitle} ${artist}`);
    }

    // Strategy 4: Add "official audio" for better results
    queries.push(`${coreTitle} ${artist} official audio`);

    // Strategy 5: Add "topic" for auto-generated channels
    queries.push(`${coreTitle} ${artist} topic`);

    // Strategy 6: Just the song title (fallback)
    queries.push(coreTitle);

    // Strategy 7: Artist + "songs" (very fallback)
    queries.push(`${artist} ${coreTitle}`);

    // Remove duplicates
    const seen = new Set<string>();
    return queries.filter((q) => {
        const normalized = q.toLowerCase().trim();
        if (seen.has(normalized) || normalized.length < 3) return false;
        seen.add(normalized);
        return true;
    });
};

// ============================================================================
// LOGGING
// ============================================================================

export const logResolution = (
    source: SourceTrack,
    result: ResolutionResult,
    context: string
): void => {
    const prefix = `[track-resolver][${context}]`;

    if (result.success) {
        console.info(`${prefix} ✓ MATCHED`, {
            sourceTitle: source.title,
            sourceArtist: source.artist,
            matchedTitle: result.matchedTitle,
            matchedChannel: result.matchedChannel,
            score: result.score,
            confidence: result.confidence,
            queryUsed: result.queryUsed,
            candidatesEvaluated: result.candidatesEvaluated,
            candidatesRejected: result.candidatesRejected,
        });
    } else {
        const topValid = result.allScores
            .filter((s) => !s.rejected)
            .slice(0, 3)
            .map((s) => ({
                title: s.candidateTitle.substring(0, 50),
                channel: s.candidateChannel,
                score: s.score,
                breakdown: s.breakdown,
            }));

        const rejectedReasons = result.allScores
            .filter((s) => s.rejected)
            .slice(0, 3)
            .map((s) => ({
                title: s.candidateTitle.substring(0, 50),
                reason: s.rejectionReason,
            }));

        console.warn(`${prefix} ✗ NO MATCH`, {
            sourceTitle: source.title,
            sourceArtist: source.artist,
            queryUsed: result.queryUsed,
            candidatesEvaluated: result.candidatesEvaluated,
            candidatesRejected: result.candidatesRejected,
            topValid,
            rejectedExamples: rejectedReasons,
        });
    }
};
