# Codebook: `power/pilot_reading1.csv`

**What it is.** Final-test data from the pilot study, used only for the power analysis
(`power/power_analysis.qmd`); not part of the pipeline. One row per participant × question
(373 participants; IDs are numbers only).

| Column | Type | Description |
|---|---|---|
| (unnamed first column) | integer | Row number. |
| `DataFile` | text | The pilot's original data file. |
| `Group` | text | Prequestion condition: `Control`, `Polio`, `TB`. |
| `Participant` | integer | Pilot participant number. |
| `Text` | text | The final-test question. |
| `Acc` | integer | Points earned on the question (0 to `poin`). |
| `Condition` | text | Topic of the question: `Polio`, `TB`. |
| `poin` | integer | Maximum points for the question (1–4). |
