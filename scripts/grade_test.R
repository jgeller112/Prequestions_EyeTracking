# Grade final test responses (all 10 questions: 5 Polio, 5 TB)
#
# Input:  data/raw/psychopy/final_test/*.csv (PsychoPy output, one file per session)
# Output: data/derived/test_scored_items.csv   one row per participant x question
#         data/derived/test_scored_topics.csv  one row per participant x topic
#                                      (points earned / total, for the
#                                      preregistered binomial GLMM)
#
# Rubric and helpers: scoring_rubric.R

source("scripts/scoring_rubric.R")

key <- read_csv("stimuli/answer_key.csv", show_col_types = FALSE)
et_ids <- load_et_ids()

raw <- read_psychopy("data/raw/psychopy/final_test") |>
  filter(!str_squish(participant) %in% test_sessions)

scored_all <- score_responses(raw, key) |>
  match_et_ids(et_ids)

# Keep only participants with eye-tracking data. Raw files are left untouched.
dropped_sessions <- scored_all |>
  filter(is.na(et_id)) |>
  distinct(file, psychopy_id, psychopy_group)

scored <- filter(scored_all, !is.na(et_id))

topics <- scored |>
  group_by(file, psychopy_id, et_id, et_group, psychopy_group, topic) |>
  summarise(n_questions = n(),
            n_answered = sum(!blank),
            points = sum(points),
            max_points = sum(max_points),
            .groups = "drop") |>
  mutate(prop_correct = points / max_points)

write_csv(scored, "data/derived/test_scored_items.csv")
write_csv(topics, "data/derived/test_scored_topics.csv")

# ---- Report ----------------------------------------------------------------
cat("\nScored", n_distinct(topics$et_id), "test sessions\n")

cat("\nSessions dropped (no eye-tracking data):\n")
print(dropped_sessions, n = Inf)

cat("\nEye-tracking participants with no test session:\n")
print(et_ids |> filter(!et_id %in% topics$et_id))

cat("\nParticipants with more than one test session:\n")
print(topics |> distinct(et_id, file) |> add_count(et_id) |> filter(n > 1))

# Condition comes from the eye-tracking data (et_group). P60 and P93 are labelled
# "polio" in their PsychoPy test files but are Control (confirmed; no pretest session);
# their label is corrected in scoring_rubric.R (group_corrections), so no mismatches
# should be listed here.
cat("\nGroup mismatches (PsychoPy vs eye-tracking; eye-tracking condition is used):\n")
print(topics |>
        mutate(pg = recode(str_to_lower(psychopy_group), polio = "po"),
               eg = str_to_lower(et_group)) |>
        filter(pg != eg) |>
        distinct(psychopy_id, et_id, psychopy_group, et_group))
