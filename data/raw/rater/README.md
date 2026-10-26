# Second-rater scores (raw)

`ra_scoring_sheet_scored.xlsx`: the blind scoring sheet written by
`scripts/make_ra_scoring_sheet.R`, as returned by the research assistant (received
2026-10-21; not edited). Sheet `Scoring` has one row per non-blank prequestion or final-test
response, in random order, identified only by `Item ID`; the rater entered `Score` (0 to the
question's maximum points). The rater saw no participant IDs, conditions, test phases, or
automated scores. `scoring/ra_scoring_key.csv` links each `Item ID` to the participant,
phase and automated score; `scripts/rater_agreement.R` merges the two.

Rows R1666–R1678 (participant P191, tested after the sheet was made) were scored by the same
rater as a second batch (`scripts/make_ra_scoring_sheet.R`, returned 2026-10-23) and appended
to the `Scoring` sheet unchanged; their key rows are appended to `scoring/ra_scoring_key.csv`.
