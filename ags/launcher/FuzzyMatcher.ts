// Explicit file path: fuzzysort ships only "main" in package.json and no ESM build,
// which esbuild's neutral platform (AGS's bundler) won't resolve by default.
import fuzzysort from "fuzzysort/fuzzysort.js"

export interface FuzzyHit<T> {
  item: T
  score: number
}

/**
 * Match `query` against `items`, returning up to `limit` hits sorted best-first.
 * `keyFn` extracts the string to match against (for non-string items).
 */
export function match<T>(
  query: string,
  items: readonly T[],
  keyFn: (item: T) => string,
  limit: number,
): FuzzyHit<T>[] {
  if (!query) {
    // Empty query: return first `limit` items with score 0, preserving order.
    return items.slice(0, limit).map((item) => ({ item, score: 0 }))
  }
  const prepared = items.map((item) => ({ item, target: keyFn(item) }))
  const results = fuzzysort.go(query, prepared, {
    key: "target",
    limit,
  })
  return results.map((r) => ({ item: r.obj.item, score: r.score }))
}

// Fast path for plain string arrays over large corpora (100k+).
// fuzzysort's full algorithm is O(n·m) and chokes on 100k strings per keystroke.
// Strategy: case-insensitive substring pre-filter (linear scan, very fast) to
// cap the candidate set, then fuzzysort on the narrowed list for ranking.
// Trade-off: queries with non-contiguous characters (e.g. "hypnd" → "hyprland")
// won't match. In practice launcher users type contiguous substrings.
const PREFILTER_CAP = 2000

export function matchStrings(
  query: string,
  items: readonly string[],
  limit: number,
): string[] {
  if (!query) return items.slice(0, limit)
  const lq = query.toLowerCase()
  const narrowed: string[] = []
  for (let i = 0; i < items.length; i++) {
    if (items[i].toLowerCase().includes(lq)) {
      narrowed.push(items[i])
      if (narrowed.length >= PREFILTER_CAP) break
    }
  }
  if (narrowed.length <= limit) return narrowed
  const results = fuzzysort.go(query, narrowed, { limit })
  return results.map((r) => r.target)
}
