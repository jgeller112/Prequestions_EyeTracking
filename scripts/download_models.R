# Download the fitted Bayesian models from Zenodo
#
# The fits are archived at https://doi.org/10.5281/zenodo.23985342 as split .qs2 parts
# (<name>.qs2.part001, ...; written by scripts/export_brms_cache.R). This script downloads
# every part into models/, skipping parts that are already there and intact, and checks
# each file against Zenodo's MD5 checksum. The analysis documents then restore the fits
# from models/ automatically (restore_fits() in R/bayes_helpers.R), so no model is refit.
#
# Run from the project root before targets::tar_make():
#   Rscript scripts/download_models.R
# About 3.1 GB.

record_id <- "23985342"
model_dir <- here::here("models")
dir.create(model_dir, showWarnings = FALSE)
options(timeout = max(3600, getOption("timeout")))

record <- jsonlite::fromJSON(sprintf("https://zenodo.org/api/records/%s", record_id))
files <- record$files
files <- files[grepl("[.]qs2[.]part[0-9]+$", files$key), ]
message(sprintf("Zenodo record %s: %d model parts, %.1f GB", record_id, nrow(files),
                sum(files$size) / 1e9))

md5_ok <- function(path, checksum) {
  file.exists(path) && unname(tools::md5sum(path)) == sub("^md5:", "", checksum)
}

for (i in seq_len(nrow(files))) {
  dest <- file.path(model_dir, files$key[i])
  if (md5_ok(dest, files$checksum[i])) next
  message(sprintf("[%d/%d] %s", i, nrow(files), files$key[i]))
  download.file(files$links$self[i], dest, mode = "wb", quiet = TRUE)
  if (!md5_ok(dest, files$checksum[i])) {
    unlink(dest)
    stop("Checksum mismatch for ", files$key[i], "; rerun the script to retry.")
  }
}
message("All model parts are in ", model_dir,
        ". Render the analysis (targets::tar_make()) to restore and use them.")
