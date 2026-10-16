# =====================================================================================
# Shared setup for all analyses: packages, plot colours, number formatting, model
# helpers (estimated means and contrasts, random-effects selection), text helpers.
# Sourced by analysis/prequestions.qmd, analysis/final_test.qmd,
# analysis/eye_tracking.qmd and the manuscript. Run from the project root.
# =====================================================================================

library(tidyverse)
library(lme4)
library(lmerTest)      # type-III F tests with Satterthwaite df
library(easystats)     # parameters, performance, modelbased, insight
library(patchwork)
library(knitr)

options(contrasts = c("contr.sum", "contr.poly"))  # effect coding for type-III tests
theme_set(theme_minimal(base_size = 12) +
            theme(panel.grid.minor = element_blank(),
                  strip.text = element_text(face = "bold")))

# Fixed categorical order: Polio = slot 1 (blue), TB = slot 2 (orange)
# Colour-blind-safe colours (Okabe-Ito palette): Polio blue, TB vermillion, grey for
# Control / other. Checked under simulated deuteranopia, protanopia and tritanopia.
topic_cols <- c(Polio = "#0072B2", TB = "#D55E00")
# Sentence colours for fixation plots (up to 11 sentences per page): viridis, reordered so
# that neighbouring sentences differ strongly in lightness (no 11-colour categorical
# palette is colour-blind safe; lightness differences are)
sentence_cols <- viridisLite::viridis(11, end = 0.92)[c(1, 7, 3, 9, 5, 11, 2, 8, 4, 10, 6)]

# Standardise eye-tracking measures by sentence length (words per sentence)?
# TRUE: durations in ms/word. FALSE: raw ms.
length_norm <- TRUE

dur_unit   <- if (length_norm) "ms/word" else "ms"

# Fixed-decimal number formatting (never scientific notation)
fmt_num <- function(x, d = 2) formatC(x, format = "f", digits = d)
fmt_ci  <- function(lo, hi, d = 2) sprintf("[%s, %s]", fmt_num(lo, d), fmt_num(hi, d))

# modelbased wrappers. Estimates use the marginaleffects backend with
# estimate = "average": predictions are made for every observation in the data
# (including its random effects) and averaged within each level of the focal factors.
# For mixed models this reflects the variation due to the random effects and gives
# means that describe the actual sample (recommended for mixed models in the
# modelbased documentation). For linear models this is nearly identical to predictions
# at the fixed effects; for logistic models the averaged probabilities are
# population-averaged rather than for a typical participant. Models with a length
# offset are evaluated per word (offset = 1).
has_offset <- function(m) length(insight::find_offset(m)) > 0
est_means <- function(m, ...) {
  args <- list(m, ..., backend = "marginaleffects", estimate = "average")
  if (has_offset(m)) args$offset <- 1
  do.call(estimate_means, args)
}
est_contrasts <- function(m, ...) {
  args <- list(m, ..., backend = "marginaleffects", estimate = "average")
  if (has_offset(m)) args$offset <- 1
  do.call(estimate_contrasts, args)
}

# Satterthwaite degrees of freedom for contrasts from linear mixed models.
# marginaleffects cannot compute Satterthwaite df for contrasts within groups (`by`),
# and parameters::dof_satterthwaite() gives df for single coefficients, whereas a
# contrast such as "Polio - TB within the TB condition" combines several coefficients.
# Each contrast is therefore rebuilt as a weight vector L over the fixed effects and
# tested with lmerTest::contest(), which returns its Satterthwaite df. The estimates
# and SEs come from modelbased (averaged over the sample); because these average over
# the random effects, they can differ slightly from the fixed-effects contrast, so the
# df of the fixed-effects contrast is used as an approximation. With the derived
# measures the two estimates agree within a tenth of a standard error; when readers
# contribute unequal numbers of observations (e.g., Tobii's first-pass measure) the
# random effects do not fully cancel and a warning reports the gap.
# The CI and p-value are then recomputed with these df.
contrast_weights <- function(m, level1, level2, focal, by = NULL, by_level = NULL) {
  mf <- model.frame(m)
  make_row <- function(lev) {
    nd <- mf[1, , drop = FALSE]
    nd[[focal]] <- factor(lev, levels = levels(mf[[focal]]))
    if (!is.null(by)) nd[[by]] <- factor(by_level, levels = levels(mf[[by]]))
    nd
  }
  fixed_terms <- delete.response(terms(reformulas::nobars(formula(m))))
  X <- model.matrix(fixed_terms, rbind(make_row(level1), make_row(level2)),
                    contrasts.arg = attr(model.matrix(m), "contrasts"))
  X[1, ] - X[2, ]
}

