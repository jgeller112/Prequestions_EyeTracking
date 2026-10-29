# Eye-tracker calibration (run sheet)

`et_run_sheet.tsv` is the lab's run sheet for the eye-tracking sessions at Boston College
(Tobii Pro Spectrum), one row per session. **Participant names have been removed**; the
original sheet (with names) is not part of this repository.

| Column | Meaning |
|---|---|
| `PID` | Session ID. Four eye-tracking recordings carry a suffix in Tobii Pro Lab (P28PO, P87a, P104po, P141a = sheet P28, P87, P104, P141); the mapping is `calib_id_map` in `preq_eyetracking_analysis.qmd`. |
| `Date` | Session date as entered (month-day-year; some entries omit the year). |
| `group` | Condition as entered by the experimenter (po / tb / control). The eye-tracking recording's condition is used in the analysis when the two differ (P159). |
| `Ran` | Whether the session was run. |
| `Rerun` | `x` = flagged by the experimenter (e.g., calibration could not be brought under 0.5°). |
| `accuracy_deg` | Validation accuracy after calibration, degrees of visual angle (Tobii Pro Lab). |
| `precision_sd_deg` | Validation precision (SD of gaze samples), degrees of visual angle. |
| `comments` | Experimenter notes. |

Blank accuracy/precision = not recorded. P150 has no row in the sheet.
