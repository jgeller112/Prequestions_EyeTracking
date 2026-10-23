# Blind scoring sheet for a second (human) rater
#
# Writes
#   scoring/ra_scoring_sheet.xlsx  - for the rater: every non-blank prequestion and final
#                                    test response, in random order, with the question,
#                                    the answer, the maximum points and the scoring rules.
#                                    No participant ID, group, phase or automated score.
#   scoring/ra_scoring_key.csv     - NOT for the rater: links each row back to the
#                                    participant, phase and automated score, for computing
#                                    agreement once the sheet is returned.
#
# Responses that were blank or "I don't know" (and similar) score 0 by rule and are not
# included. Run from the project root: Rscript scripts/make_ra_scoring_sheet.R

library(readr)
library(dplyr)
library(openxlsx)

set.seed(2026)

answer_key <- read_csv(here::here("stimuli", "answer_key.csv"), show_col_types = FALSE)

responses <- bind_rows(
  Prequestion = read_csv(here::here("data", "derived", "preq_scored_items.csv"), show_col_types = FALSE),
  `Final test` = read_csv(here::here("data", "derived", "test_scored_items.csv"), show_col_types = FALSE),
  .id = "phase"
) |>
  filter(!blank) |>
  left_join(select(answer_key, questnum, Question), by = "questnum") |>
  slice_sample(prop = 1) |>                        # random order: phase and participant mixed
  mutate(item_id = sprintf("R%04d", row_number()))

# Elements credited for each question (as in the manuscript's Appendix A)
credited <- c(
  `1`  = "The number 17 (as a whole number, e.g., not 170).",
  `2`  = "A negative answer: \"no\", \"no cure\", or \"not a cure\".",
  `3`  = "One point each for Nigeria, India, Pakistan, and Afghanistan.",
  `4`  = "One point each for antibiotics; analgesics or pain relief; exercise (including physical activity or therapy); and diet or nutrition. \"Antibiotic resistance\" alone is not credited.",
  `5`  = "One point each for cough (or blood-tinged sputum/phlegm); fever (or temperature); night sweats; and weight loss.",
  `6`  = "10% (or \"ten percent\", 1/10); not credited if stated as \"less than\" or \"under\" 10%.",
  `7`  = "One point each for antibiotics (or antibacterials); two (two drugs, courses, rounds, or types); and long-term (long, extended, prolonged, or months).",
  `8`  = "A negative answer (\"no\").",
  `9`  = "One point each for cough, sneeze, and spit (or saliva).",
  `10` = "One point each for a starting value of hundreds of thousands (100,000-999,999) and an end value of about a thousand (500-9,999, or \"a thousand\")."
)

sheet <- responses |>
  transmute(Row = row_number(), `Item ID` = item_id, `Q` = questnum, Question,
            `Correct answer` = answer, `Max points` = max_points,
            Response = response, Score = NA_integer_, Notes = NA_character_)

rubric <- answer_key |>
  arrange(questnum) |>
  transmute(Q = questnum, Question, `Correct answer` = Answer, `Max points` = Points,
            `Elements credited (one point each unless stated)` = credited[as.character(questnum)])

instructions <- data.frame(Instructions = c(
  "Score every response in the 'Scoring' sheet. Enter the number of points in the Score column (0 up to the question's maximum; the cell only accepts whole numbers in that range).",
  "Award one point for each correct element present in the response, following the rules in the 'Rubric' sheet, up to the question's maximum.",
  "Accept minor misspellings when the intended word is unambiguous (e.g., 'afganistan').",
  "Do not award points for elements that are wrong, vague, or only implied. Extra incorrect elements do not cost points.",
  "Random keystrokes or answers unrelated to the question score 0.",
  "If you are unsure, enter your best score and explain in the Notes column.",
  "Score each response on its own; do not look for patterns across rows. Rows are in random order.",
  sprintf("There are %d responses to score.", nrow(sheet))
))

wb <- createWorkbook()
addWorksheet(wb, "Instructions")
addWorksheet(wb, "Rubric")
addWorksheet(wb, "Scoring")

wrap <- createStyle(wrapText = TRUE, valign = "top")
head_style <- createStyle(textDecoration = "bold", fgFill = "#DDDDDD", wrapText = TRUE,
                          valign = "top", border = "Bottom")

writeData(wb, "Instructions", instructions, headerStyle = head_style)
setColWidths(wb, "Instructions", 1, 110)
addStyle(wb, "Instructions", wrap, rows = 2:(nrow(instructions) + 1), cols = 1)

writeData(wb, "Rubric", rubric, headerStyle = head_style)
setColWidths(wb, "Rubric", 1:5, c(5, 45, 35, 10, 70))
addStyle(wb, "Rubric", wrap, rows = 2:(nrow(rubric) + 1), cols = 1:5, gridExpand = TRUE)

writeData(wb, "Scoring", sheet, headerStyle = head_style)
setColWidths(wb, "Scoring", 1:9, c(6, 9, 4, 40, 30, 8, 50, 8, 30))
addStyle(wb, "Scoring", wrap, rows = 2:(nrow(sheet) + 1), cols = 1:9, gridExpand = TRUE)
addStyle(wb, "Scoring", createStyle(fgFill = "#FFF7D6", valign = "top"),
         rows = 2:(nrow(sheet) + 1), cols = 8, stack = TRUE)
freezePane(wb, "Scoring", firstRow = TRUE)
# Score: whole number from 0 to the row's maximum points
for (i in seq_len(nrow(sheet))) {
  dataValidation(wb, "Scoring", cols = 8, rows = i + 1, type = "whole", operator = "between",
                 value = c(0, sheet$`Max points`[i]))
}

dir.create(here::here("scoring"), showWarnings = FALSE)
saveWorkbook(wb, here::here("scoring", "ra_scoring_sheet.xlsx"), overwrite = TRUE)

responses |>
  transmute(item_id, phase, participant = et_id, questnum, max_points,
            auto_points = points, response) |>
  write_csv(here::here("scoring", "ra_scoring_key.csv"))

message(sprintf("Wrote scoring/ra_scoring_sheet.xlsx (%d responses) and scoring/ra_scoring_key.csv",
                nrow(sheet)))