add_satterthwaite <- function(tab, m, focal, by = NULL) {
  if (!inherits(m, "lmerModLmerTest")) return(tab)    # GLMMs use z tests (no df)
  satt <- map(seq_len(nrow(tab)), \(i) {
    L <- contrast_weights(m, tab$Level1[i], tab$Level2[i], focal, by,
                          if (!is.null(by)) as.character(tab[[by]][i]))
    ct <- lmerTest::contest(m, matrix(L, nrow = 1), joint = FALSE, ddf = "Satterthwaite")
    tibble(estimate = ct$Estimate, se = ct$`Std. Error`, df = ct$df)
  }) |> bind_rows()
  # The averaged contrast is usually very close to the fixed-effects contrast it borrows
  # df from; flag it if not (with df in the hundreds, the exact df barely matters)
  gap <- max(abs(satt$estimate - tab$Difference) / tab$SE)
  if (gap > 0.1) warning(sprintf("Averaged and fixed-effects contrasts differ by up to %.2f SE; Satterthwaite df are approximate.", gap))
  tab |>
    mutate(df = satt$df,
           CI_low  = Difference - qt(0.975, df) * SE,
           CI_high = Difference + qt(0.975, df) * SE,
           p = 2 * pt(-abs(t), df))
}

# ---- Text helpers (APA-style numbers, CIs and p values) -------------------------------
apa_p <- function(p) sub("0\\.", ".", format_p(p, digits = 3, stars = FALSE))  # "p = .021"
apa_num <- function(x, d = 2) fmt_num(x, d)

# Confidence interval and p value text. One-sided tests are reported with a 90% CI (the
# interval that matches a one-sided test at alpha = .05) and with both the one-tailed
# and the two-tailed p value; two-sided tests with a 95% CI and the two-tailed p.
#   est, se: estimate and standard error; lo, hi: the 95% CI (used for two-sided tests)
#   stat, df: test statistic (z: df = Inf); p: the p value used for the test
ci_part <- function(est, se, lo, hi, one_sided, df = Inf, d = 1) {
  if (one_sided) {
    crit <- qt(0.95, df)
    sprintf("90%% CI [%s, %s]", apa_num(est - crit * se, d), apa_num(est + crit * se, d))
  } else {
    sprintf("95%% CI [%s, %s]", apa_num(lo, d), apa_num(hi, d))
  }
}
p_part <- function(p, stat, df = Inf, one_sided = FALSE) {
  P <- \(x) sub("^p", "*p*", apa_p(x))
  if (one_sided) {
    sprintf("%s (one-tailed; two-tailed %s)", P(p), P(2 * pt(-abs(stat), df)))
  } else {
    P(p)
  }
}

yn <- function(x, yes = "significant", no = "not significant") if (x) yes else no

# Exclusion sentence; empty when nobody was excluded for that reason
excl_txt <- function(tab, reason) {
  n <- nrow(tab)
  if (n == 0) return("")
  sprintf("%s %s (%s) %s and %s excluded.",
          c("One", "Two", "Three", "Four", "Five")[n] %||% as.character(n),
          if (n == 1) "participant" else "participants",
          paste(tab$participant, collapse = ", "),
          reason, if (n == 1) "was" else "were")
}

