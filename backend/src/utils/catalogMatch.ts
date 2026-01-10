type Tokens = string[];

const TITLE_NOISE = new Set([
  "from",
  "original",
  "motion",
  "picture",
  "soundtrack",
  "official",
  "audio",
  "video",
  "topic",
  "vevo",
  "remix",
  "remastered",
  "live",
]);

const ARTIST_NOISE = new Set(["topic", "vevo"]);

const splitTokens = (value: string): Tokens => value.split(/[^a-z0-9]+/g).filter(Boolean);

const filterTokens = (tokens: Tokens, noise: Set<string>): Tokens =>
  tokens
    .filter((t) => !noise.has(t))
    .filter((t) => t.length >= 3);

const stripBracketsAndPunctuation = (value: string): string => {
  const lower = (value || "").toLowerCase();
  const noBrackets = lower.replace(/[()\[\]{}<>]/g, " ");
  return noBrackets.replace(/[^a-z0-9\s]/g, " ");
};

export const tokenizeTitle = (title: string): Tokens => {
  const stripped = stripBracketsAndPunctuation(title);
  const tokens = splitTokens(stripped);
  return filterTokens(tokens, TITLE_NOISE);
};

export const tokenizeArtist = (artist: string): Tokens => {
  const lower = (artist || "").toLowerCase().replace(/\s*-\s*topic$/i, "");
  const stripped = lower.replace(/[^a-z0-9\s]/g, " ");
  const tokens = splitTokens(stripped);
  return filterTokens(tokens, ARTIST_NOISE);
};

export interface MatchCandidate {
  id: string;
  title: string;
  artist?: string | null;
  description?: string | null;
}

interface Score {
  titleScore: number;
  artistScore: number;
  finalScore: number;
}

const scoreCandidate = (
  sourceTitleTokens: Tokens,
  sourceArtistTokens: Tokens,
  candidate: MatchCandidate
): Score => {
  const resultTitleTokens = tokenizeTitle(candidate.title);
  const resultArtistTokens = tokenizeArtist(candidate.artist || "");
  const descriptionTokens = tokenizeTitle(candidate.description || "");

  const titleTokenSet = new Set(resultTitleTokens);
  const artistTokenSet = new Set([...resultTitleTokens, ...resultArtistTokens, ...descriptionTokens]);

  const titleMatches = sourceTitleTokens.filter((t) => titleTokenSet.has(t)).length;
  const artistMatches = sourceArtistTokens.filter((t) => artistTokenSet.has(t)).length;

  const titleScore = sourceTitleTokens.length === 0 ? 0 : titleMatches / sourceTitleTokens.length;
  const artistScore = sourceArtistTokens.length === 0 ? 0 : artistMatches / sourceArtistTokens.length;
  const finalScore = 0.7 * titleScore + 0.3 * artistScore;

  return { titleScore, artistScore, finalScore };
};

export const findBestMatch = (
  sourceTitle: string,
  sourceArtist: string,
  candidates: MatchCandidate[]
): string | null => {
  const sourceTitleTokens = tokenizeTitle(sourceTitle);
  const sourceArtistTokens = tokenizeArtist(sourceArtist);

  if (sourceTitleTokens.length < 3) {
    console.warn("[catalog-match] skip: insufficient title tokens", {
      sourceTitle,
      sourceArtist,
      sourceTitleTokens,
      sourceArtistTokens,
    });
    return null;
  }

  let best: { id: string; score: Score; candidate: MatchCandidate } | null = null;

  for (const candidate of candidates) {
    const score = scoreCandidate(sourceTitleTokens, sourceArtistTokens, candidate);
    const accepted = score.titleScore >= 0.8 && score.finalScore >= 0.7;

    if (accepted) {
      if (!best || score.finalScore > best.score.finalScore) {
        best = { id: candidate.id, score, candidate };
      }
    }

    console.info("[catalog-match] evaluated", {
      sourceTitle,
      sourceArtist,
      sourceTitleTokens,
      sourceArtistTokens,
      candidateTitle: candidate.title,
      candidateArtist: candidate.artist,
      titleScore: score.titleScore,
      artistScore: score.artistScore,
      finalScore: score.finalScore,
      accepted,
    });
  }

  if (!best) {
    console.warn("[catalog-match] no acceptable match", {
      sourceTitle,
      sourceArtist,
      sourceTitleTokens,
      sourceArtistTokens,
    });
    return null;
  }

  console.info("[catalog-match] accepted", {
    sourceTitle,
    sourceArtist,
    sourceTitleTokens,
    sourceArtistTokens,
    matchedTitle: best.candidate.title,
    matchedArtist: best.candidate.artist,
    titleScore: best.score.titleScore,
    artistScore: best.score.artistScore,
    finalScore: best.score.finalScore,
  });

  return best.id;
};
