# Codebook: `data/derived/sentence_regions.tsv`

**What it is.** The sentence areas of interest rebuilt by `derive_et_measures.R` from the
page layout: one rectangle per sentence per text line (93 rows). Used for the AOI figure.
Coordinates are proportions of the screen (0–1; origin top-left).

| Column | Type | Description |
|---|---|---|
| `page` | integer | Text page (1–4). |
| `line` | integer | Text line (1 = top). |
| `sentence_index` | integer | Sentence position on the page. |
| `type` | text | `PO` / `TB` target or `Control` (non-target). |
| `x0`, `x1` | proportion | Left and right edge (first letter − ½ character, last letter + 1½ characters). |
| `y0`, `y1` | proportion | Top and bottom edge (line centre ± ½ line spacing). |
