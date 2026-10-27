# I Remember That Question: Using Eye Tracking to See How Prequestions Shape Reading

Jason Geller (Boston College). Preregistration: <https://osf.io/8env4>.

Participants read a four-page text about the Gates Foundation's efforts against polio and
tuberculosis (TB) while their eye movements were recorded. Before reading, they answered
five prequestions about polio, five about TB, or none (no-prequestion condition; labelled `Control` in the data and code). Afterwards, everyone
answered all ten questions. Each question's answer is in one target sentence, so every
target sentence is *prequestioned* for one group and *non-prequestioned* for another.

This repository contains the raw data, all code, and the manuscript. Everything — scoring,
the check of the scoring by a second rater, eye-movement measures, Bayesian analyses,
figures, and the manuscript itself — is produced from the raw data by one pipeline.

All file paths in the code are built with `here::here()` from the project root (marked by
the empty `.here` file), so every script and document runs from any working directory.

---

## Reproducing everything

### Requirements

| Software | Version used | Notes |
|---|---|---|
| R | 4.6.1 | |
| CmdStan | see `codebooks/r_package_versions.csv` | via cmdstanr (`cmdstanr::install_cmdstan()`) |
| Quarto | 1.10.18 | <https://quarto.org>; Typst (for the PDF) is bundled with Quarto |
| R packages | see `codebooks/r_package_versions.csv` | install with `install.packages()` |

Install the R packages (cogmod and cmdstanr may need to be installed from their own
repositories; see their documentation):

```r
install.packages(c("tidyverse", "easystats", "lme4", "lmerTest", "janitor", "here", "png",
                   "patchwork", "scales", "knitr", "xfun", "quarto", "callr", "targets",
                   "tarchetypes", "brms", "bayestestR", "modelbased",
                   "marginaleffects", "insight", "priorsense", "posterior", "extraDistr",
                   "ggdist", "quanteda", "quanteda.textstats", "udpipe", "qs2",
                   "openxlsx", "irr", "viridisLite"))
# plus cmdstanr and cogmod
```

### Run the pipeline

Open R in this folder and run:

```r
targets::tar_make()        # runs every step that is out of date
targets::tar_visnetwork()  # draws the pipeline (needs the visNetwork package)
targets::tar_outdated()    # lists the steps that would rerun
```

The pipeline is defined in `_targets.R`. It tracks every raw data file and script by
content: after a change, only the affected steps rerun. Its bookkeeping is stored in
`_targets/` (safe to delete; the next run starts from scratch).

**Fitted models.** The Bayesian models take several hours to fit from scratch (40,000
posterior draws each). Fits are cached in `analysis/brms_cache/` (not tracked by git) and
reused unless a model's data, formula or priors change. The fitted models are not in the
repository (about 3 GB): after cloning, `tar_make()` fits them, together with the prior-only
models used for the Bayes factors. The results files the manuscript reads
(`analysis/results_*.rds`) are included, so the manuscript can be rendered without fitting
anything. A supplementary prior-width sensitivity analysis (not reported in the manuscript) is not part of `tar_make()`
because it refits every model twice (about 2.5 hours): run `Rscript scripts/bf_sensitivity.R`
after `tar_make()`; it writes `analysis/results_bf_sensitivity.rds`, which is included.
Optionally, `Rscript scripts/export_brms_cache.R` saves the cached fits to `models/`
as `.qs2` files split into parts smaller than 90 MB (not tracked by git), from which
`R/bayes_helpers.R` restores any fit missing from the cache.

Steps and outputs:

