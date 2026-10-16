# Codebook: `data/raw/calibration/et_run_sheet.tsv`

See `data/raw/calibration/README.md` (copied here for completeness).

**What it is.** The lab's eye-tracking run sheet: one row per session, with Tobii Pro Lab
calibration validation results. **Participant names were removed** (the original sheet,
which contains names, is not part of the project).

| Column | Description |
|---|---|
| `PID` | Session ID. Four recordings carry a suffix in Tobii Pro Lab (P28PO, P87a, P104po, P141a = P28, P87, P104, P141); mapped by `calib_id_map` in `preq_eyetracking_analysis.qmd`. |
| `Date` | Session date as entered. |
| `group` | Condition as entered by the experimenter (the eye-tracking condition is used when they differ, e.g. P159). |
| `Ran` | Whether the session was run. |
| `Rerun` | `x` = flagged by the experimenter (e.g., calibration could not be brought below 0.5°). |
| `accuracy_deg` | Validation accuracy, degrees of visual angle. |
| `precision_sd_deg` | Validation precision (SD of gaze samples), degrees. |
| `comments` | Experimenter notes. |

**Use.** Participants with accuracy or precision worse than 0.5° are excluded (P92, P13);
participants without values (P55, P62; P150 has no row) are kept.
