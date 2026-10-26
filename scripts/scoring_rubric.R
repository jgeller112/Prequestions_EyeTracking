# Shared scoring rubric for the prequestion pretest and the final test
#
# Key: stimuli/answer_key.csv. Wording checked against the passage in
# stimuli/Prequestion_reading_v2.docx.
#
# Each question awards 1 point per credited key element (see `rubric`). Blank,
# "I don't know", and keyboard-mash answers score 0. Spelling errors are
# tolerated where the intended word is unambiguous (e.g., "afganistan").

library(tidyverse)

# Whole-number match, so "10" does not match "100" or "0.10"
num_is <- function(x, n) str_detect(x, paste0("(^|[^0-9.])", n, "([^0-9]|$)"))

# ---- Q10 helper: "from many hundreds of thousands to around a thousand" -----
# Splits an answer into a "from" and a "to" amount and classifies each one by
# magnitude: HT = hundreds of thousands (100,000-999,999), TT = tens of thousands,
# T = thousands (500-9,999 or the word "thousand"), M = millions, H = hundreds.
classify_amount <- function(s) {
  s <- str_squish(s)
  if (is.na(s) || s == "" || str_detect(s, "%")) return("other")
  n <- suppressWarnings(as.numeric(str_extract(s, "[0-9]+(\\.[0-9]+)?")))
  mult <- case_when(str_detect(s, "million") ~ 1e6,
                    str_detect(s, "thousand|[0-9]k\\b") ~ 1e3,
                    TRUE ~ 1)
  if (!is.na(n)) {
    v <- n * mult
    return(case_when(v >= 1e6 ~ "M", v >= 1e5 ~ "HT", v >= 1e4 ~ "TT",
                     v >= 500 ~ "T", TRUE ~ "other"))
  }
  case_when(str_detect(s, "million") ~ "M",
            str_detect(s, "hundred") & str_detect(s, "thous|thouands") ~ "HT",
            str_detect(s, "\\btens? (of )?thousand") ~ "TT",
            str_detect(s, "thousand") ~ "T",
            str_detect(s, "hundred") ~ "H",
            TRUE ~ "other")
}

q10_parts <- function(x) {
  x <- str_replace_all(x, "([0-9]),([0-9])", "\\1\\2")       # 100,000 -> 100000
  parts <- str_split(x, "\\s+to\\s+|[;:,]|\\s+-\\s+")[[1]] |> str_squish()
  parts <- parts[parts != ""]
  if (length(parts) < 2) {                                    # "100000 100"
    nums <- str_extract_all(x, "[0-9]+(\\.[0-9]+)?(k\\b)?")[[1]]
    if (length(nums) >= 2) parts <- nums[1:2]
  }
  if (length(parts) < 2) {                                    # "hundreds of thousands thousands"
    m <- str_match(str_squish(x), "^(.*?thousands?)\\s+(\\S.*)$")
    if (!is.na(m[1, 1])) parts <- m[1, 2:3]
  }
  if (length(parts) < 2) return(c(from = "other", to = "other"))
  c(from = classify_amount(parts[1]), to = classify_amount(parts[2]))
}

# ---- Rubric: one detector per credited element ------------------------------
rubric <- list(
  # Q1: 17%
  `1` = list(seventeen = \(x) num_is(x, 17)),

  # Q2: no ("Polio has no cure")
  `2` = list(no = \(x) str_detect(x, "^no\\b|no cure|not a (single )?(known )?cure|is not a cure")),

  # Q3: Nigeria, India, Pakistan, Afghanistan
  `3` = list(nigeria     = \(x) str_detect(x, "niger(ia|gia)"),
             india       = \(x) str_detect(x, "\\bindia\\b"),
             pakistan    = \(x) str_detect(x, "pakist"),
             afghanistan = \(x) str_detect(x, "af(g)?h?an|afgh|afghast")),

  # Q4: antibiotics, analgesics (pain relief), moderate exercise, nutritious diet
  `4` = list(antibiotics = \(x) str_detect(x, "anti-?biotic") & !str_detect(x, "^antibiotic resistance$"),
             analgesics  = \(x) str_detect(x, "analges|alages|pain"),
             exercise    = \(x) str_detect(x, "exerc|excer|excers|physical (activ|therap)|staying active|movement|fitness"),
             diet        = \(x) str_detect(x, "diet|nutri")),

  # Q5: chronic cough with blood-tinged sputum, fever, night sweats, weight loss
  #     (any mention of sweating is credited for night sweats)
  `5` = list(cough        = \(x) str_detect(x, "coug|blood.*(sput|spit|phlegm|flegm|mucus|mucous|septum|suptum|saliva)|(sput|spit|phlegm|mucus).*blood|red mucus"),
             fever        = \(x) str_detect(x, "fever|temperature"),
             night_sweats = \(x) str_detect(x, "sweat"),
             weight_loss  = \(x) str_detect(x, "weigh(t)?[- ]?loss|los(s|ing) (of )?weight|weightloss")),

  # Q6: 10%
  `6` = list(ten = \(x) (num_is(x, 10) | str_detect(x, "\\bten percent|1/10")) &
                        !str_detect(x, "<|less than|under")),

  # Q7: long-term course of two antibiotics (to kill the bacteria)
  #     credited elements: antibiotics, two (antibiotics / courses / types), long-term
  `7` = list(antibiotics = \(x) str_detect(x, "anti-?biotic|anti-?bacterial"),
             # "two" must refer to antibiotics/drugs/courses, not e.g. "2 weeks" or "2 vaccines"
             two         = \(x) str_detect(x, paste0("(\\btwo\\b|\\b2\\b|double|multi(ple)?)[- ]?([a-z]+[- ]){0,3}",
                                                  "(anti-?biotic|anti-?bod(y|ies)|drug|medication|round|course|kind|type|dose|part|stage)")),
             long_term   = \(x) str_detect(x, "long|extend|extensive|prolonged|over time|months")),

  # Q8: no ("Only people with active, not latent, TB can transmit the disease")
  `8` = list(no = \(x) str_detect(x, "^no\\b|^nope|guessing no")),

  # Q9: cough, sneeze, spit
  `9` = list(cough  = \(x) str_detect(x, "cough"),
             sneeze = \(x) str_detect(x, "sneez"),
             spit   = \(x) str_detect(x, "spit|saliva")),

  # Q10: many hundreds of thousands -> around a thousand
  `10` = list(from_hundreds_of_thousands = \(x) q10_parts(x)[["from"]] == "HT",
              to_about_a_thousand        = \(x) q10_parts(x)[["to"]] == "T")
)

