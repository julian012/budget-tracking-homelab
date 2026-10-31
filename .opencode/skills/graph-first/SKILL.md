---
name: graph-first
description: Policy for structural repo analysis with the codebase-memory MCP (code graph). ALWAYS use before touching code in any issue: symbol discovery, impact analysis, and blast radius validation.
---

## General rule

For **structural** questions about the code, use the `codebase-memory` MCP tools
first; `grep`/`read` are left for literal text, strings, docs, and non-code
config.

| Question | Tool |
|----------|------|
| Who calls X? / what breaks if I change Y? | `trace_path` (inbound/outbound) |
| Where is X defined? Are there duplicates? | `search_graph` (BM25 query / name_pattern / semantic_query) |
| How critical/used is this code? | `get_architecture` (hotspots) |
| Read the exact source of a symbol | `get_code_snippet` |
| Impact of my diff before the PR | `detect_changes --since main` |
| Literal text, docs, YAML, strings | `grep` (the graph does not cover non-code) |

## When to use (by work phase)

1. **Before implementing** any issue: `search_graph` to map the symbols
   involved + `trace_path` to confirm real callers/usages. Do not assume from
   grep that something "is unused" — verify CALLS/USAGE edges.
2. **During**: `get_code_snippet` to read the exact context of each function to be touched.
3. **Before opening the PR**: `detect_changes` (or outbound `trace_path` on the
   changed symbols) to validate that the blast radius matches expectations —
   if a module you did not consider appears, review before pushing.

## Index hygiene

- The index lives in `.codebase-memory/` and auto-updates in the background; after
  large merges or structural changes, use `index_status` to check freshness and
  `index_repository` if there is drift.
- `check_index_coverage` on every cited file before claiming "the graph does not
  have it" — coverage is best-effort.
- The `index_repository` output marks `parse_partial` (unparsed line range):
  treat those areas as grep territory, not graph territory.
- Build artifacts excluded via `.cbmignore` (Android `.cxx`, `dist/`, etc.) — if
  junk shows up in results, add the pattern and re-index.

## Limitations

- The graph does not detect logic bugs and does not replace tests.
- Dynamic relationships (reflection, Flutter↔native method channels, callbacks by
  string) may not appear: for those, grep complements.
- A `callers_total: 0` is a strong signal of orphaned code, but confirm with grep
  for the literal name before deleting (e.g., routes passed as strings in HTTP clients).
