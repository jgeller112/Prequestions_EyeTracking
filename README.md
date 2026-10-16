# Where Do Prequestions Direct Attention? An Eye-Tracking Study of the Prequestion Effect

Jason Geller (Boston College) and Shana K. Carpenter (Oregon State University).
Preregistration: <https://osf.io/8env4>.

Participants read a four-page text about the Gates Foundation's efforts against polio and
tuberculosis (TB) while their eye movements were recorded. Before reading, they answered
five prequestions about polio, five about TB, or none (Control). Afterwards, everyone
answered all ten questions. Each question's answer is in one target sentence, so every
target sentence is *prequestioned* for one group and *non-prequestioned* for another.

This repository contains the raw data, all code, and the manuscript. Everything — scoring,
eye-movement measures, statistical analyses, figures, and the manuscript itself — is
produced from the raw data by one pipeline.

---

## Reproducing everything

### Requirements

| Software | Version used | Notes |
|---|---|---|
| R | 4.6.1 | |
| Quarto | 1.10.18 | <https://quarto.org>; Typst (for the PDF) is bundled with Quarto |
| R packages | see `codebooks/r_package_versions.csv` | install with `install.packages()` |

Install the R packages:

```r
install.packages(c("tidyverse", "easystats", "lme4", "glmmTMB", "gamlss", "car",
                   "modelbased", "marginaleffects", "parameters", "performance",
                   "insight", "cocor", "patchwork", "png", "knitr", "xfun", "quarto",
                   "callr", "targets", "tarchetypes", "lmerTest", "janitor",
                   "reformulas", "scales", "MASS"))
```

If glmmTMB warns that it was "built with TMB package version …", reinstall it from source
(`install.packages("glmmTMB", type = "source")`); results are unaffected but the warning
recurs otherwise.

### Run the pipeline

Open R in this folder and run:

```r
targets::tar_make()        # runs every step that is out of date (about 5-10 min from scratch)
targets::tar_visnetwork()  # draws the pipeline (needs the visNetwork package)
targets::tar_outdated()    # lists the steps that would rerun
```

The pipeline is defined in `_targets.R`. It tracks every raw data file and script by
content: after a change, only the affected steps rerun. Its bookkeeping is stored in
`_targets/` (safe to delete; the next run starts from scratch).

Steps and outputs:

| Step | Code | Reads | Writes |
|---|---|---|---|
| 1. Score prequestions | `scripts/grade_prequestions.R` (+ `scripts/scoring_rubric.R`) | `data/raw/psychopy/prequestions/*.csv`, `stimuli/answer_key.csv`, `data/raw/tobii/fixations.tsv` (eye-tracking IDs) | `data/derived/preq_scored_items.csv`, `data/derived/preq_scored_participants.csv` |
| 2. Score final test | `scripts/grade_test.R` (+ `scripts/scoring_rubric.R`) | `data/raw/psychopy/final_test/*.csv`, `stimuli/answer_key.csv`, `data/raw/tobii/fixations.tsv` (eye-tracking IDs) | `data/derived/test_scored_items.csv`, `data/derived/test_scored_topics.csv` |
| 3. Eye-movement measures | `scripts/derive_et_measures.R` | `data/raw/tobii/fixations.tsv`, `stimuli/sentences.tsv`, `stimuli/pages/page*_full.png` | `data/derived/et_measures.tsv`, `data/derived/fixations.tsv`, `data/derived/sentence_regions.tsv`, `data/derived/et_checks/*.png` |
| 4. Analysis reports | `R/setup.R`, `R/data.R` (shared), then `analysis/prequestions.qmd`, `analysis/final_test.qmd`, `analysis/eye_tracking.qmd` | outputs of 1–3, `data/raw/calibration/et_run_sheet.tsv` | `analysis/prequestions.html`, `analysis/final_test.html`, `analysis/eye_tracking.html` |
| 5. Manuscript | `manuscript/manuscript.qmd` (APA style via `manuscript/_extensions/wjschne/apaquarto`, `apa.csl`, `references.bib`) | as 4 | `manuscript/manuscript.pdf`, `manuscript/manuscript.docx`, `manuscript/packages.bib` |

Each step can also be run on its own, from this folder: `Rscript scripts/grade_test.R`,
`quarto render analysis/eye_tracking.qmd`, `quarto render manuscript/manuscript.qmd`, and so on
(in the order above).

