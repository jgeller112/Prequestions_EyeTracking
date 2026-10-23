# Codebook: `data/raw/tobii/fixations.tsv`

**What it is.** Raw fixation export from Tobii Pro Lab: one row per fixation, for every
recording × text page (TOI). `data/raw/tobii/fixations.tsv` contains all 161 recorded participants
and is the file used (read by `derive_et_measures.R`; its participant list is also used
by `scoring_rubric.R` to match the PsychoPy files). Never edited; exclusions are applied in code.

**Format.** Tab-separated, UTF-8, header row; 17 columns.

| Column | Type | Description |
|---|---|---|
| `Recording` | text | Tobii Pro Lab recording name (participant ID, often with a condition suffix, e.g. `p72po`, `p130tb`, `P06control`). One recording per participant. |
| `Participant` | text | Participant ID as entered in Tobii Pro Lab (e.g. `P72`, `P132a`). This is the ID used throughout the analysis (`et_id` in the scored files). |
| `Did_you_learn_English_before_4_years_old?` | text | Participant variable recorded in Tobii Pro Lab (`Yes`/`No`). Not used. |
| `Group` | text | Condition: `Po` (Polio prequestions), `TB` (TB prequestions), `Control`. The authoritative condition label for the analysis. |
| `TOI` | text | Time of interest = text page, e.g. `page(1)`, `page(2) (1)`. The page number is the first number. |
| `Interval` | integer | Interval number within the TOI (always 1). Not used. |
| `Media` | text | Stimulus image shown (same as the page). Not used. |
| `Type` | text | Type of the sentence AOI the fixation was assigned to by Tobii Pro Lab: `PO` (Polio target), `TB` (TB target), `Control` (non-target sentence); empty if not on any AOI. |
| `Event_type` | text | Always `Fixation`. |
| `Validity` | text | Tobii validity of the fixation (`Whole` / `Partial`). Not used. |
| `EventIndex` | integer | Order of the fixation within the recording × page (time order). |
| `Start`, `Stop` | ms | Start and end time of the fixation, relative to the start of the TOI. |
| `Duration` | ms | Fixation duration. |
| `AOI` | text | Text of the sentence AOI Tobii Pro Lab assigned the fixation to (empty if none). Matches `text` in `stimuli/sentences.tsv`. |
| `FixationPointX`, `FixationPointY` | proportion | Fixation position as a proportion of screen width / height (0 = left / top, 1 = right / bottom). Screen: 1920 × 1080 px. |

**Notes.** Tobii Pro Lab's AOI assignment is affected by vertical drift; the analysis uses
the drift-corrected assignment in `data/derived/fixations.tsv` instead (see
`derived_fixations.md`). P01's page 2 (TOI `page(2)`, an earlier copy of the page image)
had no AOI labels in the first export; AOIs were added to that image and P01's rows in
`data/raw/tobii/fixations.tsv` were replaced with the re-export (same fixations, page 2 labelled). P101 has no fixations on page 3.