# ---- Omnibus tests -------------------------------------------------------------------
# GLMMs (Gamma and logistic models, final test): type-III Wald chi-square tests
# (car::Anova). The F-test branch is kept for linear models but no longer used.
omnibus <- function(m, family) {
  if (family != "gaussian") {
    as.data.frame(model_parameters(car::Anova(m, type = 3))) |>
      transmute(Parameter, test = "chi2", stat = Chi2, df, df_error = NA_real_, p)
  } else {
    as.data.frame(model_parameters(anova(m, type = 3))) |>
      transmute(Parameter, test = "F", stat = F, df, df_error, p)
  }
}

# ---- Random-effects selection --------------------------------------------------------
# Every GLMM starts from the maximal random-effects structure of its design and is
# reduced by model comparison (Matuschek et al., 2017): if the maximal model is singular
# or does not converge, correlations are removed; then random slopes are removed one at
# a time by likelihood-ratio test while p > .20 (or while the model is singular).
# A random-effects structure is a list: grouping factor -> named list of slopes, where
# each slope is a character vector of numeric predictor codes.
# Build the random-effects part of a formula. Uncorrelated terms are written `(x || g)`
# for glmer and `diag(x | g)` for glmmTMB (which has no `||`).
re_formula <- function(re, family, correlated) {
  map2_chr(names(re), re, \(g, sl) {
    rhs <- paste(c("1", unlist(sl)), collapse = " + ")
    if (correlated || length(sl) == 0) sprintf("(%s | %s)", rhs, g)
    else if (family == "gamma") sprintf("diag(%s | %s)", rhs, g)
    else sprintf("(%s || %s)", rhs, g)
  }) |> paste(collapse = " + ")
}

# Fit one GLMM. Gamma GLMMs use glmmTMB: lme4's glmer() is unreliable for the Gamma
# family here (convergence failures and implausibly small standard errors).
# A fit that stops with an error returns NULL (treated as a failed fit below).
fit_one <- function(f, d, family) tryCatch(fit_one_raw(f, d, family), error = \(e) NULL)
fit_one_raw <- function(f, d, family) {
  if (family == "binomial") {
    suppressWarnings(glmer(f, data = d, family = binomial,
                           control = glmerControl(optimizer = "bobyqa",
                                                  optCtrl = list(maxfun = 2e5))))
  } else if (family == "gamma") {
    suppressWarnings(glmmTMB::glmmTMB(f, data = d, family = Gamma(link = "log")))
  } else if (family == "lognormal") {
    suppressWarnings(glmmTMB::glmmTMB(f, data = d, family = glmmTMB::lognormal(link = "log")))
  } else {
    stop("Unknown family: ", family)
  }
}

fit_ok <- function(m) {
  if (is.null(m)) return(FALSE)
  tryCatch(!isTRUE(check_singularity(m)) && isTRUE(check_convergence(m)),
           error = \(e) FALSE)
}

# Likelihood-ratio test of a larger vs. a smaller (nested) model
lrt <- function(m_big, m_small) {
  if (is.null(m_big) || is.null(m_small)) return(tibble(chi2 = NA_real_, df = NA_real_, p = NA_real_))
  l1 <- logLik(m_big); l0 <- logLik(m_small)
  chi2 <- max(0, 2 * (as.numeric(l1) - as.numeric(l0)))
  df <- attr(l1, "df") - attr(l0, "df")
  tibble(chi2 = chi2, df = df, p = pchisq(chi2, df, lower.tail = FALSE))
}

# Readable description of a structure, e.g. "participant: intercepts + Topic slopes;
# sentence: intercepts (uncorrelated)"
re_describe <- function(re, correlated) {
  parts <- map2_chr(names(re), re, \(g, sl) {
    if (length(sl) == 0) sprintf("%s: intercepts", g)
    else sprintf("%s: intercepts + %s slopes", g, paste(names(sl), collapse = " + "))
  })
  has_slopes <- any(lengths(re) > 0)
  paste0(paste(parts, collapse = "; "),
         if (has_slopes && !correlated) " (uncorrelated)" else "")
}

