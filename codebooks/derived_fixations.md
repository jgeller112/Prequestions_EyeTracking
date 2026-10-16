# Codebook: `data/derived/fixations.tsv`

**What it is.** Fixation-level output of `derive_et_measures.R`: every on-screen fixation
with its recorded and drift-corrected position and its sentence assignment. Fixations
shorter than 80 ms or longer than 1,000 ms are discarded first and are not in this file.
Used for the figures and checks. Produced by the pipeline; do not edit by hand.

| Column | Type | Description |
|---|---|---|
| `recording`, `participant` | text | As in `raw_tobii_fixations.md`. |
| `page` | integer | Text page (1–4). |
| `event_index` | integer | Fixation order within the recording × page. |
| `duration` | ms | Fixation duration. |
| `x` | proportion | Horizontal position (proportion of screen width; not corrected). |
| `y_recorded` | proportion | Recorded vertical position (proportion of screen height). |
| `y_corrected` | proportion | Vertical position after drift correction. |
| `line` | integer | Text line the fixation was assigned to (1 = top line of the page). |
| `sentence_tobii` | integer | Sentence (`Sentence_index`) assigned by Tobii Pro Lab; `NA` = none. |
| `sentence_corrected` | integer | Sentence assigned after drift correction; `NA` = off the text. |
| `word` | integer | Word assigned after drift correction (words numbered across the page in reading order); `NA` = off the text. |
| `reading` | logical | `TRUE` once reading has started on the page (first fixation on sentence 1); `FALSE` = landing fixation. |
