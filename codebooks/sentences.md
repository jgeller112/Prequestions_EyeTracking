# Codebook: `stimuli/sentences.tsv`

**What it is.** The text participants read: one row per sentence (38 sentences, 690 words,
on four pages), in the order shown. Read by `derive_et_measures.R` (to rebuild the page
layout and assign fixations to sentences), `R/data.R` and `manuscript_inputs.R` (text
statistics). Not edited by the pipeline.

| Column | Type | Description |
|---|---|---|
| `page` | integer | Text page (1–4). |
| `sentence_index` | integer | Order of the sentence on its page (1 = first). Matches Tobii Pro Lab's `Sentence_index` AOIs. |
| `type` | text | `PO` = Polio target sentence, `TB` = TB target sentence (each contains the answer to one question; 5 per topic), `Control` = other sentence. |
| `n_words` | integer | Number of words (Tobii Pro Lab's "Number of units"); durations are divided by this (ms per word). |
| `text` | text | The sentence as shown on screen. |
