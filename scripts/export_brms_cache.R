# Export the fitted Bayesian models for GitHub
#
# The fits in analysis/brms_cache/ are too large to commit as they are, so this script
#   1. saves each fit used by the analysis documents as models/<name>.qs2, and
#   2. splits it into parts smaller than 90 MB (models/<name>.qs2.part001, ...) with
#      scripts/split_qs2.R, so that the parts can be committed.
# Only the parts are tracked by git (the whole .qs2 files are ignored). R/bayes_helpers.R
# recombines the parts and restores a fit into analysis/brms_cache/ when it is missing, so
# the analysis documents reuse the shared fits instead of refitting them.
#
# The prior-only models (*_prior.rds) are not exported: the analysis documents regenerate
# them when they are missing (a few minutes per model).
#
# Run from the project root after the fits have changed: Rscript scripts/export_brms_cache.R

library(qs2)
source(here::here("scripts", "split_qs2.R"))

cache_dir <- here::here("analysis", "brms_cache")
model_dir <- here::here("models")

# Fits used by the analysis documents (prequestions.qmd, final_test.qmd, eye_tracking.qmd)
fits <- c(
  # eye movements: status models and Group x Topic models
  "bayes_status_total_fix", "bayes_status_reread_after", "bayes_status_regressed_in",
  "bayes_status_go_past_exg",
  "bayes_cond_topic_total_fix", "bayes_cond_topic_reread_after",
  "bayes_cond_topic_regressed_in", "bayes_cond_topic_go_past_exg",
  # final test (beta-binomial), and the binomial model it was compared with
  "bayes_status_final_test_bb", "bayes_cond_topic_final_test_bb",
  "bayes_status_final_test_binomial",
  # prequestions (beta-binomial)
  "bayes_preq_betabin"
)

missing <- fits[!file.exists(file.path(cache_dir, paste0(fits, ".rds")))]
if (length(missing) > 0) stop("Not in ", cache_dir, ": ", paste(missing, collapse = ", "),
                              ". Render the analysis documents first (targets::tar_make()).")

dir.create(model_dir, showWarnings = FALSE)
for (f in fits) {
  out <- file.path(model_dir, paste0(f, ".qs2"))
  # remove the parts of an earlier export of this fit
  unlink(list.files(model_dir, pattern = paste0("^", f, "[.]qs2[.]part[0-9]+$"), full.names = TRUE))
  qs_save(readRDS(file.path(cache_dir, paste0(f, ".rds"))), out, nthreads = 4)
  split_qs2_file(out, max_size_mb = 90)
  # a fit smaller than 90 MB is not split: keep it as a single part
  if (!file.exists(paste0(out, ".part001"))) file.copy(out, paste0(out, ".part001"))
  unlink(out)
  message("Exported ", f)
}
parts <- list.files(model_dir, pattern = "[.]qs2[.]part[0-9]+$", full.names = TRUE)
message(sprintf("%d parts, %.1f GB in %s/", length(parts), sum(file.size(parts)) / 1e9, model_dir))
