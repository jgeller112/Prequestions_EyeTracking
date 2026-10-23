# Grade prequestion (pretest) responses
#
# Input:  data/raw/psychopy/prequestions/*.csv (PsychoPy output, one file per session)
# Output: data/derived/preq_scored_items.csv         one row per participant x question
#         data/derived/preq_scored_participants.csv  one row per participant
#
# Rubric and helpers: scoring_rubric.R

source(here::here("scripts", "scoring_rubric.R"))

key <- read_csv(here::here("stimuli", "answer_key.csv"), show_col_types = FALSE)
et_ids <- load_et_ids()

raw <- read_psychopy(here::here("data", "raw", "psychopy", "prequestions")) |>
  filter(!str_squish(participant) %in% test_sessions)

scored_all <- score_responses(raw, key) |>
  match_et_ids(et_ids)

# Keep only participants in the eye-tracking prequestion conditions.
# Dropped: sessions with no eye-tracking data. (The pretest file named P92 is P91's;
# see file_map in scoring_rubric.R.) Raw files are left untouched.
dropped_sessions <- scored_all |>
  filter(is.na(et_id) | et_group == "Control") |>
  distinct(file, psychopy_id, psychopy_group, et_id, et_group) |>
  mutate(reason = if_else(is.na(et_id), "no eye-tracking data",
                          "Control condition in eye-tracking data"))

scored <- scored_all |>
  filter(!is.na(et_id), et_group != "Control")

participants <- scored |>
  group_by(file, psychopy_id, et_id, et_group, psychopy_group, topic) |>
  summarise(n_questions = n(),
            n_answered = sum(!blank),
            points = sum(points),
            max_points = sum(max_points),
            .groups = "drop") |>
  mutate(prop_correct = points / max_points)

write_csv(scored, here::here("data", "derived", "preq_scored_items.csv"))
write_csv(participants, here::here("data", "derived", "preq_scored_participants.csv"))

# ---- Report ----------------------------------------------------------------
cat("\nScored", nrow(participants), "pretest sessions\n")

cat("\nSessions dropped from the scored output:\n")
print(dropped_sessions, n = Inf)

cat("\nEye-tracking prequestion participants with no scored session:\n")
print(et_ids |> filter(et_group != "Control", !et_id %in% participants$et_id))

cat("\nGroup mismatches (PsychoPy vs eye-tracking):\n")
print(participants |>
        filter(str_to_lower(psychopy_group) != str_to_lower(et_group)) |>
        select(psychopy_id, et_id, psychopy_group, et_group))
