# Shared code for the Bayesian analysis documents (analysis/prequestions.qmd,
# analysis/final_test.qmd, analysis/eye_tracking.qmd): priors, model fitting with a cache,
# equal-prior contrasts, comparisons and Savage-Dickey Bayes factors (modelbased +
# bayestestR), means, diagnostics, prior sensitivity, and the results files.
#
# Requires R/setup.R and R/data.R, and `fit_settings` (chains, iter, warmup, adapt_delta,
# refit), set in each document's setup chunk from its YAML params.

library(here)
library(brms)
library(cogmod)       # cogmod_exgaussian()
library(bayestestR)
library(modelbased)

options(brms.backend = "cmdstanr", mc.cores = parallel::detectCores())

cache_dir <- here("analysis", "brms_cache")
dir.create(cache_dir, showWarnings = FALSE)

# Shared fits: models/<name>.qs2.part001, ... (committed; written by
# scripts/export_brms_cache.R). A fit missing from the cache is recombined from its parts
# and restored as analysis/brms_cache/<name>.rds, so that brms reuses it instead of refitting.
source(here("scripts", "split_qs2.R"))
restore_fits <- function(model_dir = here("models")) {
  parts <- list.files(model_dir, pattern = "[.]qs2[.]part001$", full.names = TRUE)
  for (p in parts) {
    qs2_file <- sub("[.]part001$", "", p)
    rds <- file.path(cache_dir, sub("[.]qs2$", ".rds", basename(qs2_file)))
    if (file.exists(rds)) next
    combine_qs2_file(qs2_file)
    saveRDS(qs2::qs_read(qs2_file, nthreads = 4), rds)
    unlink(qs2_file)
    message("Restored ", basename(rds), " from ", model_dir)
  }
}
restore_fits()
refit_mode <- if (isTRUE(fit_settings$refit)) "always" else "on_change"
has_priorsense <- requireNamespace("priorsense", quietly = TRUE)

# ---- Coding ---------------------------------------------------------------------------
# Equal-prior contrasts (bayestestR::contr.equalprior_pairs): a normal(0, s) prior on the
# coefficients gives the same normal(0, s) prior on every pairwise difference between levels
equal_prior <- function(d) {
  contrasts(d$status) <- contr.equalprior_pairs
  contrasts(d$topic)  <- contr.equalprior_pairs
  d
}
# Group x Topic models: Group (condition) ordered Polio, TB, Control
cond_coding <- function(d) {
  d$condition <- factor(d$condition, levels = c("Polio", "TB", "Control"))
  contrasts(d$condition) <- contr.equalprior_pairs
  d
}
# status of each Group x Topic cell (for figures)
add_status <- \(d) mutate(d, status = factor(case_when(
  condition == "Control" ~ "Control",
  as.character(condition) == as.character(topic) ~ "Prequestioned",
  TRUE ~ "Non-prequestioned"), levels = c("Prequestioned", "Non-prequestioned", "Control")))

# ---- Priors (s = prior SD of every pairwise difference, link scale) --------------------
s_log   <- 0.5     # Gamma durations (log scale) and ex-Gaussian tau (softplus scale)
s_logit <- 1.5     # binary measures, beta-binomial (log-odds)
s_mu    <- 0.1     # ex-Gaussian mu (s/word)

pr_gamma <- c(prior_string(sprintf("normal(0, %s)", s_log), class = "b"),
              prior(normal(-1.5, 1), class = "Intercept"),     # log(s/word): about 0.2 s/word
              prior(student_t(3, 0, 0.5), class = "sd"),
              prior(gamma(2, 0.5), class = "shape"),
              prior(lkj(2), class = "cor"))
pr_logit <- c(prior_string(sprintf("normal(0, %s)", s_logit), class = "b"),
              prior(normal(0, 1.5), class = "Intercept"),
              prior(student_t(3, 0, 1), class = "sd"),
              prior(lkj(2), class = "cor"))
