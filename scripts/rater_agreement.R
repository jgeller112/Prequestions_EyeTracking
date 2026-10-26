# Agreement between the automated scores and an independent human rater
#
# Reads the rater's returned blind scoring sheets (data/raw/rater/) and the keys written by
# scripts/make_ra_scoring_sheet.R (scoring/ra_scoring_key*.csv), and writes
#   data/derived/rater_agreement.rds      agreement statistics (overall, by phase, by
#                                         question, per-participant final-test totals)
#   data/derived/rater_disagreements.csv  every response the two scorings disagree on
# Agreement: exact agreement and ICC(2,1) (two-way random effects, absolute agreement,
# single rater; Shrout & Fleiss, 1979), with 95% CIs from 2,000 bootstrap resamples.
#
# Run from the project root: Rscript scripts/rater_agreement.R

library(readr)
library(dplyr)
library(openxlsx)

# One key per batch sent to the rater (scoring/ra_scoring_key.csv, ra_scoring_key_2.csv, ...);
# the returned sheet of each batch is data/raw/rater/ra_scoring_sheet[_2, ...]_scored.xlsx.
# Batches not yet returned are left out (with a message).
keys <- list.files(here::here("scoring"), pattern = "^ra_scoring_key(_[0-9]+)?[.]csv$")
returned <- here::here("data", "raw", "rater",
                       sub("^ra_scoring_key(.*)[.]csv$", "ra_scoring_sheet\\1_scored.xlsx", keys))
if (any(!file.exists(returned)))
  message("Not yet returned by the rater (left out): ", paste(basename(returned[!file.exists(returned)]), collapse = ", "))
key <- bind_rows(lapply(here::here("scoring", keys[file.exists(returned)]), read_csv, show_col_types = FALSE))
ra <- bind_rows(lapply(returned[file.exists(returned)], \(f) read.xlsx(f, "Scoring"))) |>
  transmute(item_id = Item.ID, ra = Score, response_ra = Response)
d <- inner_join(key, ra, by = "item_id")
stopifnot(nrow(d) == nrow(key), nrow(d) == nrow(ra), !anyNA(d$ra),
          all(d$ra >= 0 & d$ra <= d$max_points),
          all(d$response == d$response_ra))         # the sheet matches the key row by row

icc21 <- function(x, y) {
  m <- cbind(x, y); n <- nrow(m); k <- 2
  gm <- mean(m); rm <- rowMeans(m); cm <- colMeans(m)
  msr <- k * sum((rm - gm)^2) / (n - 1)
  msc <- n * sum((cm - gm)^2) / (k - 1)
  mse <- sum((m - outer(rm, rep(1, k)) - outer(rep(1, n), cm) + gm)^2) / ((n - 1) * (k - 1))
  (msr - mse) / (msr + (k - 1) * mse + k * (msc - mse) / n)
}
summ <- function(x, y, B = 2000) {
  set.seed(2026)
  boot <- if (B > 0) replicate(B, { i <- sample(length(x), replace = TRUE); icc21(x[i], y[i]) }) else NA_real_
  tibble(n = length(x), exact = mean(x == y), within1 = mean(abs(x - y) <= 1),
         icc = icc21(x, y), icc_lo = unname(quantile(boot, 0.025, na.rm = TRUE)),
         icc_hi = unname(quantile(boot, 0.975, na.rm = TRUE)), n_disagree = sum(x != y),
         rater_minus_auto = mean(x - y))
}

totals <- d |>
  filter(phase == "Final test") |>
  group_by(participant) |>
  summarise(ra = sum(ra), auto = sum(auto_points), .groups = "drop")

agreement <- list(
  overall = summ(d$ra, d$auto_points),
  by_phase = d |> group_by(phase) |> group_modify(\(g, k) summ(g$ra, g$auto_points)) |> ungroup(),
  by_question = d |> group_by(questnum, max_points) |>
    group_modify(\(g, k) summ(g$ra, g$auto_points, B = 0)) |> ungroup() |>
    select(-icc_lo, -icc_hi),
  totals = summ(totals$ra, totals$auto)
)
saveRDS(agreement, here::here("data", "derived", "rater_agreement.rds"))

d |>
  filter(ra != auto_points) |>
  arrange(questnum, response) |>
  select(item_id, phase, questnum, max_points, response, auto_points, rater_points = ra) |>
  write_csv(here::here("data", "derived", "rater_disagreements.csv"))

message(sprintf("Exact agreement %.1f%%, ICC(2,1) = %.3f; %d disagreements",
                100 * agreement$overall$exact, agreement$overall$icc, agreement$overall$n_disagree))
