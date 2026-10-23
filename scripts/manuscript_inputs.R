# Inputs for the manuscript: every number the manuscript reports that is not a model
# result (sample, exclusions, calibration, materials, fixation processing), computed once
# from the data files and saved, so that rendering the manuscript only reads files.
# Writes data/derived/manuscript_inputs.rds (a named list; the manuscript loads it into
# its environment). Run by targets (target `manuscript_inputs`), from the project root.

library(here)
params <- list(measures = "derived")
source(here("R", "setup.R"))
source(here("R", "data.R"))

# ---- Prequestion scores (descriptives) -----------------------------------------------
preq_perf <- read_csv(here::here("data", "derived", "preq_scored_participants.csv"), show_col_types = FALSE) |>
  filter(et_id %in% levels(dat$participant)) |>
  transmute(participant = et_id, condition = recode(et_group, Po = "Polio"), topic,
            pre = points / max_points, attempted = n_answered / n_questions)
stopifnot(n_distinct(preq_perf$participant) ==
            sum(n_by_cond$n[n_by_cond$condition != "Control"]))
preq_by_cond <- preq_perf |>
  group_by(condition) |>
  summarise(n = n(), pre_m = mean(pre), pre_sd = sd(pre), att_m = mean(attempted),
            .groups = "drop")

# ---- Sentence regions on the four text pages (figures) -------------------------------
regions <- read_tsv(here::here("data", "derived", "sentence_regions.tsv"), show_col_types = FALSE) |>
  mutate(role = factor(case_when(type == "PO" ~ "Polio target", type == "TB" ~ "TB target",
                                 TRUE ~ "Other sentence"),
                       levels = c("Polio target", "TB target", "Other sentence")))
# label each sentence once, at the start of its first line
region_labels <- regions |>
  group_by(page, sentence_index) |>
  slice_min(line, n = 1) |>
  ungroup()
targets2 <- filter(regions, page == 2, type %in% c("PO", "TB"))

# ---- Study facts used in the Method ----------------------------------------------------
# Study facts used in the Method (all from the data files)
answer_key <- read_csv(here::here("stimuli", "answer_key.csv"), show_col_types = FALSE)
points_by_topic <- answer_key |> group_by(Condition) |> summarise(points = sum(Points))
stopifnot(n_distinct(points_by_topic$points) == 1)

passage <- read_tsv(here::here("stimuli", "sentences.tsv"), show_col_types = FALSE)   # the text
n_sentences <- nrow(passage)
n_words_passage <- sum(passage$n_words)
target_words <- passage |> filter(type %in% c("PO", "TB")) |> pull(n_words)
# Length of the target sentences by topic (words)
words_by_topic <- passage |>
  filter(type %in% c("PO", "TB")) |>
  group_by(type) |>
  summarise(M = mean(n_words), SD = sd(n_words), min = min(n_words), max = max(n_words))
# Reading level (Flesch-Kincaid grade, quanteda.textstats) and syntactic complexity (udpipe
# parse with the English EWT model in stimuli/udpipe): mean dependency distance (words
# between each word and its syntactic head, excluding punctuation) and clauses per sentence
# (the main clause plus clausal dependents: ccomp, xcomp, advcl, acl, acl:relcl, csubj,
# parataxis, and coordinated verbs)
targets_txt <- passage |> filter(type %in% c("PO", "TB")) |> mutate(id = paste0("s", row_number()))
fk_grade <- quanteda.textstats::textstat_readability(
  quanteda::corpus(targets_txt$text, docnames = targets_txt$id), measure = "Flesch.Kincaid")
ud_parse <- udpipe::udpipe(setNames(targets_txt$text, targets_txt$id),
                           object = udpipe::udpipe_load_model(here::here("stimuli", "udpipe", "english-ewt-ud-2.5-191206.udpipe")))
clausal <- c("ccomp", "xcomp", "advcl", "acl", "acl:relcl", "csubj", "parataxis")
text_metrics <- ud_parse |>
  mutate(head = as.integer(head_token_id), tok = as.integer(token_id)) |>
  group_by(id = doc_id) |>
  summarise(mdd = mean(abs(tok - head)[dep_rel != "root" & upos != "PUNCT"]),
            clauses = 1 + sum(dep_rel %in% clausal | (dep_rel == "conj" & upos %in% c("VERB", "AUX")))) |>
  left_join(tibble(id = fk_grade$document, fk = fk_grade$Flesch.Kincaid), by = "id") |>
  left_join(select(targets_txt, id, type), by = "id") |>
  group_by(type) |>
  summarise(across(c(fk, mdd, clauses), list(M = mean, SD = sd)))
# the Materials text says the Polio target sentences have the higher reading level
stopifnot(text_metrics$fk_M[text_metrics$type == "PO"] > text_metrics$fk_M[text_metrics$type == "TB"])

# participants with eye-tracking recordings (full fixation export, via the derived measures)
n_recordings <- n_distinct(read_tsv(here::here("data", "derived", "et_measures.tsv"), show_col_types = FALSE)$participant)
n_excluded <- nrow(excluded_incomplete) + nrow(excluded_no_pretest) + nrow(excluded_no_test)

