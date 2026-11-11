# Topic familiarity (`data/raw/qualtrics/familiarity.csv`)

Self-rated familiarity with the passage topics, collected in Qualtrics **before the reading**.
Participants entered their names in the survey; the names were matched to session IDs with
the lab's named run sheet (not part of this repository) and then removed, so the file holds
participant IDs only. Matches were checked against session dates. Not every participant
completed the survey, and some responses could not be matched to a session, so the file
covers 139 sessions, including 108 of the 138 analysed participants.
One duplicate submission was resolved by keeping the more complete response.

| Column | Meaning |
|---|---|
| `participant` | Eye-tracking participant ID (as in `data/raw/tobii/fixations.tsv`); for sessions without an eye-tracking recording, the run-sheet ID. |
| `familiarity_gates` | "Estimate your knowledge of the Gates Foundation", 0 (never heard of them) to 100 (expert). Not used in the analyses. |
| `familiarity_polio` | "Estimate your knowledge of Polio", 0 (never heard of it) to 100 (expert). |
| `familiarity_tb` | "Estimate your knowledge of Tuberculosis", 0 (never heard of it) to 100 (expert). |

Blank = slider left at its starting point; Qualtrics saves this as blank, and it is scored 0 in the code. Used descriptively in the manuscript (Participants), via
`scripts/manuscript_inputs.R` (`fam_n`, `fam_summary`, `fam_by_cond`).
