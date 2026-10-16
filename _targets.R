# =====================================================================================
# Reproducible pipeline for "Where Do Prequestions Direct Attention? An Eye-Tracking
# Study of the Prequestion Effect" (targets, https://docs.ropensci.org/targets/)
# =====================================================================================
#
# Run everything:        targets::tar_make()
# See what is outdated:  targets::tar_outdated()
# Draw the pipeline:     targets::tar_visnetwork()
#
# Each step runs one of the project's scripts or Quarto documents, unchanged, in a fresh
# R session. targets records a hash of every input file and script; when one changes,
# only the steps downstream of it are rerun. Every step returns the paths of the files
# it writes (format = "file"), so the outputs are tracked too.
#
# Steps (see README.md for details and the codebooks/ folder for every file):
#   1. Score the prequestions       grade_prequestions.R -> data/derived/preq_scored_*.csv
#   2. Score the final test         grade_test.R         -> data/derived/test_scored_*.csv
#   3. Derive eye-movement measures derive_et_measures.R -> data/derived/*.tsv
#   4. Analysis reports, one per domain (shared code: R/setup.R, R/data.R)
#        analysis/prequestions.qmd -> analysis/prequestions.html
#        analysis/final_test.qmd   -> analysis/final_test.html
#        analysis/eye_tracking.qmd -> analysis/eye_tracking.html
#   5. Manuscript                   manuscript/manuscript.qmd -> manuscript/manuscript.pdf, .docx
# =====================================================================================

library(targets)
library(tarchetypes)

# The scripts load their own packages, so no packages are attached here.
tar_option_set(packages = character())

# Run an R script in a fresh R session (working directory = project root) and return
# the files it writes. `...` are upstream targets, listed only so that targets knows
# this step depends on them.
run_script <- function(script, outputs, ...) {
  callr::rscript(script, wd = ".", show = FALSE)
  missing <- outputs[!file.exists(outputs)]
  if (length(missing) > 0) stop(script, " did not write: ", paste(missing, collapse = ", "))
  outputs
}

# Render a Quarto document (in a fresh R session, via the Quarto CLI) and return the
# files it writes. `...`: upstream targets (dependencies only), as in run_script().
# `params`: Quarto execute parameters; `output_file`: optional output name (both must be
# given by name, after the dependencies).
render_quarto <- function(input, outputs, ..., params = NULL, output_file = NULL) {
  quarto::quarto_render(input, execute_params = params, output_file = output_file,
                        quiet = FALSE)
  missing <- outputs[!file.exists(outputs)]
  if (length(missing) > 0) stop(input, " did not write: ", paste(missing, collapse = ", "))
  outputs
}

list(
  # ---- Raw inputs (tracked by content) -----------------------------------------------
  # PsychoPy output, one file per session; re-listed on every run, so added or removed
  # files are noticed
  tar_files_input(raw_preq_files,
                  list.files("data/raw/psychopy/prequestions", pattern = "[.]csv$", full.names = TRUE)),
  tar_files_input(raw_test_files,
                  list.files("data/raw/psychopy/final_test", pattern = "[.]csv$", full.names = TRUE)),
  tar_target(raw_answer_key, "stimuli/answer_key.csv", format = "file"),
  # Tobii Pro Lab fixation export (all recorded participants; the starting raw data)
  # the text: page, order, text, type and word count of each sentence
  tar_target(raw_sentences, "stimuli/sentences.tsv", format = "file"),
  tar_target(raw_tobii_fixations, "data/raw/tobii/fixations.tsv", format = "file"),
  # Full-resolution screenshots of the four text pages
  tar_target(raw_page_images, sprintf("stimuli/pages/page%d_full.png", 1:4),
             format = "file"),
  # Lab run sheet with calibration accuracy and precision (participant names removed)
  tar_target(raw_calibration, "data/raw/calibration/et_run_sheet.tsv", format = "file"),

  # ---- Code (tracked by content) -----------------------------------------------------
  tar_target(code_scoring_rubric, "scripts/scoring_rubric.R", format = "file"),
  tar_target(code_grade_prequestions, "scripts/grade_prequestions.R", format = "file"),
  tar_target(code_grade_test, "scripts/grade_test.R", format = "file"),
  tar_target(code_derive_et, "scripts/derive_et_measures.R", format = "file"),
  # shared analysis code and the three analysis documents
  tar_target(code_analysis_shared, c("R/setup.R", "R/data.R"), format = "file"),
  tar_target(doc_prequestions, "analysis/prequestions.qmd", format = "file"),
  tar_target(doc_final_test, "analysis/final_test.qmd", format = "file"),
  tar_target(doc_eye_tracking, "analysis/eye_tracking.qmd", format = "file"),
  tar_target(doc_manuscript, "manuscript/manuscript.qmd", format = "file"),
  # Manuscript support files: references, citation style, APA Quarto extension
  tar_target(doc_manuscript_support,
             c("manuscript/references.bib", "manuscript/apa.csl",
               list.files("manuscript/_extensions", recursive = TRUE, full.names = TRUE)),
             format = "file"),

  # ---- 1. Score the prequestions -----------------------------------------------------
  tar_target(preq_scored,
             run_script(code_grade_prequestions,
                        c("data/derived/preq_scored_items.csv", "data/derived/preq_scored_participants.csv"),
                        raw_preq_files, raw_answer_key, raw_tobii_fixations,
                        code_scoring_rubric),
             format = "file"),

  # ---- 2. Score the final test -------------------------------------------------------
  tar_target(test_scored,
             run_script(code_grade_test,
                        c("data/derived/test_scored_items.csv", "data/derived/test_scored_topics.csv"),
                        raw_test_files, raw_answer_key, raw_tobii_fixations,
                        code_scoring_rubric),
             format = "file"),

  # ---- 3. Derive the eye-movement measures -------------------------------------------
  tar_target(et_derived,
             run_script(code_derive_et,
                        c("data/derived/et_measures.tsv", "data/derived/fixations.tsv",
                          "data/derived/sentence_regions.tsv"),
                        raw_tobii_fixations, raw_sentences, raw_page_images),
             format = "file"),

  # ---- 4. Analysis reports ---------------------------------------------------------
  tar_target(report_prequestions,
             render_quarto(doc_prequestions, "analysis/prequestions.html",
                           code_analysis_shared, preq_scored, test_scored, et_derived,
                           raw_calibration, raw_sentences),
             format = "file"),
  tar_target(report_final_test,
             render_quarto(doc_final_test, "analysis/final_test.html",
                           code_analysis_shared, preq_scored, test_scored, et_derived,
                           raw_calibration, raw_sentences),
             format = "file"),
  tar_target(report_eye_tracking,
             render_quarto(doc_eye_tracking, "analysis/eye_tracking.html",
                           code_analysis_shared, preq_scored, test_scored, et_derived,
                           raw_calibration, raw_answer_key, raw_page_images,
                           raw_sentences),
             format = "file"),

  # ---- 5. Manuscript (re-runs the analysis code itself; see its setup chunk) ---------
  tar_target(manuscript,
             render_quarto(doc_manuscript,
                           c("manuscript/manuscript.pdf", "manuscript/manuscript.docx"),
                           code_analysis_shared, doc_prequestions, doc_final_test,
                           doc_eye_tracking, doc_manuscript_support, preq_scored,
                           test_scored, et_derived, raw_calibration, raw_answer_key,
                           raw_page_images),
             format = "file")
)
