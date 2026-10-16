# Codebook: scored final test (`data/derived/test_scored_items.csv`, `data/derived/test_scored_topics.csv`)

**What they are.** Final-test responses scored by `grade_test.R` with the same rules as the
prequestions (`scoring_rubric.R`; see `preq_scored.md` for how responses were scored).
All participants in the eye-tracking data with a test session (139 participants). Produced
by the pipeline; do not edit by hand.

## `test_scored_items.csv` — one row per participant × question (1,390 rows)

Same columns as `preq_scored_items.csv` (see `preq_scored.md`): `file`, `psychopy_id`,
`psychopy_group`, `response`, `questnum`, `topic`, `max_points`, `answer`, `points`,
`credited`, `blank`, `id_norm`, `et_id`, `et_group`. `et_group` here also includes
`Control`. P60 and P93 (Control) carry a leftover "polio" label in their raw PsychoPy
test files; `psychopy_group` is corrected to "control" in `scoring_rubric.R`
(`group_corrections`).

## `test_scored_topics.csv` — one row per participant × topic (278 rows)

| Column | Type | Description |
|---|---|---|
| `file`, `psychopy_id`, `et_id`, `et_group`, `psychopy_group` | | As above. |
| `topic` | text | `Polio` or `TB` (5 questions each). |
| `n_questions` | integer | Questions on the topic (5). |
| `n_answered` | integer | Questions attempted (not blank). |
| `points` | integer | Points earned on the topic (of 12). The preregistered outcome. |
| `max_points` | integer | Points available (12). |
| `prop_correct` | proportion | `points / max_points`. |
