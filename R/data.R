# =====================================================================================
# Data for all analyses: sentence-level eye-movement measures, exclusions, calibration,
# and the analysis data sets. Requires R/setup.R. Run from the project root.
#
# Objects used by the analyses:
#   dat         one row per analysed participant x target sentence, all conditions
#   dat_rel     dat in the Polio and TB conditions, with relevance (prequestioned or not)
#   excluded_*  the participants excluded at each step (with reasons)
#   calib_*     calibration accuracy and precision
#   test_scores, preq_scores   scored final test and prequestions (by topic / participant)
# =====================================================================================

# Sentence-level measures are those derived from the fixation data by
# derive_et_measures.R (the only option)
if (!exists("params")) params <- list(measures = "derived")

# ---- Import ----------------------------------------------------------------------------
stopifnot(params$measures == "derived")

# Sentence-level measures (data/derived/et_measures.tsv, written by derive_et_measures.R
# from the fixation data, data/raw/tobii/fixations.tsv), with common column names; only
# the measures analysed in the manuscript (definitions in derive_et_measures.R):
#   total         total gaze duration: all fixation time on the sentence (ms)
#   go_past       selective regression-path duration (first-pass reading; ms): fixations
#                 on the sentence from first entering it until the first move to later
#                 text; NA if the sentence was skipped on first pass
#   reread_after  re-reading time: time on the sentence after the reader first moved on to
#                 later text (total minus the landing fixations and go_past; ms); NA if
#                 skipped on first pass
#   regressed_in  regression-in (look-back): whether the reader came back to the sentence
#                 from later text after first-pass reading
measures_src <- read_tsv(here::here("data", "derived", "et_measures.tsv"), show_col_types = FALSE) |>
  transmute(participant, group, type, aoi, number_of_units, sentence_index,
            total = total_duration,
            go_past = selective_regression_path,
            reread_after = rereading_duration,
            regressed_in = regressed_in)

# Only sentences that were fixated are analysed. A sentence that was never fixated has no
# reading time, so its total duration (0 in the derived file) is set to missing; its other
# measures are already missing. It therefore drops out of every model.
measures_src <- measures_src |>
  mutate(fixated = total > 0,
         total   = if_else(fixated, total, NA_real_))

# `group` is a reserved name in marginaleffects (used by modelbased), so it is
# renamed to `condition`
dat <- measures_src |>
  filter(type %in% c("PO", "TB")) |>
  transmute(
    participant = factor(participant),
    condition   = factor(recode(group, Po = "Polio"), levels = c("Control", "Polio", "TB")),
    topic       = factor(recode(type, PO = "Polio"), levels = c("Polio", "TB")),
    topic_c     = if_else(topic == "Polio", 0.5, -0.5),   # numeric code for random slopes
    # numeric codes for by-sentence Condition slopes (each prequestion condition vs.
    # Control, centred). Numeric codes let the selection procedure (Models) remove
    # correlations, which lme4's `||` does not do for factors.
    cond_polio  = (condition == "Polio") - 1/3,
    cond_tb     = (condition == "TB") - 1/3,
    total_fix   = total,
    go_past     = go_past,
    reread_after = reread_after,
    regressed_in = regressed_in,                          # binary; not length-normalised
    sentence    = factor(aoi),
    n_words     = number_of_units   # words per sentence (Tobii "Number of units")
  )

if (length_norm) {
  dat <- dat |> mutate(across(c(total_fix, go_past, reread_after),
                              ~ .x / n_words))
}

# Re-reading: whether the sentence was re-read after the reader had moved on to later
# text, and how long it was re-read when it was
dat <- dat |>
  mutate(reread_any  = if_else(is.na(reread_after), NA_integer_, as.integer(reread_after > 0)),
         reread_time = if_else(reread_after > 0, reread_after, NA_real_))

