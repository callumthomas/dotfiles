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

// Convenience for plain string arrays.
export function matchStrings(
  query: string,
  items: readonly string[],
  limit: number,
): FuzzyHit<string>[] {
  return match(query, items, (s) => s, limit)
}