# Fixation processing (data/derived/fixations.tsv, written by derive_et_measures.R)
fx_all <- read_tsv(here::here("data", "derived", "fixations.tsv"), show_col_types = FALSE)
share_assigned <- mean(!is.na(fx_all$sentence_corrected))
both_labelled  <- filter(fx_all, !is.na(sentence_tobii), !is.na(sentence_corrected))
share_agree    <- mean(both_labelled$sentence_tobii == both_labelled$sentence_corrected)

derived_all <- read_tsv(here::here("data", "derived", "et_measures.tsv"), show_col_types = FALSE) |>
  filter(type %in% c("PO", "TB"), total_duration > 0,
         participant %in% levels(dat$participant))
fp_present_derived <- mean(!is.na(derived_all$first_pass_duration))
# landing: share of pages (analysed participants) on which the first fixation on the text
# fell below the first sentence
landed_below <- fx_all |>
  filter(participant %in% levels(dat$participant), !is.na(sentence_corrected)) |>
  group_by(recording, page) |>
  summarise(first_sentence = sentence_corrected[which.min(event_index)], .groups = "drop") |>
  summarise(share = mean(first_sentence > 1)) |>
  pull(share)


share_not_reread <- mean(dat$reread_any == 0, na.rm = TRUE)
# Target sentences never fixated (excluded from all eye-movement analyses)
n_not_fixated <- sum(is.na(dat$total_fix))
# Fixations shorter than 80 ms or longer than 1,000 ms, discarded first (derive_et_measures.R), analysed participants
raw_fix_dur <- read_tsv(here::here("data", "raw", "tobii", "fixations.tsv"), show_col_types = FALSE,
                        col_select = c(Participant, Recording, TOI, EventIndex, Duration)) |>
  distinct(Recording, TOI, EventIndex, .keep_all = TRUE) |>
  filter(Participant %in% levels(dat$participant))
share_short <- mean(raw_fix_dur$Duration < 80)
share_long  <- mean(raw_fix_dur$Duration > 1000)
fix_median  <- median(raw_fix_dur$Duration[between(raw_fix_dur$Duration, 80, 1000)])

# Calibration bound used for the drift correction (see derive_et_measures.R)
max_shift_cm <- 65 * tan(0.5 * pi / 180)

n_dat <- nrow(dat)

# ---- Drift-correction example and statistics ---------------------------------------------
# Example reader for the before/after figure: a TB-condition reader on page 2, chosen
# because their recorded gaze shows marked vertical drift
drift_id <- "P20"
fx_drift <- read_tsv(here::here("data", "derived", "fixations.tsv"), show_col_types = FALSE) |>
  filter(participant == drift_id, page == 2) |>
  arrange(event_index)
stopifnot(nrow(fx_drift) > 0)

# Size of the correction (in line spacings) and the share of assigned fixations whose
# sentence label changed, for this reader-page and as the median over all reader-pages
line_sp <- regions |> group_by(page) |> summarise(spacing = median(y1 - y0))
drift_stats <- read_tsv(here::here("data", "derived", "fixations.tsv"), show_col_types = FALSE) |>
  filter(participant %in% levels(dat$participant), !is.na(sentence_corrected)) |>
  left_join(line_sp, by = "page") |>
  group_by(participant, page) |>
  summarise(shift = median(abs(y_corrected - y_recorded) / spacing),
            relabelled = mean(sentence_tobii != sentence_corrected | is.na(sentence_tobii)),
            .groups = "drop")
drift_ex <- filter(drift_stats, participant == drift_id, page == 2)


inputs <- list(
  # sample, exclusions, calibration (R/data.R)
  n_total = n_total, n_by_cond = n_by_cond,
  excluded_incomplete = excluded_incomplete, excluded_calibration = excluded_calibration,
  excluded_no_pretest = excluded_no_pretest, excluded_no_test = excluded_no_test,
  calib_n = calib_n, calib_summary = calib_summary, calib_over = calib_over,
  # prequestion descriptives, regions
  preq_by_cond = preq_by_cond, regions = regions, region_labels = region_labels,
  targets2 = targets2,
  # materials
  answer_key = answer_key, points_by_topic = points_by_topic, n_sentences = n_sentences,
  n_words_passage = n_words_passage, words_by_topic = words_by_topic,
  text_metrics = text_metrics,
  # fixation processing and eye-movement data
  n_recordings = n_recordings, n_excluded = n_excluded, share_assigned = share_assigned,
  share_agree = share_agree, fp_present_derived = fp_present_derived,
  landed_below = landed_below, share_not_reread = share_not_reread,
  n_not_fixated = n_not_fixated, n_dat = n_dat, share_short = share_short,
  share_long = share_long, fix_median = fix_median, max_shift_cm = max_shift_cm,
  # drift example
  drift_id = drift_id, fx_drift = fx_drift, drift_stats = drift_stats, drift_ex = drift_ex
)
saveRDS(inputs, here("data", "derived", "manuscript_inputs.rds"))
