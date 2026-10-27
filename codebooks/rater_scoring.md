# Codebook: second-rater scoring files

The check of the automated scoring by a research assistant (manuscript: Scoring; Appendix
Table A2). `scripts/make_ra_scoring_sheet.R` writes a blind scoring sheet and its key; the
rater fills in the sheet; `scripts/rater_agreement.R` merges the returned sheet with the key.
**The key must not be given to the rater.**

## `scoring/ra_scoring_sheet.xlsx` (sent to the rater) and `data/raw/rater/ra_scoring_sheet_scored.xlsx` (as returned)

Three sheets. `Instructions`: how to score. `Rubric`: per question (`Q`), the `Question`,
`Correct answer`, `Max points` and the elements credited (one point each unless stated).
`Scoring`: one row per non-blank prequestion or final-test response, in random order,
with no participant ID, condition, test phase or automated score:

| Column | Type | Description |
|---|---|---|
| `Row` | integer | Row number. |
| `Item ID` | text | Response identifier (`R0001`, ...); links to the key. |
| `Q`, `Question`, `Correct answer`, `Max points` | | The question (1–10) and its answer and maximum points. |
| `Response` | text | The participant's response, verbatim. |
| `Score` | integer | Points awarded by the rater (0 to `Max points`); empty in the sheet sent out. |
| `Notes` | text | Optional rater comments. |

The returned file also contains the second batch (R1666–R1678; see `data/raw/rater/README.md`).

## `scoring/ra_scoring_key.csv`

| Column | Type | Description |
|---|---|---|
| `item_id` | text | As `Item ID` in the sheet. |
| `phase` | text | `Prequestion` or `Final test`. |
| `participant` | text | Participant ID. |
| `questnum` | integer | Question number (1–10). |
| `max_points` | integer | Maximum points for the question. |
| `auto_points` | integer | Points from the automated scoring (`scripts/scoring_rubric.R`). |
| `response` | text | The response (checked against the returned sheet row by row). |

## `data/derived/rater_disagreements.csv`

Every response on which the rater and the automated scoring differ.
Columns `item_id`, `phase`, `questnum`, `max_points`, `response`, `auto_points` as in the
key, and `rater_points` (the rater's score).

## `data/derived/rater_agreement.rds`

A list of four tables: `overall` (all responses), `by_phase` (prequestions, final test),
`by_question` (per question; `questnum`, `max_points`) and `totals` (participants' final-test
totals). Columns:

| Column | Description |
|---|---|
| `n` | Number of responses (participants for `totals`). |
| `exact` | Proportion on which the two scores are equal. |
| `within1` | Proportion differing by at most one point. |
| `icc`, `icc_lo`, `icc_hi` | ICC(2,1) (two-way random effects, absolute agreement, single rater) and its 95% CI, from `irr::icc()` (`by_question` has no CI). `NaN` if neither scoring varies. |
| `n_disagree` | Number of responses on which the scores differ. |
| `rater_minus_auto` | Mean of rater − automated score. |
