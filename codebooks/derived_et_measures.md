# Codebook: `data/derived/et_measures.tsv`

**What it is.** Sentence-level eye-movement measures derived from the fixation data by
`derive_et_measures.R` (with vertical drift correction and a page-landing correction; see
the script header and the manuscript's Eye-Movement Data Processing section). One row per
recording × page × sentence for every processed page of `data/raw/tobii/fixations.tsv` (all 160
participants; P101's page 3 is missing: no fixations were recorded). Durations
are in **ms** here; the analysis divides them by `number_of_units` (ms per word).
Produced by the pipeline; do not edit by hand.

Terms: a *visit* (pass) is a run of consecutive fixations on the same sentence. *Reading
start* is the first fixation on the page's first sentence; fixations before it are the
*landing* when the page appears. "Earlier"/"later" = sentence order on the page.

| Column | Type | Description |
|---|---|---|
| `recording`, `participant`, `group`, `toi`, `aoi`, `type`, `sentence_index`, `number_of_units` | | Recording and participant from `data/raw/tobii/fixations.tsv`; sentence text, order, type and word count from `stimuli/sentences.tsv`. `page` = page number (1–4). `type`: `PO`/`TB` target, `Control` = non-target sentence. |
| `total_duration` | ms | All fixations on the sentence (including landing). = `landing_duration + first_pass_duration + second_pass_duration`. **Analysed: total gaze duration (ex-Gaussian).** |
| `landing_duration` | ms | Fixations on the sentence before reading started. |
| `first_pass_duration` | ms | From first entering the sentence until first leaving it; `NA` if a later sentence had already been read (skipped on first pass). **Analysed: first-pass duration.** |
| `first_pass_regression` | 0/1 | 1 if the first pass ended by moving to an earlier sentence, 0 if to a later one; `NA` if no first pass, if the page ended during it, or for sentence 1 of a page. **Analysed.** |
| `regression_path` | ms | Go-past time: from first entering the sentence until first fixating a later sentence, including time on earlier sentences. |
| `selective_regression_path` | ms | Go-past time counting only fixations on the sentence itself. |
| `rereading_duration` | ms | Tobii-style re-reading: `regression_path - first_pass_duration` if the first pass ended in a regression, else 0. Not analysed. |
| `second_pass_duration` | ms | Time on the sentence after reading started, outside the first pass (`total - first pass - landing`). **Analysed as re-reading**: whether > 0 (re-read) and, if > 0, its duration. |
| `n_passes` | count | Visits to the sentence after reading started. |
| `n_revisits` | count | Returns after the first pass (`n_passes - 1`); `NA` if skipped on first pass. |
| `revisited` | 0/1 | `n_revisits > 0`. |
| `n_regressions_in` | count | Returns to the sentence **from later text** after its first pass. |
| `regressed_in` | 0/1 | `n_regressions_in > 0`. **Analysed: second-pass regressions (exploratory).** |
| `pe_firstpass_nfix`, `pe_firstpass_duration` | count, ms | First-pass fixations by popEye's definition (the sentence is the furthest one reached; continues after a brief look back). Report only (exploratory). |
| `pe_firstpass_forward_nfix`, `pe_firstpass_forward_duration` | count, ms | popEye first-pass fixations on a word beyond the furthest word read so far (forward reading). Report only. |
| `pe_firstpass_reread_nfix`, `pe_firstpass_reread_duration` | count, ms | popEye first-pass fixations on an earlier word (re-reading within the sentence). Report only. |
| `derived_available` | logical | `TRUE` for every row (all output pages are processed); kept for compatibility. |

`NA` conventions: sentences never fixated have `total_duration = 0`, `n_passes = 0`, and
`NA` for pass-based measures.
