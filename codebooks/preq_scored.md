# Codebook: scored prequestions (`data/derived/preq_scored_items.csv`, `data/derived/preq_scored_participants.csv`)

**What they are.** Prequestion (pretest) responses scored by `grade_prequestions.R`, using
the rules in `scoring_rubric.R`. Only participants in the Polio and TB prequestion
conditions of the eye-tracking data are kept (96 sessions; the analysis keeps the 90 who
are also in the final sample). Produced by the pipeline (`targets::tar_make()`); do not
edit by hand.

**How responses were scored.** A deterministic, rule-based script (`scoring_rubric.R`,
written by Claude Opus 5.5, `claude-opus-5-5`) awards one point per element of the correct
answer found in the response (rules per question: `score_one()` in `scoring_rubric.R`;
Appendix A of the manuscript). Blank responses, "I don't know" and similar, and random
keystrokes score 0; minor misspellings are accepted.

## `preq_scored_items.csv` — one row per participant × prequestion (480 rows)

| Column | Type | Description |
|---|---|---|
| `file` | text | PsychoPy file the response came from (`data/raw/psychopy/prequestions/`). |
| `psychopy_id` | text | Participant ID as typed in PsychoPy (raw, may contain typos such as `(144`). |
| `psychopy_group` | text | Condition as typed in PsychoPy (`po`, `tb`), after the corrections in `scoring_rubric.R`. Not used in the analysis. |
| `response` | text | The typed response (`NA` = left blank). |
| `questnum` | integer | Question number (1–10; see `answer_key.md`). |
| `topic` | text | Question topic (`Polio` / `TB`). |
| `max_points` | integer | Maximum points for the question. |
| `answer` | text | Correct answer (from the answer key). |
| `points` | integer | Points earned (0 to `max_points`). |
| `credited` | text | Answer elements credited, comma-separated (empty if none). |
| `blank` | logical | `TRUE` if no answer was given (blank or "I don't know"-type response). |
| `id_norm` | text | Normalized ID used for matching (`P` + the number in the ID). |
| `et_id` | text | Matched eye-tracking participant ID (the ID used in the analysis). |
| `et_group` | text | Condition from the eye-tracking data (`Po`, `TB`) — the authoritative condition. |

## `preq_scored_participants.csv` — one row per participant (96 rows)

| Column | Type | Description |
|---|---|---|
| `file`, `psychopy_id`, `et_id`, `et_group`, `psychopy_group`, `topic` | | As above (`topic` = the prequestioned topic). |
| `n_questions` | integer | Prequestions answered in the session (5). |
| `n_answered` | integer | Prequestions attempted (not blank). |
| `points` | integer | Points earned (of 12). |
| `max_points` | integer | Points available (12). |
| `prop_correct` | proportion | `points / max_points`. |