# ---- Exclusions ------------------------------------------------------------------------
# Pages with eye-tracking data = pages with recorded fixations that were processed by
# derive_et_measures.R. P101 has no fixations on page 3 and is excluded here. (P01's
# page 2 is included: P01 was re-exported with page-2 sentence labels; see
# derive_et_measures.R.)
pages_source <- read_tsv(here::here("data", "derived", "et_measures.tsv"), show_col_types = FALSE)
pages_per_participant <- pages_source |>
  mutate(group = recode(group, Po = "Polio")) |>
  group_by(participant, group) |>
  summarise(n_pages = n_distinct(toi),
            pages = paste(sort(unique(toi)), collapse = ", "), .groups = "drop")

# Exclusions are applied in this order, each among the participants not already
# excluded (so nobody is counted twice): (1) eye-tracking data for fewer than all four
# pages, (2) calibration, (3) prequestion condition without prequestion data, (4) no final
# test data.
participants_all <- dat |> distinct(participant, condition)

# (1) eye-tracking data for fewer than all four pages
excluded_incomplete <- pages_per_participant |> filter(n_pages < 4)
excluded_so_far <- as.character(excluded_incomplete$participant)

# (2) calibration. Preregistered criterion: validation accuracy and precision (SD of gaze
# samples) no worse than 0.5 degrees. Values come from the lab run sheet
# (data/raw/calibration/et_run_sheet.tsv; participant names removed). Also excluded:
# participants the experimenter flagged for a rerun (calibration could not be brought
# under 0.5 degrees) whose calibration values were never recorded. Participants without
# values who were not flagged are kept (the criterion cannot be checked for them). The
# sheet uses the session ID; four eye-tracking recordings carry a suffix.
calib_id_map <- c(P28PO = "P28", P87a = "P87", P104po = "P104", P141a = "P141")
calib <- read_tsv(here::here("data", "raw", "calibration", "et_run_sheet.tsv"),
                  col_types = cols(.default = "c")) |>
  transmute(sheet_id = PID,
            accuracy = as.numeric(accuracy_deg), precision = as.numeric(precision_sd_deg),
            rerun_flag = !is.na(Rerun) & str_to_lower(str_trim(Rerun)) == "x")
# Values missing from the run sheet, supplied by the PI from the lab records (P66:
# 2026-10-15; P55, P62, P150: 2026-10-20). P150 has no row in the sheet, so the
# corrections are full-joined (they add rows for participants missing from the sheet).
calib_corrections <- tribble(
  ~sheet_id, ~accuracy_fix, ~precision_fix,
  "P66",     0.76,          0.19,
  "P55",     0.46,          0.14,
  "P62",     0.47,          0.16,
  "P150",    0.25,          0.17
)
calib <- calib |>
  full_join(calib_corrections, by = "sheet_id") |>
  mutate(accuracy = coalesce(accuracy, accuracy_fix),
         precision = coalesce(precision, precision_fix)) |>
  select(-accuracy_fix, -precision_fix)
# calibration of every recorded participant (blank / absent in the sheet -> NA)
calib_all <- participants_all |>
  mutate(sheet_id = coalesce(unname(calib_id_map[as.character(participant)]),
                             as.character(participant))) |>
  left_join(calib, by = "sheet_id") |>
  mutate(rerun_flag = coalesce(rerun_flag, FALSE))
excluded_calibration <- calib_all |>
  filter(!participant %in% excluded_so_far,
         accuracy > 0.5 | precision > 0.5 |
           (rerun_flag & (is.na(accuracy) | is.na(precision)))) |>
  select(participant, condition, accuracy, precision)
excluded_so_far <- c(excluded_so_far, as.character(excluded_calibration$participant))

# (3) prequestion-condition participants need prequestion (prior-knowledge) data;
# scores come from grade_prequestions.R
preq_scores <- read_csv(here::here("data", "derived", "preq_scored_participants.csv"), show_col_types = FALSE)
excluded_no_pretest <- participants_all |>
  filter(!participant %in% excluded_so_far, condition != "Control",
         !participant %in% preq_scores$et_id)
excluded_so_far <- c(excluded_so_far, as.character(excluded_no_pretest$participant))