score_one <- function(q, response) {
  x <- str_to_lower(coalesce(response, ""))
  hits <- map_lgl(rubric[[as.character(q)]], \(f) isTRUE(f(x)))
  list(points = sum(hits), credited = paste(names(hits)[hits], collapse = ", "))
}

no_answer_regex <- paste0("^(i )?(do not|don'?t|dont|cannot|can'?t) (know|remember|recall)|",
                          "^idk$|^no (idea|clue)|^not sure|^unsure|^n/?a$|^none$|^-$|",
                          "^i (forgot|forget)|^forget")

# Read PsychoPy response files and score them
read_psychopy <- function(dir) {
  files <- list.files(dir, pattern = "[.]csv$", full.names = TRUE)
  map(files, \(f) {
    x <- tryCatch(read_csv(f, show_col_types = FALSE, col_types = cols(.default = "c")),
                  error = function(e) NULL)
    if (is.null(x) || nrow(x) == 0) NULL else mutate(x, file = basename(f))
  }) |>
    bind_rows()
}

# Condition labels that are wrong in the raw PsychoPy files (the raw files are not
# changed). P60 and P93 are Control: they have no prequestion session, and the
# eye-tracking recording and run sheet list them as Control; their final-test files
# carry a leftover "polio" label (confirmed by the PI, 2026-10-15).
group_corrections <- c(P60 = "control", P93 = "control")

score_responses <- function(raw, key) {
  key <- mutate(key, q_stub = str_sub(str_squish(Question), 1, 30))
  out <- raw |>
    filter(!is.na(Question)) |>
    transmute(file,
              psychopy_id = str_squish(participant),
              psychopy_group = coalesce(unname(group_corrections[str_squish(participant)]),
                                        group),
              q_stub = str_sub(str_squish(Question), 1, 30),
              response = str_squish(textbox_2.text)) |>
    left_join(select(key, q_stub, questnum, topic = Condition, max_points = Points,
                     answer = Answer), by = "q_stub")
  stopifnot(!anyNA(out$questnum))
  out <- out |>
    mutate(s = map2(questnum, response, score_one),
           points = map_int(s, "points"),
           credited = map_chr(s, "credited"),
           blank = is.na(response) | str_detect(str_to_lower(response), no_answer_regex)) |>
    select(-s, -q_stub)
  stopifnot(all(out$points <= out$max_points))
  out
}

# Eye-tracking IDs sometimes carry suffixes (P132a, P28PO); match on the number
norm_id <- function(x) {
  d <- str_extract(x, "[0-9]+")
  if_else(is.na(d), NA_character_, paste0("P", as.integer(d)))
}

# Manual ID corrections (PsychoPy ID -> eye-tracking ID)
manual_map <- tribble(
  ~psychopy_id, ~et_id,
  "P1902",      "P19012"   # same participant; eye-tracking ID mistyped
)

# Manual corrections for individual session files (file -> eye-tracking ID).
# Take precedence over ID-based matching.
file_map <- tribble(
  ~file,                                   ~et_id_file,
  # Pretest saved under the wrong ID: TB pretest at 12:09 on 2025-02-27, followed by
  # P91's TB test at 12:23. P92 is Control (Control has no pretest; P92's own test is
  # at 12:48), so this session is P91's.
  "P92_preQ_2025-02-27_12h09.17.770.csv",  "P91"
)

# Pilot / test sessions (not participants)
test_sessions <- c("1123", "123", "hdhdhdhd", "ss test")

match_et_ids <- function(scored, et_ids) {
  scored |>
    mutate(id_norm = norm_id(psychopy_id)) |>
    left_join(manual_map, by = "psychopy_id") |>
    left_join(file_map, by = "file") |>
    left_join(select(et_ids, id_norm, et_id_auto = et_id), by = "id_norm") |>
    mutate(et_id = coalesce(et_id_file, et_id, et_id_auto)) |>
    select(-et_id_auto, -et_id_file) |>
    left_join(select(et_ids, et_id, et_group), by = "et_id")
}

# Eye-tracking participants and their conditions, from the full Tobii Pro Lab fixation
# export (data/raw/tobii/fixations.tsv, all 160 recorded participants)
load_et_ids <- function() {
  read_tsv(here::here("data", "raw", "tobii", "fixations.tsv"), show_col_types = FALSE,
           col_select = c(Participant, Group)) |>
    distinct(et_id = Participant, et_group = Group) |>
    mutate(id_norm = norm_id(et_id))
}
