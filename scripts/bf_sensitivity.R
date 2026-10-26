# Bayes factor sensitivity to the prior width on the effects
#
# Refits the pooled (Status) and Group x Topic models of the final test and the eye-movement
# measures with every effect prior (class "b", including the tau and hurdle parts) at half
# and twice its width, and recomputes the Savage-Dickey Bayes factors exactly as in the
# analysis documents. The main fits (width 1) are read from analysis/brms_cache/; the
# refits are written to analysis/brms_cache/sensitivity/ and deleted once their Bayes
# factors are saved, because each is several hundred MB.
#
# Output: analysis/results_bf_sensitivity.rds (one row per model, parameter, comparison and
# prior width). Run from the project root: Rscript scripts/bf_sensitivity.R

fit_settings <- list(chains = 4, iter = 11000, warmup = 1000, adapt_delta = 0.95, refit = FALSE)
source(here::here("R", "setup.R"))
source(here::here("R", "bayes_helpers.R"))

sens_dir <- file.path(cache_dir, "sensitivity")
dir.create(sens_dir, showWarnings = FALSE)
out_file <- here::here("analysis", "results_bf_sensitivity.rds")
widths <- c(0.5, 2)

# model name in the results, cached fit, comparison draws, response-scale Bayes factors
specs <- tribble(
  ~model,         ~fit,                              ~design,  ~response_scale,
  "final_test",   "bayes_status_final_test_bb",      "status", FALSE,
  "total_fix",    "bayes_status_total_fix",          "status", FALSE,
  "reread_time",  "bayes_status_reread_after",       "status", FALSE,
  "regressed_in", "bayes_status_regressed_in",       "status", FALSE,
  "first_pass",   "bayes_status_go_past_exg",        "status", FALSE,
  "final_test",   "bayes_cond_topic_final_test_bb",  "topic",  TRUE,
  "total_fix",    "bayes_cond_topic_total_fix",      "topic",  FALSE,
  "reread_time",  "bayes_cond_topic_reread_after",   "topic",  FALSE,
  "regressed_in", "bayes_cond_topic_regressed_in",   "topic",  TRUE,
  "first_pass",   "bayes_cond_topic_go_past_exg",    "topic",  FALSE
)

# Multiply the SD of every normal(0, s) prior on the effects by k
scale_b_priors <- function(pr, k) {
  is_b <- pr$class == "b" & pr$coef == "" & grepl("^normal\\(0, ", pr$prior)
  sd <- as.numeric(sub("^normal\\(0, ([0-9.]+)\\)$", "\\1", pr$prior[is_b]))
  pr$prior[is_b] <- sprintf("normal(0, %s)", sd * k)
  pr
}

done <- if (file.exists(out_file)) readRDS(out_file) else tibble()

for (i in seq_len(nrow(specs))) for (k in widths) {
  sp <- specs[i, ]
  if (nrow(done) && any(done$fit == sp$fit & done$width == k)) next
  message(Sys.time(), "  ", sp$fit, "  width x", k)
  m0 <- readRDS(file.path(cache_dir, paste0(sp$fit, ".rds")))
  name <- sprintf("%s_w%s", sp$fit, k)
  m <- update(m0, prior = scale_b_priors(m0$prior, k),
              chains = fit_settings$chains, iter = fit_settings$iter,
              warmup = fit_settings$warmup,
              control = list(adapt_delta = fit_settings$adapt_delta),
              cores = fit_settings$chains, threads = threading(2), init = 0, seed = 2026,
              file = file.path(sens_dir, name), file_refit = "on_change")
  rm(m0); gc()
  draws_fun <- if (sp$design == "topic") topic_draws else contrast_draws
  res <- bf_model(m, sp$model, draws_fun, response_scale = sp$response_scale) |>
    mutate(BF10 = exp(log_BF), BF01 = 1 / BF10, width = k, fit = sp$fit, design = sp$design,
           max_rhat = max(rhat(m), na.rm = TRUE),
           divergences = sum(subset(nuts_params(m), Parameter == "divergent__")$Value))
  done <- bind_rows(done, res)
  saveRDS(done, out_file)
  unlink(list.files(sens_dir, paste0("^", name), full.names = TRUE))
  rm(m); gc()
}
message(Sys.time(), "  done: ", out_file)