pr_exg <- c(prior_string(sprintf("normal(0, %s)", s_mu), class = "b"),
            prior_string(sprintf("normal(0, %s)", s_log), class = "b", dpar = "tau"),
            prior(normal(0.2, 0.2), class = "Intercept"),                  # s/word
            # softplus scale: softplus(-2.5) = 0.08 s/word; for values this small,
            # softplus(x) is close to exp(x), so these behave like log-scale priors
            prior(normal(-2.5, 1), class = "Intercept", dpar = "sigma"),
            prior(normal(-2.5, 1), class = "Intercept", dpar = "tau"),
            prior(student_t(3, 0, 0.1), class = "sd"),
            prior(student_t(3, 0, 0.5), class = "sd", dpar = "sigma"),
            prior(student_t(3, 0, 0.5), class = "sd", dpar = "tau"),
            prior(lkj(2), class = "cor"))

# Maximal random-effects structures warranted by the design. Topic varies within
# participants; Status (and Group) vary within items, because every sentence and question
# was prequestioned for one group, non-prequestioned for another and read by Control.
# Within a participant Status is fixed by Topic, so there is no by-participant Status slope.
re_et        <- "(1 + topic | participant) + (1 + status | sentence)"
re_test      <- "(1 + topic | participant) + (1 + status | question)"
re_et_cond   <- "(1 + topic | participant) + (1 + condition | sentence)"
re_test_cond <- "(1 + topic | participant) + (1 + condition | question)"

# ---- Fitting (cached in analysis/brms_cache/) ------------------------------------------
fit_brm <- function(formula, data, family, prior, name, ...) {
  brm(formula, data = data, family = family, prior = prior,
      chains = fit_settings$chains, iter = fit_settings$iter, warmup = fit_settings$warmup,
      control = list(adapt_delta = fit_settings$adapt_delta),
      cores = fit_settings$chains, threads = threading(2),   # within-chain parallelisation
      init = 0, seed = 2026, save_pars = save_pars(all = TRUE),
      file = file.path(cache_dir, name), file_refit = refit_mode, ...)
}

# Points earned on a question out of its maximum (1-4 points): beta-binomial (logit link
# for the probability of earning a point, mu; phi = overdispersion, because a student
# tends to know all or none of a question's elements). Same equal-prior normal(0, s_logit)
# on the coefficients as the binary models. `cor = FALSE` for random intercepts only.
pr_betabin <- function(cor = TRUE) {
  c(prior_string(sprintf("normal(0, %s)", s_logit), class = "b"),
    prior(normal(0, 1.5), class = "Intercept"),
    prior(student_t(3, 0, 1), class = "sd"),
    prior(exponential(0.1), class = "phi"),
    if (cor) prior(lkj(2), class = "cor"))
}
fit_betabin <- function(rhs, name, data, re = re_test, cor = TRUE, ...) {
  fit_brm(as.formula(paste("points | trials(max_points) ~", rhs, "+", re)), data,
          beta_binomial(), pr_betabin(cor), name, ...)
}

# The same model sampled from its priors only (for the Bayes factors), cached next to the
# fit and resampled only when the fit is newer than it, or when refit is true
prior_model <- function(m) {
  if (is.null(m$file)) return(unupdate(m))
  fp <- sub("[.]rds$", "_prior.rds", m$file)
  if (file.exists(fp) && refit_mode != "always" && file.mtime(fp) > file.mtime(m$file)) {
    return(readRDS(fp))
  }
  mp <- unupdate(m)
  saveRDS(mp, fp)
  mp
}

# ---- What is reported for each model --------------------------------------------------
# label = c(est = what the estimates predict, bf = what the Bayes factor compares);
# NA = the expected response (modelbased default). "mu" is each model's main quantity.
par_spec <- function(nm) switch(nm,
  total_fix   = list(mu = c(est = "mu", bf = "link"), tau = c(est = "tau", bf = "tau")),
  first_pass  = list(mu = c(est = "mu", bf = "link"), tau = c(est = "tau", bf = "tau")),
  # beta-binomial: estimates on the probability of earning a point (mu), i.e. the expected
  # proportion of a question's points, rather than the expected number of points
  final_test   = list(mu = c(est = "mu", bf = "link")),
  prequestions = list(mu = c(est = "mu", bf = "link")),
  list(mu = c(est = NA, bf = "link")))
pp <- \(x) if (is.na(x)) NULL else unname(x)

# ---- Pooled models: each status vs. Control ---------------------------------------------
# Draws of the comparisons (modelbased), one column per comparison
contrast_draws <- function(m, predict, ...) {
  x <- estimate_contrasts(m, contrast = "status", comparison = "revpairwise",
                          predict = predict, backend = "marginaleffects", estimate = "average",
                          centrality = "mean", keep_iterations = TRUE, ...) |>
    as.data.frame() |>
    filter(Level2 == "Control")
  setNames(as.data.frame(t(as.matrix(x[, grep("^iter_", names(x))]))),
           paste(x$Level1, "-", x$Level2))
}