| Step | Code | Reads | Writes |
|---|---|---|---|
| 1. Score prequestions | `scripts/grade_prequestions.R` (+ `scripts/scoring_rubric.R`) | `data/raw/psychopy/prequestions/*.csv`, `stimuli/answer_key.csv`, `data/raw/tobii/fixations.tsv` (eye-tracking IDs) | `data/derived/preq_scored_items.csv`, `data/derived/preq_scored_participants.csv` |
| 2. Score final test | `scripts/grade_test.R` (+ `scripts/scoring_rubric.R`) | `data/raw/psychopy/final_test/*.csv`, `stimuli/answer_key.csv`, `data/raw/tobii/fixations.tsv` (eye-tracking IDs) | `data/derived/test_scored_items.csv`, `data/derived/test_scored_topics.csv` |
| 3. Eye-movement measures | `scripts/derive_et_measures.R` | `data/raw/tobii/fixations.tsv`, `stimuli/sentences.tsv`, `stimuli/pages/page*_full.png` | `data/derived/et_measures.tsv`, `data/derived/fixations.tsv`, `data/derived/sentence_regions.tsv`, `data/derived/et_checks/*.png` |
| 4. Bayesian analysis reports | `R/setup.R`, `R/data.R`, `R/bayes_helpers.R` (shared), then `analysis/prequestions.qmd`, `analysis/final_test.qmd`, `analysis/eye_tracking.qmd` | outputs of 1–3, `data/raw/calibration/et_run_sheet.tsv` | `analysis/*.html` and the results files `analysis/results_prequestions.rds`, `analysis/results_final_test.rds`, `analysis/results_eye_tracking.rds` |
| 5. Manuscript inputs | `scripts/manuscript_inputs.R` | outputs of 1–3, raw fixations, calibration sheet, `stimuli/sentences.tsv`, `stimuli/udpipe/` | `data/derived/manuscript_inputs.rds` (sample, exclusions, calibration, materials, fixation processing) |
| 6. Second-rater agreement | `scripts/rater_agreement.R` | `data/raw/rater/ra_scoring_sheet_scored.xlsx`, `scoring/ra_scoring_key.csv` | `data/derived/rater_agreement.rds`, `data/derived/rater_disagreements.csv` |
| 7. Manuscript | `manuscript/manuscript.qmd` (+ `R/manuscript_helpers.R`; APA style via `manuscript/_extensions/wjschne/apaquarto`, `apa.csl`, `references.bib`) | the results files of 4–6 | `manuscript/manuscript.pdf`, `manuscript/manuscript.docx`, `manuscript/packages.bib` |

