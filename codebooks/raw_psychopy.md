# Codebook: PsychoPy session files (`data/raw/psychopy/prequestions/*.csv`, `data/raw/psychopy/final_test/*.csv`)

**What they are.** Raw PsychoPy output, one file per session:

- `data/raw/psychopy/prequestions/` — prequestion (pretest) sessions, named `<ID>_preQ_<date>.csv` (only
  participants in the Polio and TB conditions answered prequestions).
- `data/raw/psychopy/final_test/` — final test sessions, named `<ID>_preQ_test_<date>.csv`.

Each `.csv` has a matching `.log.gz` (PsychoPy's event log; not used). Files are never
edited; pilot sessions, ID errors and condition-label errors are handled in
`scoring_rubric.R` (`test_sessions`, `manual_map`, `file_map`, `group_corrections`).

**Format.** Comma-separated, one row per screen/trial (instructions, one row per question,
end screen); 36 columns. Only the columns below are used.

| Column | Description |
|---|---|
| `participant` | ID typed by the experimenter (may differ from the eye-tracking ID; matched on the number, with manual corrections in `scoring_rubric.R`). |
| `group` | Condition typed by the experimenter (`po`/`polio`, `tb`, `control`). The eye-tracking condition is used instead; P60 and P93 (Control) carry a leftover `polio` label in their test files, corrected in `scoring_rubric.R`. |
| `date` | Session date and time. |
| `Question` | Question text (one row per question). Matched to the answer key on its first 30 characters. |
| `Condition` | Topic of the question (`Polio` / `TB`). |
| `textbox_2.text` | The participant's typed response. |
| `trials.thisIndex` | Index of the question in the conditions file (question order was randomized). |
| `Preq_Phase.started` / `.stopped` (pretest), `Test_Phase.started` / `.stopped` (test) | Time (s) the question screen started / ended. Not used. |

Other columns (`mouse*`, `key_resp_2.*`, `Welcome.*`, `Test_instr.*`, `End.*`,
`expName`, `psychopyVersion`, `OS`, `frameRate`, `trials.*`) are PsychoPy bookkeeping and
are not used.