# Savage-Dickey Bayes factor for each comparison (bayestestR); `draws_fun` gives the
# comparison draws for a model (contrast_draws or topic_draws). `response_scale`: compute
# the Bayes factor on the scale of the estimates (the response scale) instead of the link
# scale. Used for the Group x Topic comparisons of bounded outcomes (look-backs, final
# test), whose Polio and TB items differ: for an outcome near 0 or 1 for some items, the
# same comparison is much less precise in log-odds than in probability, so a link-scale
# Bayes factor can contradict the response-scale estimate and pd.
bf_model <- function(m, nm, draws_fun = contrast_draws, response_scale = FALSE) {
  m_prior <- prior_model(m)
  imap(par_spec(nm), \(sp, lab) {
    pr <- pp(if (response_scale) sp[["est"]] else sp[["bf"]])
    draws <- \(mm) if (isTRUE(sp["re"] == "NA")) draws_fun(mm, pr, re_formula = NA)
                    else draws_fun(mm, pr)
    bayesfactor_parameters(draws(m), prior = draws(m_prior), null = 0) |>
      as.data.frame() |>
      rename(comparison = Parameter) |>
      mutate(model = nm, parameter = lab)
  }) |> bind_rows()
}
bf_table <- function(models, draws_fun = contrast_draws, response_scale = character()) {
  imap(models, \(m, nm) bf_model(m, nm, draws_fun, response_scale = nm %in% response_scale) |>
         mutate(scale = if (nm %in% response_scale) "response" else "link")) |>
    bind_rows() |>
    mutate(BF10 = exp(log_BF), BF01 = 1 / BF10)
}

# Response-scale comparisons with Control, averaged over the sample, with pd
contrasts_by <- function(models) {
  imap(models, \(m, nm) imap(par_spec(nm), \(sp, lab)
    estimate_contrasts(m, contrast = "status", comparison = "revpairwise",
                       backend = "marginaleffects", estimate = "average", centrality = "mean",
                       predict = pp(sp[["est"]])) |>
      as.data.frame() |>
      filter(Level2 == "Control") |>
      mutate(model = nm, parameter = lab)) |>
      bind_rows()) |>
    bind_rows()
}

# ---- Group x Topic models: Polio - TB within each group, and the interaction ----------
# The interaction contrast is the Polio group's Polio - TB difference minus the TB group's
topic_draws <- function(m, predict = NULL, ...) {
  x <- estimate_contrasts(m, contrast = "topic", by = "condition", comparison = "revpairwise",
                          predict = predict, backend = "marginaleffects", estimate = "average",
                          centrality = "mean", keep_iterations = TRUE, ...) |>
    as.data.frame()
  sgn <- if_else(x$Level1 == "Polio", 1, -1)          # always Polio - TB
  d <- as.data.frame(t(sgn * as.matrix(x[, grep("^iter_", names(x))])))
  names(d) <- paste0("Polio - TB (", x$condition, " group)")
  d[["Interaction (Polio group - TB group)"]] <- d[["Polio - TB (Polio group)"]] - d[["Polio - TB (TB group)"]]
  d
}
# Response-scale estimates with 95% CrI and pd, from the same comparisons
topic_estimates <- function(models) {
  imap(models, \(m, nm) imap(par_spec(nm), \(sp, lab)
    describe_posterior(topic_draws(m, pp(sp[["est"]])), centrality = "mean", ci = 0.95,
                       test = "pd") |>
      as.data.frame() |>
      transmute(comparison = Parameter, Mean, CI_low, CI_high, pd, model = nm, parameter = lab)) |>
      bind_rows()) |>
    bind_rows()
}

