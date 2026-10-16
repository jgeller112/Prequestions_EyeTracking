# Codebook: `stimuli/answer_key.csv`

**What it is.** The ten questions (used as prequestions and on the final test) and their
answers. Read by `grade_prequestions.R`, `grade_test.R`, the analysis and the manuscript.
The detailed scoring rules for each question are in `scoring_rubric.R` (`score_one()`) and
in Appendix A of the manuscript.

| Column | Type | Description |
|---|---|---|
| `Question` | text | Question text as shown to participants. |
| `Points` | integer | Maximum points for the question (1–4; one point per answer element). Each topic totals 12 points. |
| `Answer` | text | The correct answer. |
| `Condition` | text | Topic of the question: `Polio` (questions 1–4, 10) or `TB` (5–9). |
| `questnum` | integer | Question number (1–10), used to link prequestion and test items and target sentences. |