The manuscript does not copy numbers from the reports: its setup chunk runs `R/setup.R`,
`R/data.R` and the code of the three analysis documents, and every number in the text is
computed. A `claims-check` chunk stops the render if a statement in the text (e.g., "was
significant") no longer matches the results.

---

## Folder structure

```
_targets.R                     pipeline definition (targets)
README.md                      this file
codebooks/                     one codebook per data file (see below)

data/
  raw/                         RAW data: never edited (exclusions and corrections are made in code)
    tobii/fixations.tsv          Tobii Pro Lab fixation export, all 160 recorded participants
                                 (exported as PreQ_fix_all.tsv)
    tobii/unused/PreQ_fix.tsv    earlier fixation export (143 participants; superseded, not read)
    psychopy/prequestions/       PsychoPy prequestion sessions (.csv + .log.gz)
    psychopy/final_test/         PsychoPy final-test sessions (.csv + .log.gz)
    calibration/                 lab run sheet with calibration results (names removed) + README
  derived/                     DERIVED: written by the pipeline (safe to delete; tar_make() rebuilds it)
    preq_scored_*.csv            step 1
    test_scored_*.csv            step 2
    et_measures.tsv, fixations.tsv, sentence_regions.tsv   step 3
    et_checks/                   step 3: before/after drift-correction plots

stimuli/
  sentences.tsv                the text: page, order, type, word count and text of every sentence
  answer_key.csv               the ten questions, answers and points (was prequest_answers.csv)
  pages/                       screenshots of the four text pages (see its README)
  Prequestion_reading_v2.docx  the text as written
  tobii_images/                full-resolution page images exported by Tobii Pro Lab (source of pages/)
  reference/                   earlier target-sentence lists (reference only, not read)

scripts/
  scoring_rubric.R             scoring rules + helpers for steps 1-2 (ID matching, corrections)
  grade_prequestions.R         step 1
  grade_test.R                 step 2
  derive_et_measures.R         step 3 (fully commented; settings, e.g. fixation limits, near the top)
R/
  setup.R                      shared: packages, colours, model and text helpers
  data.R                       shared: import, exclusions, calibration, analysis data sets
analysis/                      step 4: one report per domain (code + explanations)
  prequestions.qmd             prequestion scores; accuracy by condition
  final_test.qmd               final test (preregistered)
  eye_tracking.qmd             all eye-movement analyses, mediation, correlations
manuscript/                    step 5: the paper
  manuscript.qmd               source (its R code runs from the project root)
  manuscript.pdf, .docx        rendered paper
  references.bib, apa.csl      literature references and citation style
  packages.bib                 R package references, written at render time
  _extensions/                 APA formatting extension (apaquarto)
```

**RAW files are never edited.** All exclusions, ID matching, and label corrections are
made in code, with comments explaining each one.

## Codebooks

| File | Codebook |
|---|---|
| `data/raw/tobii/fixations.tsv` (and the earlier `data/raw/tobii/unused/PreQ_fix.tsv`) | `codebooks/raw_tobii_fixations.md` |
| `data/raw/psychopy/prequestions/*.csv`, `data/raw/psychopy/final_test/*.csv` | `codebooks/raw_psychopy.md` |
| `stimuli/answer_key.csv` | `codebooks/answer_key.md` |
| `data/raw/calibration/et_run_sheet.tsv` | `codebooks/calibration_run_sheet.md` |
| `data/derived/preq_scored_items.csv`, `data/derived/preq_scored_participants.csv` | `codebooks/preq_scored.md` |
| `data/derived/test_scored_items.csv`, `data/derived/test_scored_topics.csv` | `codebooks/test_scored.md` |
| `data/derived/et_measures.tsv` | `codebooks/derived_et_measures.md` |
| `data/derived/fixations.tsv` | `codebooks/derived_fixations.md` |
| `data/derived/sentence_regions.tsv` | `codebooks/derived_sentence_regions.md` |
| R package versions | `codebooks/r_package_versions.csv` |

---

## Key decisions (details in the report and manuscript)

**Participants and exclusions** (applied in `R/data.R`, in this order, each among those
not already excluded): eye-tracking data were recorded from 160 participants; excluded
were 1 with eye-tracking data for fewer than four pages (P101: no fixations on page 3),
18 who did not meet the preregistered calibration criterion of 0.5° accuracy and
precision or could not be calibrated (see `data/raw/calibration/`; P66's values, missing from
the run sheet, are supplied in `R/data.R`), and 4 without final-test data (P64, P79, P161,
P19012). P01 was shown an earlier copy of the page-2 image; sentence regions were added to it
in Tobii Pro Lab and P01's rows in `data/raw/tobii/fixations.tsv` are that re-export. The **eye-tracking condition label is
authoritative**; disagreeing labels elsewhere (P60, P93, P159) are explained in the
codebooks and corrected in code.

**Scoring.** Responses were scored by a deterministic, rule-based script
(`scripts/scoring_rubric.R`) written by Claude Opus 5.5 (Anthropic, `claude-opus-5-5`); Claude did
not judge individual answers. The rules are in the script and in Appendix A.

**Eye-movement measures** (`scripts/derive_et_measures.R`). Fixations shorter than 80 ms or
longer than 1,000 ms are discarded first. Target sentences that were never fixated are
missing (not 0) in all analyses. Tobii Pro Lab's sentence measures were
replaced because (a) when a page appears, the eyes land partway down it, which makes
Tobii score the sentences above as already passed; and (b) recorded gaze drifts
vertically, mis-assigning fixations to the neighbouring line. The script rebuilds the
page layout, corrects vertical drift per reader and page (limited to the 0.5° calibration
bound), assigns fixations to sentences and words, starts reading at the first fixation on
sentence 1, and computes the measures. All durations are analysed per word.

**Models.** Total gaze duration: preregistered ex-Gaussian model (gamlss). First-pass
duration: Gamma GLMM (glmmTMB). Re-reading: hurdle model (logistic for whether re-read,
Gamma for duration). First-pass and second-pass regressions: logistic GLMMs. Final test:
binomial GLMM. Random effects start maximal and are reduced by likelihood-ratio tests
(Matuschek et al., 2017); every test is listed in the report. Preregistered directional
contrasts are one-tailed (reported with 90% CIs and both one- and two-tailed *p*);
everything else is two-tailed. Deviations from the preregistration are listed in the
manuscript.

---

## Privacy

Participant IDs are pseudonymous. The original calibration run sheet contained
participant names; the copy in `data/raw/calibration/` has them removed and was checked
against every name in the original. Do not add the original sheet to this repository.