# ---- Means -----------------------------------------------------------------------------
resp_means <- function(m, by, predict = NULL) {
  estimate_means(m, by = by, backend = "marginaleffects", estimate = "average",
                 centrality = "mean", predict = predict) |>
    as.data.frame() |>
    # modelbased names the estimate after what is predicted ("Probability", "Mu", ...)
    rename(any_of(c(Mean = "Probability", Mean = "Mu", Mean = "Tau", Mean = "Hu",
                    Mean = "Expectation", Mean = "Predicted")))
}
means_by <- function(models, by) {
  imap(models, \(m, nm) imap(par_spec(nm), \(sp, lab)
    resp_means(m, by, pp(sp[["est"]])) |> mutate(model = nm, parameter = lab)) |>
      bind_rows()) |>
    bind_rows()
}
# Posterior draws of the means, for the manuscript figures (thinned to 4,000 draws)
mean_draws_by <- function(models, by, n = 4000) {
  one <- function(m, nm, predict = NULL, par = "mu") {
    estimate_means(m, by = by, backend = "marginaleffects", estimate = "average",
                   predict = predict, keep_iterations = n) |>
      as.data.frame() |>
      select(all_of(by), starts_with("iter_")) |>
      pivot_longer(starts_with("iter_"), names_to = "draw", values_to = "value") |>
      mutate(model = nm, parameter = par)
  }
  imap(models, \(m, nm) imap(par_spec(nm), \(sp, lab) one(m, nm, pp(sp[["est"]]), lab)) |>
         bind_rows()) |>
    bind_rows()
}

# ---- Diagnostics, prior sensitivity, posterior predictive checks -----------------------
diag_model <- function(m, nm) {
  np <- nuts_params(m)
  tibble(model = nm,
         divergences = sum(np$Value[np$Parameter == "divergent__"]),
         max_rhat = max(rhat(m), na.rm = TRUE),
         min_ess_bulk = min(posterior::summarise_draws(m, "ess_bulk")$ess_bulk, na.rm = TRUE))
}
diag_table <- \(models) imap(models, diag_model) |> bind_rows()

sens_table <- function(models) {
  if (!has_priorsense) return(NULL)
  imap(models, \(m, nm)
    priorsense::powerscale_sensitivity(m, variable = grep("^b_", variables(m), value = TRUE)) |>
      as.data.frame() |>
      # priorsense marks unflagged coefficients with "-" (prior and likelihood
      # sensitivity both below its 0.05 threshold)
      mutate(diagnosis = if_else(diagnosis == "-", "no issue", diagnosis), model = nm)) |>
    bind_rows()
}

# Posterior predictive check for points out of a maximum: observed vs. predicted share of
# responses at each possible score (proportion of the question's points), with 95%
# intervals over draws
score_freq <- function(yrep_prop, obs_prop) {
  vals <- sort(unique(round(obs_prop, 2)))
  pred <- t(apply(round(yrep_prop, 2), 1, \(r) sapply(vals, \(v) mean(r == v))))
  tibble(score = vals, observed = sapply(vals, \(v) mean(round(obs_prop, 2) == v)),
         predicted = colMeans(pred), lo = apply(pred, 2, quantile, 0.025),
         hi = apply(pred, 2, quantile, 0.975))
}
ppc_scores <- function(m, title, ndraws = 500) {
  d <- m$data
  yrep <- posterior_predict(m, ndraws = ndraws) /
    matrix(d$max_points, ndraws, nrow(d), byrow = TRUE)
  f <- score_freq(yrep, d$points / d$max_points)
  ggplot(f, aes(factor(round(score, 2)))) +
    geom_col(aes(y = observed), fill = "grey75") +
    geom_pointrange(aes(y = predicted, ymin = lo, ymax = hi)) +
    scale_y_continuous(labels = scales::percent) +
    labs(x = "Score (proportion of the question's points)", y = "Share of responses",
         title = title, subtitle = "Bars: observed; points: predicted (95% interval over draws)") +
    theme_minimal(base_size = 10)
}

# ---- Results files ---------------------------------------------------------------------
# modelbased/bayestestR tables carry the model and its data as attributes; keep only the
# table itself, so the results files stay small
plain <- function(x) {
  if (!is.data.frame(x)) return(x)
  d <- as.data.frame(x)
  attributes(d) <- list(names = names(d), row.names = seq_len(nrow(d)), class = "data.frame")
  d[] <- lapply(d, \(col) {
    attributes(col) <- attributes(col)[intersect(names(attributes(col)), c("levels", "class"))]
    col
  })
  d
}
save_results <- function(results, file) {
  results$settings <- c(fit_settings, list(s_log = s_log, s_logit = s_logit, s_mu = s_mu))
  saveRDS(lapply(results, plain), file)
}
