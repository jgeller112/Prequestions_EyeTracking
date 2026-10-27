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

Only the measures reported in the manuscript are included (definitions follow Schotter &
Dillon, 2025). For every sentence read on first pass,
`total_duration = landing_duration + selective_regression_path + rereading_duration`, so the
analysed measures do not overlap.

| Column | Type | Description |
|---|---|---|
| `recording`, `participant`, `group`, `toi`, `aoi`, `type`, `sentence_index`, `number_of_units` | | Recording and participant from `data/raw/tobii/fixations.tsv`; sentence text, order, type and word count from `stimuli/sentences.tsv`. `page` = page number (1–4). `type`: `PO`/`TB` target, `Control` = non-target sentence. |
| `total_duration` | ms | All fixations on the sentence (including landing). **Analysed: total gaze duration (ex-Gaussian).** |
| `landing_duration` | ms | Fixations on the sentence before reading started. Used only to compute `rereading_duration`. |
| `selective_regression_path` | ms | Selective regression-path duration: fixations on the sentence from first entering it until the eyes first move to a later sentence (brief returns to earlier text do not end it; time on earlier text is not counted); `NA` if a later sentence had already been read (skipped on first pass). **Analysed: first-pass reading (ex-Gaussian).** |
| `rereading_duration` | ms | Time on the sentence after the reader first moved on to later text (`total - landing - selective_regression_path`); `NA` if skipped on first pass. **Analysed: re-reading time (Gamma, when > 0).** |
| `regressed_in` | 0/1 | 1 if the reader came back to the sentence **from later text** after its first pass; `NA` if skipped on first pass. **Analysed: regressions-in (look-backs).** |
| `first_pass_duration` | ms | The preregistered first-pass duration: from first entering the sentence until first leaving it; `NA` if skipped on first pass. Not analysed: bimodal (see Methods and Appendix C). |
| `first_pass_regression` | 0/1 | 1 if the first pass ended by moving to an earlier sentence, 0 if to a later one; `NA` if no first pass, if the page ended during it, or for sentence 1 of a page. Not analysed: documents why first-pass duration was bimodal. |
| `derived_available` | logical | `TRUE` for every row (all output pages are processed); kept for compatibility. |

`NA` conventions: sentences never fixated have `total_duration = 0` and `landing_duration = 0`,
and `NA` for the other measures.