The manuscript does not refit or recompute anything: it reads the results files of steps
4–6 and fills in every number in the text, so a text-only change re-renders in about 20
seconds. A `claims-check` chunk stops the render if a statement in the text (e.g., "was
longer") no longer matches the results.

**Blinded version for peer review.** From `manuscript/`, run
`MS_MASKED=true quarto render manuscript.qmd --to apaquarto-docx -M mask:true --output manuscript_blinded.docx`
(and `--to apaquarto-typst ... --output manuscript_blinded.pdf`), then `targets::tar_make()`
to rebuild the regular PDF, which Quarto replaces when it writes the blinded one. apaquarto's
`mask` option removes the author block and author note and masks the citations listed under
`masked-citations`; `MS_MASKED=true` replaces identifying details in the text (university,
task links) and swaps in anonymized links to the preregistration and repository. The blinded
files and the separate title page are not tracked on `master`; the `review` branch holds the
anonymized copy of the repository used for peer review.

---

## Folder structure

```
_targets.R                     pipeline definition (targets)
.here                          marks the project root for here::here()
README.md                      this file
codebooks/                     a codebook (data dictionary) for every data file; see Codebooks below
  r_package_versions.csv         R and package versions used

data/
  raw/                         RAW data: never edited (exclusions and corrections are made in code)
    tobii/fixations.tsv          Tobii Pro Lab fixation export, all 161 recorded participants
    psychopy/prequestions/       PsychoPy prequestion sessions (.csv + .log.gz)
    psychopy/final_test/         PsychoPy final-test sessions (.csv + .log.gz)
    calibration/                 et_run_sheet.tsv: lab run sheet with calibration results (names removed) + README
    rater/                       ra_scoring_sheet_scored.xlsx: second rater's scores on the blind sheet, as returned + README
  derived/                     DERIVED: written by the pipeline (safe to delete; tar_make() rebuilds it)
    preq_scored_items.csv, preq_scored_participants.csv   step 1
    test_scored_items.csv, test_scored_topics.csv         step 2
    et_measures.tsv              step 3: sentence-level eye-movement measures
    fixations.tsv                step 3: fixations with drift-corrected positions and sentences
    sentence_regions.tsv         step 3: sentence areas of interest on each text line
    et_checks/                   step 3: before/after drift-correction plots
    manuscript_inputs.rds        step 5: descriptive values for the manuscript
    rater_agreement.rds, rater_disagreements.csv   step 6

stimuli/
  sentences.tsv                the text: page, order, type, word count and text of every sentence
  answer_key.csv               the ten questions, answers and points
  pages/                       screenshots of the four text pages: page1-4.png and full-resolution
                               page1-4_full.png (used to locate the text lines; see its README)
  tobii_images/                the four text pages as exported by Tobii Pro Lab, renamed page1-4.png
  Prequestion_reading_v2.docx  the text as written
  udpipe/                      English (EWT) udpipe model, for the syntactic-complexity measures

scripts/
  scoring_rubric.R             scoring rules + helpers for steps 1-2 (ID matching, corrections)
  grade_prequestions.R         step 1
  grade_test.R                 step 2
  derive_et_measures.R         step 3 (fully commented; settings, e.g. fixation limits, near the top);
                               computes only the measures reported in the manuscript
  manuscript_inputs.R          step 5
  rater_agreement.R            step 6: agreement between the automated scores and the second rater (irr)
  make_ra_scoring_sheet.R      blind scoring sheet for a second rater and its key (writes scoring/)
  bf_sensitivity.R             supplementary: Bayes factors with the effect priors halved and doubled (not in the manuscript;
                               run separately, about 2.5 hours)
  export_brms_cache.R          optional: exports the fitted models to models/ as split .qs2 parts
  split_qs2.R                  splits .qs2 files into < 90 MB parts and recombines them
R/
  setup.R                      shared: packages, colours, text helpers
  data.R                       shared: import, exclusions, calibration, analysis data sets
  bayes_helpers.R              shared by the analysis reports: priors, fitting, contrasts,
                               Bayes factors, diagnostics, results files
  manuscript_helpers.R         functions used by the manuscript (text helpers, page figures,
                               the eye-movement measures schematic)
analysis/                      step 4: one Bayesian report per part (code + explanations)
  prequestions.qmd / .html     prequestion scores; TB vs. Polio condition (described)
  final_test.qmd / .html       final test: specific and general benefits, Group x Topic,
                               choice of model (beta-binomial vs. binomial)
  eye_tracking.qmd / .html     eye movements: specific and general effects, Group x Topic
  results_prequestions.rds, results_final_test.rds, results_eye_tracking.rds
                               results read by the manuscript
  results_bf_sensitivity.rds   supplementary prior-width sensitivity of the Bayes factors (not in the manuscript)
  brms_cache/                  fitted models (not tracked by git; fitted by tar_make())
models/                        optional export of the fitted models (not tracked by git)
manuscript/                    step 7: the paper
  manuscript.qmd               source (its R code runs from the project root)
  manuscript.pdf, .docx        rendered paper
  figures/                     every figure of the paper, written at render time, as a
                               600-dpi PNG and a vector PDF (figure1_aois, figure2_scanpath,
                               figure3_measures, figure4_test, figure5_eye)
  references.bib, apa.csl      literature references and citation style
  packages.bib                 R package references, written at render time
  _extensions/                 APA formatting extension (apaquarto)
scoring/                       for the second rater (see Privacy)
  ra_scoring_sheet.xlsx        blind scoring sheet sent to the rater
  ra_scoring_key.csv           its key (links each response to participant, phase and
                               automated score); never given to the rater
power/                         sample-size planning (before data collection; not part of the pipeline)
  power_analysis.qmd           simulation-based power analysis (mixedpower), pilot data
  pilot_reading1.csv           pilot final-test data
```

**RAW files are never edited.** All exclusions, ID matching, and label corrections are
made in code, with comments explaining each one.

## Codebooks

Every data file has a codebook (data dictionary) in `codebooks/` describing each column
(or, for `.rds` files, each element), its units and how missing values are coded.

| File | Codebook |
|---|---|
| `data/raw/tobii/fixations.tsv` | `codebooks/raw_tobii_fixations.md` |
| `data/raw/psychopy/prequestions/*.csv`, `data/raw/psychopy/final_test/*.csv` | `codebooks/raw_psychopy.md` |
| `data/raw/calibration/et_run_sheet.tsv` | `codebooks/calibration_run_sheet.md` |
| `data/raw/rater/ra_scoring_sheet_scored.xlsx`, `scoring/ra_scoring_sheet.xlsx`, `scoring/ra_scoring_key.csv`, `data/derived/rater_disagreements.csv`, `data/derived/rater_agreement.rds` | `codebooks/rater_scoring.md` |
| `stimuli/sentences.tsv` | `codebooks/sentences.md` |
| `stimuli/answer_key.csv` | `codebooks/answer_key.md` |
| `data/derived/preq_scored_items.csv`, `data/derived/preq_scored_participants.csv` | `codebooks/preq_scored.md` |
| `data/derived/test_scored_items.csv`, `data/derived/test_scored_topics.csv` | `codebooks/test_scored.md` |
| `data/derived/et_measures.tsv` | `codebooks/derived_et_measures.md` |
| `data/derived/fixations.tsv` | `codebooks/derived_fixations.md` |
| `data/derived/sentence_regions.tsv` | `codebooks/derived_sentence_regions.md` |
| `data/derived/manuscript_inputs.rds` | `codebooks/manuscript_inputs.md` |
| `analysis/results_*.rds` | `codebooks/analysis_results.md` |
| `power/pilot_reading1.csv` | `codebooks/pilot_reading.md` |
| R and package versions | `codebooks/r_package_versions.csv` |

---

## Key decisions (details in the reports and manuscript)

**Participants and exclusions** (applied in `R/data.R`, in this order, each among those
not already excluded): eye-tracking data were recorded from 161 participants; excluded
were 1 with eye-tracking data for fewer than four pages (P101: no fixations on page 3),
18 who did not meet the preregistered calibration criterion of 0.5° accuracy and
precision or could not be calibrated (see `data/raw/calibration/`; values missing from the
run sheet for P66, P55, P62 and P150 were supplied from the lab records and are entered in
`R/data.R`), and 4 without final-test data (P64, P79, P161, P19012). The final sample is 138
(no prequestions 47, Polio 45, TB 46). P01 was shown an earlier copy of the page-2 image; sentence
regions were added to it in Tobii Pro Lab and P01's rows in `data/raw/tobii/fixations.tsv`
are that re-export. The **eye-tracking condition label is authoritative**; disagreeing labels
elsewhere (P60, P93, P159) are explained in the codebooks and corrected in code.

**Scoring.** Responses were scored by a deterministic, rule-based script
(`scripts/scoring_rubric.R`) written by Claude Opus 5.5 (Anthropic, `claude-opus-5-5`); Claude did
not judge individual answers. The rules are in the script and in Appendix A. To check
the scoring, a research assistant blind to condition, test phase and the automated scores
scored all 1,678 non-blank responses (`scripts/make_ra_scoring_sheet.R` writes the blind
sheet; `scripts/rater_agreement.R` compares the scores with the irr package): exact
agreement 97.6%, ICC(2,1) = .99 (per question: Appendix Table A2).

**Eye-movement measures** (`scripts/derive_et_measures.R`). Fixations were identified with
Tobii Pro Lab's I-VT filter (settings in the manuscript). Fixations shorter than 80 ms or
longer than 1,000 ms are discarded first. Target sentences that were never fixated are
missing (not 0) in all analyses. Tobii Pro Lab's sentence measures were replaced because
(a) when a page appears, the eyes land partway down it, which makes Tobii score the
sentences above as already passed; and (b) recorded gaze drifts vertically, mis-assigning
fixations to the neighbouring line. The script rebuilds the page layout, corrects vertical
drift per reader and page (limited to the 0.5° calibration bound), assigns fixations to
sentences, starts reading at the first fixation on sentence 1, and computes the measures
reported in the manuscript (Schotter & Dillon, 2025): total gaze duration, selective
regression-path duration (first-pass reading), re-reading time (after first moving on to
later text) and regressions-in (look-backs); these do not overlap. It also keeps the
preregistered first-pass duration, which was not analysed because it was bimodal.
All durations are analysed per word.

**Models** (brms, Stan via cmdstanr). Each sentence or question is coded by its status for
the reader (prequestioned, non-prequestioned, no-prequestion); the preregistered specific effect
is prequestioned − no-prequestion and the general effect non-prequestioned − no-prequestion (pooled
models, Status + Topic). The preregistered Group × Topic models break these down by topic
(Polio − TB within each group, described; the interaction contrast, tested). Families:
total gaze duration and selective regression-path duration, ex-Gaussian (cogmod; μ and τ);
re-reading time (sentences re-read), Gamma; regressions-in (look-backs), logistic; final test
and prequestions, beta-binomial (points out of each question's maximum). Every model has the maximal
random-effects structure warranted by the design (by-participant intercepts and Topic slopes;
by-item intercepts and Status or Group slopes). Status, Group and Topic use equal-prior
contrasts (`bayestestR::contr.equalprior_pairs`), so every pairwise comparison has the same
prior. An effect counts as present when its probability of direction (pd) exceeds 95% in the
predicted direction (97.5% for the general effects, which had no directional prediction);
Savage–Dickey Bayes factors describe the strength of the evidence. Prior sensitivity is
checked with priorsense. Deviations from the preregistration are listed in the manuscript.

---

## Privacy

Participant IDs are pseudonymous. 