# (4) every participant needs final test data; scores come from grade_test.R
test_scores <- read_csv(here::here("data", "derived", "test_scored_topics.csv"), show_col_types = FALSE)
excluded_no_test <- participants_all |>
  filter(!participant %in% excluded_so_far, !participant %in% test_scores$et_id)
excluded_so_far <- c(excluded_so_far, as.character(excluded_no_test$participant))

# Other preregistered exclusions (high prior knowledge) to be added here, e.g. c("P12")
excluded_prereg <- character(0)

excluded_ids <- c(excluded_so_far, excluded_prereg)
dat <- dat |> filter(!participant %in% excluded_ids) |> droplevels()

n_by_cond <- dat |> distinct(participant, condition) |> count(condition)
n_missing <- sum(is.na(dat$total_fix))

kable(n_by_cond, col.names = c("Condition", "N participants"),
      caption = "Participants per condition after exclusions")

# ---- Calibration of the analysed participants ------------------------------------------
# calibration of the analysed participants (calib_all is built in the exclusions above)
calib_inc <- filter(calib_all, participant %in% levels(dat$participant))
stopifnot(nrow(calib_inc) == nlevels(dat$participant))

calib_n       <- sum(!is.na(calib_inc$accuracy) & !is.na(calib_inc$precision))
calib_missing <- filter(calib_inc, is.na(accuracy) | is.na(precision))
# worse than the preregistered 0.5-degree criterion
calib_over    <- filter(calib_inc, accuracy > 0.5 | precision > 0.5)
calib_summary <- calib_inc |>
  summarise(across(c(accuracy, precision),
                   list(M = \(x) mean(x, na.rm = TRUE), SD = \(x) sd(x, na.rm = TRUE),
                        min = \(x) min(x, na.rm = TRUE), max = \(x) max(x, na.rm = TRUE))))

calib_summary |>
  pivot_longer(everything(), names_to = c("Measure", ".value"), names_sep = "_") |>
  kable(digits = 2, caption = sprintf(
    "Calibration validation (degrees), %d of %d analysed participants with data",
    calib_n, nlevels(dat$participant)))
# by condition (analysed participants with calibration data)
calib_by_cond <- calib_inc |>
  filter(!is.na(accuracy), !is.na(precision)) |>
  group_by(condition) |>
  summarise(n = n(),
            acc_M = mean(accuracy), acc_SD = sd(accuracy),
            prec_M = mean(precision), prec_SD = sd(precision), .groups = "drop")
kable(calib_by_cond, digits = 2, caption = "Calibration validation by condition (degrees)")

kable(select(calib_missing, participant, condition),
      caption = "Analysed participants without calibration data")
kable(select(calib_over, participant, accuracy, precision),
      caption = "Analysed participants worse than the 0.5° criterion")

# ---- Prequestioned vs. non-prequestioned data (Polio and TB conditions) -----------------
dat_rel <- dat |>
  filter(condition != "Control") |>
  mutate(relevance = factor(if_else(as.character(topic) == as.character(condition),
                                    "Prequestioned", "Non-prequestioned"),
                            levels = c("Prequestioned", "Non-prequestioned")),
         rel_c = if_else(relevance == "Prequestioned", 0.5, -0.5)) |>
  droplevels()

# ---- Sentence status for the reader (all three conditions) -------------------------------
# Prequestioned: Polio sentences in the Polio condition, TB sentences in the TB condition;
# Non-prequestioned: the other topic in those conditions; Control: all sentences read by
# Control readers. Topic is balanced across the three levels. Numeric codes (centred, as
# for Condition) are used for by-sentence status slopes.
dat_status <- dat |>
  mutate(status = case_when(condition == "Control" ~ "Control",
                            as.character(topic) == as.character(condition) ~ "Prequestioned",
                            TRUE ~ "Non-prequestioned"),
         status = factor(status, levels = c("Prequestioned", "Non-prequestioned", "Control")),
         stat_pre = (status == "Prequestioned") - 1/3,
         stat_non = (status == "Non-prequestioned") - 1/3)

n_total <- sum(n_by_cond$n)
