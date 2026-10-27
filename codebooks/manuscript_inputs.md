# Codebook: `data/derived/manuscript_inputs.rds`

**What it is.** A named list of the descriptive values and small tables the manuscript
reports outside the Bayesian models (sample, exclusions, calibration, materials, fixation
processing), written by `scripts/manuscript_inputs.R` so that the manuscript does not
recompute them. Durations in ms; proportions 0–1.

| Element | Description |
|---|---|
| `n_total`, `n_by_cond` | Final sample size, overall and by condition (`condition`, `n`). |
| `n_recordings`, `n_excluded` | Participants with eye-tracking recordings; participants excluded other than for calibration. |
| `excluded_incomplete`, `excluded_calibration`, `excluded_no_pretest`, `excluded_no_test` | Participants excluded at each step (with `condition`/`group`, and pages or calibration `accuracy`/`precision` in degrees). |
| `calib_n`, `calib_summary`, `calib_over` | Calibration of the analysed participants: N, mean/SD/min/max of accuracy and precision (°), and anyone over the 0.5° criterion. |
| `preq_by_cond` | Prequestion scores by condition (`n`, `pre_m`, `pre_sd`: mean and SD proportion of points; `att_m`: proportion of questions attempted). |
| `answer_key`, `points_by_topic` | `stimuli/answer_key.csv` and the points per topic. |
| `n_sentences`, `n_words_passage`, `words_by_topic`, `text_metrics` | Text statistics: sentences, words; words per target sentence by topic; Flesch–Kincaid grade (`fk`), mean dependency distance (`mdd`) and clauses per target sentence by topic (M, SD). |
| `regions`, `region_labels`, `targets2` | Sentence regions for the page figures, as in `codebooks/derived_sentence_regions.md`, with `role` (`Polio target`, `TB target`, `Other sentence`). |
| `share_short`, `share_long`, `fix_median` | Share of fixations discarded as < 80 ms or > 1,000 ms; median fixation duration. |
| `share_assigned`, `share_agree` | Share of on-screen fixations assigned to a sentence after processing; share whose sentence agrees with Tobii Pro Lab's. |
| `fp_present_derived` | Share of fixated target sentences with first-pass reading (not skipped). |
| `landed_below` | Share of pages on which the first fixation fell below the first sentence. |
| `max_shift_cm` | The drift-correction limit (0.5°) in cm. |
| `drift_id`, `fx_drift`, `drift_ex` | The participant shown in the drift-correction figure, their fixations (columns as `codebooks/derived_fixations.md`), and their shift (line spacings) and share of relabelled fixations. |
| `drift_stats` | Per participant × page: median vertical `shift` (line spacings) and share of fixations `relabelled`. |
| `share_not_reread`, `n_not_fixated`, `n_dat` | Share of fixated target sentences not re-read; target sentences never fixated; participant × target-sentence rows. |
