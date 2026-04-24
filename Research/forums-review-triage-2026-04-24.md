---
source_simulation: forums-review-simulation-2026-04-24.md
triage_date: 2026-04-24
rule: FREVIEW-012
pre_classification_automated: true
final_classification_requires_human_review: true
---

# Concreteness-anchor triage — forums-review-simulation-2026-04-24

Pre-classifications are produced by `scripts/triage_simulation.py` using the
concreteness-anchor regex catalogue. **Final classifications require a human
review pass** to apply the manual escape hatch per [FREVIEW-012] — a post with
low anchor count MAY still be load-bearing if it surfaces a novel semantic
property of the target package. Such escapes MUST be justified in the
`final_classification_notes` column.

Quoted blocks (Discourse-style `> text` lines) and fenced code blocks are
excluded from the count — they don't count as the post author's own anchoring.

| # | handle | archetype (from comment) | anchor total | pre-classification | final classification | disposition |
|---|---|---|---:|---|---|---|
| 1 | @op-author | OP | 17 | op-follow-up | _pending review_ | _pending_ |
| 2 | @reviewer-1 | c1 | 7 | load-bearing-candidate | _pending review_ | _pending_ |
| 3 | @reviewer-9 | c9 | 13 | load-bearing-candidate | _pending review_ | _pending_ |
| 4 | @reviewer-8 | c8 | 4 | load-bearing-candidate | _pending review_ | _pending_ |
| 5 | @reviewer-10 | c10 | 4 | load-bearing-candidate | _pending review_ | _pending_ |
| 6 | @reviewer-3 | c3 | 5 | load-bearing-candidate | _pending review_ | _pending_ |
| 7 | @reviewer-4 | c4 | 11 | load-bearing-candidate | _pending review_ | _pending_ |
| 8 | @reviewer-2 | c2 | 2 | partially-load-bearing-candidate | _pending review_ | _pending_ |
| 9 | @reviewer-7 | c7 | 3 | load-bearing-candidate | _pending review_ | _pending_ |
| 10 | @reviewer-6 | c6 | 12 | load-bearing-candidate | _pending review_ | _pending_ |
| 11 | @reviewer-5 | c5 | 6 | load-bearing-candidate | _pending review_ | _pending_ |

## Anchor breakdown per post

- Post 1 (@op-author): backticked_qualified=12, se_crossref=5 (total 17).
- Post 2 (@reviewer-1): file_line=2, backticked_qualified=2, se_crossref=2, readme_ref=1 (total 7).
- Post 3 (@reviewer-9): file_line=2, backticked_type=1, backticked_qualified=5, se_crossref=5 (total 13).
- Post 4 (@reviewer-8): file_line=1, backticked_qualified=1, package_swift=2 (total 4).
- Post 5 (@reviewer-10): file_line=1, backticked_type=1, backticked_qualified=1, se_crossref=1 (total 4).
- Post 6 (@reviewer-3): file_line=2, backticked_fn=1, se_crossref=2 (total 5).
- Post 7 (@reviewer-4): file_line=1, backticked_type=1, backticked_qualified=5, se_crossref=4 (total 11).
- Post 8 (@reviewer-2): file_line=1, backticked_type=1 (total 2).
- Post 9 (@reviewer-7): file_line=2, readme_ref=1 (total 3).
- Post 10 (@reviewer-6): file_line=2, backticked_type=2, backticked_qualified=4, se_crossref=3, readme_ref=1 (total 12).
- Post 11 (@reviewer-5): source_file=1, file_line=2, backticked_qualified=3 (total 6).

## Human-review instructions

For each row:

1. Confirm or override the pre-classification. Overrides MUST be justified in prose.
2. For every load-bearing post (including escape-hatched), source-verify each anchor-grounded factual claim per `[FREVIEW-018]` BEFORE writing a disposition. Anchors make claims checkable, not correct — a post may correctly cite `Foo.swift:42` while drawing a false conclusion about what's there, whether a surrounding `#if` chain platform-restricts it, whether a count includes Tests/ or only Sources/, etc.
3. Write a one-sentence `disposition`: act-on / act-on-but-claim-N-false-premise / answer-cheaply / discount / escape-to-load-bearing-because-X. Verified-correct claims get plain `act-on`; verified-false claims get `act-on-but-claim-N-false-premise; archive`.
4. Archetype-shaped posts that are NOT escape-hatched should drive zero post-launch action.
5. If more than 50% of substantive posts are archetype-shaped, consider re-running the simulation with a different seed or a narrower archetype mix — the current thread may not be exercising the package's real surface.
6. When this record is archived as an observed-reception data point (`[FREVIEW-017]`), populate `claim_correctness` in the record per `observed_reception_schema.json` — axis 2 of calibration depends on per-archetype false-claim rates.