# Fit `fixed` with random effects selected from the maximal structure `re_max` (steps
# in the text above). Returns the final model with attributes:
#   re_used  - description of the final structure
#   re_steps - every comparison made (tibble), for the selection table
fit_glmm <- function(fixed, d, family, re_max, alpha = .20) {
  fit_re <- \(re, corr) fit_one(as.formula(paste(fixed, "+", re_formula(re, family, corr))),
                                d, family)
  re <- re_max
  steps <- tibble()
  corr <- TRUE
  m <- fit_re(re, corr)
  if (!fit_ok(m) && any(lengths(re) > 0)) {
    steps <- bind_rows(steps, tibble(step = "maximal model singular or not converged",
                                     term = "correlations", decision = "removed"))
    corr <- FALSE
    m <- fit_re(re, corr)
  }
  # backward selection of random slopes by likelihood-ratio test
  repeat {
    slopes <- tibble(group = rep(names(re), lengths(re)),
                     slope = unlist(map(re, names)))
    if (nrow(slopes) == 0) break
    cand <- pmap(slopes, \(group, slope) {
      re_red <- re
      re_red[[group]][[slope]] <- NULL
      m_red <- fit_re(re_red, corr)
      list(re = re_red, m = m_red, test = lrt(m, m_red))
    })
    tests <- bind_rows(map(cand, "test")) |> bind_cols(slopes)
    # If the current model itself failed to fit, move to the first simpler model that
    # does fit
    if (is.null(m)) {
      k <- which(!map_lgl(cand, \(x) is.null(x$m)))[1]
      stopifnot(!is.na(k))
      steps <- bind_rows(steps, tibble(
        step = sprintf("%s slope by %s", tests$slope[k], tests$group[k]),
        term = tests$slope[k], decision = "removed (model with it failed to fit)"))
      re <- cand[[k]]$re
      m <- cand[[k]]$m
      next
    }
    # A simpler model that fails to fit cannot justify removing a slope (p = 0: kept).
    # A fit that returns no log-likelihood gives no evidence for keeping the slope
    # (p = 1: removed).
    reduced_failed <- map_lgl(cand, \(x) is.null(x$m))
    tests$p[reduced_failed] <- 0
    lrt_failed <- is.na(tests$p)
    tests$p[lrt_failed] <- 1
    k <- which.max(tests$p)                       # the slope that matters least
    drop <- tests$p[k] > alpha || !fit_ok(m)
    steps <- bind_rows(steps, tibble(
      step = sprintf("%s slope by %s", tests$slope[k], tests$group[k]),
      term = tests$slope[k], chi2 = tests$chi2[k], df = tests$df[k], p = tests$p[k],
      decision = if (drop) {
        if (lrt_failed[k]) "removed (fit failed, no test)"
        else if (tests$p[k] > alpha) "removed (p > .20)" else "removed (model singular)"
      } else "kept"))
    if (!drop) break
    re <- cand[[k]]$re
    m <- cand[[k]]$m
  }
  attr(m, "re_used") <- re_describe(re, corr)
  attr(m, "re_steps") <- steps
  m
}

# Tables of the final random-effects structure of each model in `glmm_list` (a named
# list of models fitted with fit_glmm()) and of every likelihood-ratio test made.
re_selection_tables <- function(glmm_list) {
  list(
    final = tibble(Model = names(glmm_list),
                   `Final random effects` = map_chr(glmm_list, ~ attr(.x, "re_used"))),
    steps = imap_dfr(glmm_list, \(m, nm) mutate(attr(m, "re_steps"), Model = nm)))
}
show_re_selection <- function(tabs) {
  print(kable(tabs$final, caption = "Final random-effects structure of each GLMM"))
  print(kable(tabs$steps |>
                transmute(Model, Step = step, `χ²` = chi2, df,
                          p = if_else(is.na(p), "", format_p(p, name = NULL, digits = 3)),
                          Decision = decision),
              digits = 2, caption = "Random-effects selection: every likelihood-ratio test"))
  invisible(tabs)
}
