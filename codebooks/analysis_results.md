# Codebook: `analysis/results_*.rds`

**What they are.** The results the manuscript reads, written by the analysis reports
(`analysis/*.qmd`) and `scripts/bf_sensitivity.R`. Each report's file is a named list of
tables. Values are posterior summaries (40,000 draws): `Mean` = posterior mean, `CI_low`/
`CI_high` = 95% credible interval, `pd` = probability of direction, `ROPE_*` = bayestestR's
default ROPE output (not reported). Durations are in s per word; proportions 0–1.

Common keys: `model` = the measure (`final_test`, `prequestions`, `total_fix` = total gaze
duration, `first_pass` = selective regression-path duration, `regressed_in` = regression-in,
`reread_time` = re-reading time); `parameter` = `mu` (the mean, or the ex-Gaussian μ) or
`tau` (ex-Gaussian τ); `status` = `Prequestioned`, `Non-prequestioned`, `Control` (no
prequestions); `condition` = group (`Control`, `Polio`, `TB`); `topic` = `Polio`, `TB`.

| Element | Description |
|---|---|
| `bf` | Pooled models: Savage–Dickey Bayes factors for `Prequestioned - Control` and `Non-prequestioned - Control` (`log_BF`, `BF10`, `BF01`; `scale` = link or response scale). |
| `est` | Pooled models: the same comparisons' estimates (`Level1` − `Level2`). |
| `means`, `means_draws` | Pooled models: estimated means by status, and their posterior draws (`draw`, `value`). |
| `bf_topic`, `est_topic` | Group × Topic models: Bayes factors and estimates for `Polio - TB` within each group and the interaction (Polio group − TB group). |
| `means_topic`, `means_topic_draws` | Group × Topic models: means by group and topic (with the sentence's `status`), and their draws. |
| `diag` | Convergence: divergent transitions, maximum R-hat, minimum bulk ESS per model. |
| `sens` | priorsense power-scaling sensitivity per parameter (`prior`, `likelihood`, `diagnosis`). |
| `settings` | Sampler settings and prior widths (`s_log`, `s_logit`, `s_mu`). |
| `n_draws` | (eye tracking) Number of posterior draws. |
| `score_fit` | (final test) Posterior predictive check: observed and predicted share of each score (`lo`, `hi` = 95% interval) for the beta-binomial and binomial models. |
| `preq_means`, `preq_diff` | (prequestions) Mean proportion of points by condition and the Polio − TB difference. |

`analysis/results_bf_sensitivity.rds` is one table: the Bayes factors of `bf` and `bf_topic`
(`comparison`, `model`, `parameter`, `log_BF`, `BF10`, `BF01`) recomputed with every effect
prior at `width` × 0.5 or × 2, with the refit's name (`fit`), `design` (`status` = pooled,
`topic` = Group × Topic), `max_rhat` and `divergences`.
