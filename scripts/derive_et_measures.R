# =====================================================================================
# Derive sentence-level eye-tracking measures from Tobii fixation data,
# with correction for vertical drift
# =====================================================================================
#
# INPUTS
#   data/raw/tobii/fixations.tsv              One row per fixation (Tobii Pro Lab export): recording,
#                                 page (TOI), time order (EventIndex), duration (ms),
#                                 Tobii's sentence AOI, and gaze position (x, y as a
#                                 proportion of screen width / height, 0-1).
#   stimuli/sentences.tsv         The text: one row per sentence with its page, order on
#                                 the page (sentence_index), type (PO / TB target,
#                                 Control = non-target), number of words, and text.
#   stimuli/pages/page1-4_full.png  Full-resolution screenshots of the four pages
#                                 (1920 x 1080 px, the screen resolution), used to locate
#                                 the text lines and character positions.
#
# OUTPUTS
#   data/derived/et_measures.tsv  One row per recording x page x sentence, with the
#                                 derived measures.
#   data/derived/fixations.tsv    One row per fixation: recorded and drift-corrected
#                                 position, assigned line and sentence (corrected and
#                                 Tobii's), and whether reading had started (Step 5).
#   data/derived/sentence_regions.tsv  The sentence regions (areas of interest) used:
#                                 one rectangle per sentence per text line, in screen
#                                 proportions (0-1), from the rebuilt layout (Steps 1-2).
#   data/derived/et_checks/       Overlay plots of fixations on the page images, before
#                                 and after drift correction, for visual checking.
#
# WHY THIS SCRIPT EXISTS
#   Tobii's sentence measures have two problems in this data set:
#   1. Page landing. When a page appears, the eyes usually land partway down it and then
#      move to the first line. Tobii treats the sentences above the landing point as
#      already passed, so their first-pass time is 0 (true for ~84% of first sentences).
#   2. Vertical drift. Recorded gaze sits roughly half a line above the text for many
#      readers, so Tobii often labels a fixation with the sentence on the line above.
#      This creates spurious "regressions" (e.g., a rightward move along a line that is
#      labelled as a jump back to an earlier sentence) and chops first passes into
#      pieces.
#
# WHAT THE SCRIPT DOES (each step is a section below)
#   (first) Fixations shorter than 80 ms or longer than 1,000 ms are discarded (see
#           min_fixation_ms and max_fixation_ms).
#   Step 1  Rebuild the exact text layout of each page: which sentence occupies every
#           character position on every line. The text is in a fixed-width font, so a
#           character's screen position follows from its column number.
#   Step 2  Find the screen position of each text line (from the page images) and the
#           size of one character.
#   Step 3  Drift correction: for each reader and page, estimate how far their recorded
#           gaze is shifted vertically, then assign each fixation to a text line using
#           runs of fixations that move along a line together ("chains").
#   Step 4  Convert each fixation's line + horizontal position into a character column,
#           and from that into the sentence it falls on.
#   Step 5  Decide where reading starts on each page (first fixation on sentence 1).
#   Step 6  Compute the sentence-level reading measures.
#   Step 7  Save the output and print checks.
#   Step 8  Save overlay plots for visual checking.
#
# MEASURE DEFINITIONS (sentence = one AOI; "earlier"/"later" = sentence order on page)
# Only the measures reported in the manuscript are computed (definitions follow Schotter
# & Dillon, 2025). The analysed measures do not overlap:
#   total_duration = landing_duration + selective_regression_path + rereading_duration
#   (for every sentence read on first pass).
#
#   total_duration           Total gaze duration: sum of all fixations on the sentence
#                            (whole page visit, including any before reading started).
#                            Analysed.
#   landing_duration         Fixations on the sentence before reading started on the page
#                            (the eyes landing on the page when it appears; Step 5).
#                            Used only to compute rereading_duration.
#   selective_regression_path  Selective regression-path duration (first-pass reading):
#                            fixations on the sentence from first entering it until the
#                            eyes first move to a later sentence; brief returns to earlier
#                            text do not end it, and time on earlier text is not counted.
#                            NA if the sentence was skipped on first pass (a later
#                            sentence had already been read). Analysed.
#   rereading_duration       Re-reading time: time on the sentence after the reader first
#                            moved on to later text: total_duration - landing_duration -
#                            selective_regression_path. NA if skipped on first pass.
#                            Analysed (when > 0).
#   regressed_in             Regression-in (look-back): 1 if the reader came back to the
#                            sentence FROM LATER TEXT after first-pass reading had moved
#                            past it, else 0. Re-entries from earlier text (after
#                            regressing out of the sentence) are not counted. NA if
#                            skipped on first pass. Analysed.
#   first_pass_duration      The preregistered first-pass duration: fixations from first
#                            entering the sentence until first leaving it. NA if skipped
#                            on first pass. Not analysed: it was bimodal (see
#                            first_pass_regression), which the manuscript reports as the
#                            reason for the deviation to selective_regression_path.
#   first_pass_regression    1 if the first pass ended by moving to an earlier sentence,
#                            0 if to a later sentence. NA if there was no first pass, the
#                            page ended during it, or the sentence is the first on its
#                            page. Only used to describe why first_pass_duration was
#                            bimodal (interrupted first passes).
# =====================================================================================

library(tidyverse)
library(png)

# ---- Settings -----------------------------------------------------------------------

# Full Tobii Pro Lab fixation export, all recorded participants (161).
fix_file   <- here::here("data", "raw", "tobii", "fixations.tsv")
sentences_file <- here::here("stimuli", "sentences.tsv")
out_file   <- here::here("data", "derived", "et_measures.tsv")
fixations_file <- here::here("data", "derived", "fixations.tsv")
regions_file   <- here::here("data", "derived", "sentence_regions.tsv")
check_dir  <- here::here("data", "derived", "et_checks")

# Text layout (Step 1). Verified in Step 2 against the line lengths in the page images.
wrap_width   <- 79   # maximum characters per line
page4_indent <- 2    # page 4 starts each paragraph with 2 spaces (visible in the image)

# Places where the text on screen differs from Tobii's sentence text. Tobii's AOI text
# collapses double spaces, but page 4 shows two spaces after "philanthrocapitalism.";
# without this correction every character after it on that line is placed one
# character too far left (found from the full-resolution image, Step 2).
screen_text_fixes <- c("philanthrocapitalism.” “Philanthrocapitalism," =
                         "philanthrocapitalism.”  “Philanthrocapitalism,")

# Paragraphs on each page, as sentence numbers (Sentence_index), read from the page
# images. Step 2 checks that the resulting number of lines matches the images.
paragraphs <- list(
  `1` = list(1:6, 7:10),
  `2` = list(1, 2:9, 10:11),
  `3` = list(1:2, 3:8, 9:10),
  `4` = list(1:4, 5:7)
)

# Page images (Step 2 and the check plots): full-resolution screenshots, 1920 x 1080 px,
# exported from Tobii Pro Lab (see stimuli/pages/README.md)
page_image <- function(p) here::here("stimuli", "pages", sprintf("page%d_full.png", p))

# Image analysis (Step 2): pixels darker than this (0 = black, 1 = white) count as ink.
# The background grey is ~0.83.
ink_threshold <- 0.7

# Drift correction (Step 3)
# How far may the correction move a reader's gaze? Every included recording passed
# calibration validation with accuracy < 0.5 degrees of visual angle (the preregistered
# criterion). On this setup (24-inch 1920 x 1080 monitor, 53.1 x 29.9 cm, viewed from
# about 65 cm, no chin rest), 0.5 degrees = 65 * tan(0.5 deg) = 0.57 cm = 0.019 of the
# screen height, i.e. about 0.45 of a line spacing. The correction is therefore limited
# to shifts of at most that size anywhere on the page.
# Why limit it at all: readers' fixations scatter by about +/- half a line, so without
# a limit a shift of a whole line can fit almost as well as no shift, and in testing
# that moved some well-aligned readers onto the wrong line (checked visually).
# Known limitation: without a chin rest, head movement can make the drift grow during
# reading (for some readers the lower paragraph is recorded up to a full line high);
# drift beyond the 0.5-degree bound is not corrected.
screen_height_cm    <- 29.9
viewing_distance_cm <- 65
accuracy_deg        <- 0.5
max_offset <- viewing_distance_cm * tan(accuracy_deg * pi / 180) / screen_height_cm
offset_step      <- 0.05  # in units of one line spacing
chain_dx         <- 0.10  # a horizontal jump larger than 10% of screen width ends a chain
chain_dy_lines   <- 0.6   # a vertical jump larger than 0.6 line spacings ends a chain
n_refine         <- 5     # rounds of fitting the linear drift model (Step 3c)

# Sentence mapping (Step 4): a fixation up to this many characters beyond the start or
# end of its line still counts as on that line's first/last word; further out = off text.
edge_tolerance_chars <- 3

# Short fixations: fixations shorter than this are discarded before any other step.
# 80 ms is a common lower bound in reading research (e.g., Serrano-Carot et al., 2025):
# shorter fixations are too brief for the text to be processed. Tobii Pro Lab's I-VT
# filter discards fixations under 60 ms by default, but the export still contains
# shorter ones (some of 1 ms). The rule also removes fixations cut short by a page
# change (Tobii's Validity = "Partial").
min_fixation_ms <- 80
# Long fixations: fixations longer than this are discarded as well. Upper bounds of
# 800-1,200 ms are common in reading research; fixations in reading typically last
# 200-250 ms (Rayner, 1998), so longer ones usually reflect lapses of attention or
# track loss rather than reading.
max_fixation_ms <- 1000

set.seed(2025)  # only used to pick readers for the check plots


# ---- Read data ----------------------------------------------------------------------

# Page number (1-4) from the TOI label. P01's page 2 is labelled "page(2)" while every
# other recording has "page(2) (1)", so only the digit is used.
page_from_toi <- \(toi) as.integer(str_extract(toi, "(?<=page\\()\\d"))

# Note: P01 (the first session) was shown page 2 from an earlier import of the page image
# (TOI/media "page(2)"; every other recording has "page(2) (1)"). Tobii Pro Lab's sentence
# AOIs were added to that image and P01 was re-exported; P01's rows in data/raw/tobii/fixations.tsv
# are that re-export (same fixations; page 2 now has sentence labels).
fix_raw <- read_tsv(fix_file, show_col_types = FALSE) |>
  janitor::clean_names() |>
  mutate(page = page_from_toi(toi))

# One row per sentence of the text (stimuli/sentences.tsv): page, order on the page,
# text (as in Tobii Pro Lab's AOIs), type (PO / TB target, Control = non-target) and
# number of words
sentences <- read_tsv(sentences_file, show_col_types = FALSE) |>
  transmute(page, sentence_index, aoi = text, type, number_of_units = n_words) |>
  arrange(page, sentence_index)
stopifnot(!anyDuplicated(select(sentences, page, sentence_index)))


# =====================================================================================
# Step 1. Rebuild the text layout of each page
# =====================================================================================
# The pages show the sentences as paragraphs, wrapped at `wrap_width` characters with
# ordinary word wrapping (a word that does not fit moves to the next line). Rebuilding
# this gives, for every line, the sentence that occupies each character column.

# Greedy word wrap, as a text editor does it
wrap_words <- function(words, width, indent) {
  lines <- character()
  current <- strrep(" ", indent)
  for (w in words) {
    candidate <- if (str_trim(current) == "") paste0(current, w) else paste(current, w)
    if (nchar(candidate) <= width || str_trim(current) == "") {
      current <- candidate
    } else {
      lines <- c(lines, current)
      current <- w
    }
  }
  c(lines, current)
}

# For one paragraph: wrap its text and record, for every character, which sentence it
# belongs to. Sentences within a paragraph are separated by one space.
layout_paragraph <- function(page, sentence_ids) {
  txt <- sentences |>
    filter(page == !!page, sentence_index %in% sentence_ids) |>
    mutate(aoi = str_replace_all(aoi, fixed(screen_text_fixes)))
  # sentence of every character in the paragraph text (the separating space belongs to
  # the preceding sentence)
  char_sentence <- unlist(map2(txt$aoi, txt$sentence_index, \(s, id) rep(id, nchar(s) + 1)))
  paragraph_text <- paste(txt$aoi, collapse = " ")
  indent <- if (page == 4) page4_indent else 0
  # split at single spaces; a double space leaves an empty "word", which wrap_words()
  # turns back into the extra space
  lines <- wrap_words(str_split(paragraph_text, " ")[[1]], wrap_width, indent)

  # Walk through the wrapped lines, keeping track of the position in the paragraph text
  pos <- 0   # characters of the paragraph text consumed so far
  map(seq_along(lines), \(i) {
    line <- lines[i]
    first <- if (i == 1) indent else 0             # indent spaces are not in the text
    n_text <- nchar(line) - first
    cols <- first + seq_len(n_text) - 1            # 0-based character columns
    ids  <- char_sentence[pos + seq_len(n_text)]
    pos <<- pos + n_text + 1                       # +1: the space replaced by the break
    tibble(line_in_par = i, col = cols,
           char = str_split(str_sub(line, first + 1), "")[[1]],
           sentence_index = ids)
  }) |> bind_rows()
}

layout <- map(1:4, \(p) {
  map(seq_along(paragraphs[[p]]), \(k) {
    layout_paragraph(p, paragraphs[[p]][[k]]) |> mutate(paragraph = k)
  }) |>
    bind_rows() |>
    mutate(page = p)
}) |>
  bind_rows() |>
  # number the lines on each page from the top
  group_by(page) |>
  mutate(line = consecutive_id(paragraph, line_in_par)) |>
  ungroup() |>
  select(page, line, col, char, sentence_index)

# Sanity check: every sentence's letters are laid out exactly once
letter_check <- layout |>
  filter(char != " ") |>
  count(page, sentence_index) |>
  left_join(sentences |> mutate(n_letters = nchar(str_remove_all(aoi, " "))),
            by = c("page", "sentence_index"))
stopifnot(nrow(letter_check) == nrow(sentences), all(letter_check$n == letter_check$n_letters))

line_lengths <- layout |>
  group_by(page, line) |>
  summarise(first_col = min(col), last_col = max(col), .groups = "drop")


# =====================================================================================
# Step 2. Locate the text lines and character positions on screen
# =====================================================================================
# In each page image, a text line is a band of rows containing dark (ink) pixels. Bands
# separated by only a few pixels (e.g., the dot of an "i" above its letter) are merged.
# The line's y position is the ink-weighted centre of its band (dominated by the
# letters' main body rather than ascenders and descenders); its right-most ink pixel
# gives the end of the line. Because the font is fixed-width, the right edge of a line is
#   right_edge = left_margin + (last_col + 1) * char_width,
# so a regression of right edges on line length (in characters) across all lines gives
# the character width and left margin. The fit also checks the reconstructed layout:
# if the wrap width or paragraphs were wrong, line lengths would not line up.

image_lines <- map(1:4, \(p) {
  img  <- readPNG(page_image(p))
  grey <- rowMeans(img[, , 1:3], dims = 2)          # average of R, G, B; 0 = black
  ink  <- grey < ink_threshold
  ink_rows <- which(rowSums(ink) > 0)
  # runs of ink rows; gaps smaller than 0.8% of the image height stay in one band
  bands <- split(ink_rows, cumsum(c(1, diff(ink_rows) > 0.008 * nrow(grey))))
  tibble(page = p,
         line = seq_along(bands),
         y = map_dbl(bands, \(r) sum(rowSums(ink[r, , drop = FALSE]) * (r - 0.5)) /
                       sum(ink[r, ])) / nrow(grey),                          # 0-1
         right_px = map_dbl(bands, \(r) max(which(colSums(ink[r, , drop = FALSE]) > 0))),
         width_px = ncol(grey))
}) |> bind_rows()

# The number of lines in each image must match the rebuilt layout
stopifnot(identical(count(image_lines, page)$n, count(line_lengths, page)$n))

geometry_fit <- lm(right_px ~ I(last_col + 1),
                   data = left_join(image_lines, line_lengths, by = c("page", "line")))
char_px     <- unname(coef(geometry_fit)[2])
char_width  <- char_px / image_lines$width_px[1]                       # proportion of screen
left_margin <- unname(coef(geometry_fit)[1]) / image_lines$width_px[1]
layout_error_px <- max(abs(resid(geometry_fit)))

cat(sprintf(paste0("Steps 1-2: layout of %d lines rebuilt; line ends match the images within ",
                   "%.1f px (one character = %.1f px)\n"),
            nrow(line_lengths), layout_error_px, char_px))
# every line end within half a character (the remaining error is glyph shape: a line
# ending in "," or ")" has its last ink pixel further left than one ending in a letter)
stopifnot(layout_error_px < char_px / 2)

# Line spacing (distance between neighbouring lines within a paragraph)
line_spacing <- image_lines |>
  group_by(page) |>
  summarise(spacing = median(diff(y)))

line_y <- select(image_lines, page, line, y)


# =====================================================================================
# Step 3. Drift correction: assign each fixation to a text line
# =====================================================================================
# (a) Vertical offset. For each reader and page, find the vertical shift that, when
#     removed from the recorded gaze, puts the fixations closest to the text lines.
#     The cost of a candidate shift is the summed squared distance from each fixation
#     to its nearest line, capped at one line spacing so that stray fixations (margins)
#     cannot dominate. Paragraph gaps and the first and last lines make the best shift
#     unambiguous ... in principle. In practice, fixations scatter about +/- half a
#     line, so the search is limited to shifts of at most `max_offset` (the 0.5-degree
#     calibration bound, about 0.45 lines) to rule out whole-line errors.
# (b) Chains. Consecutive fixations that move along the same line (small horizontal
#     and vertical steps) form a chain. A chain ends at a large horizontal jump (such as
#     a return sweep to the next line) or a vertical jump of more than `chain_dy_lines`.
#     Each chain is assigned as a whole to the line nearest its median corrected
#     position, so a single fixation that drifts towards the neighbouring line stays on
#     the line being read.
# (c) Linear drift. The recorded height is often not just shifted: the error can grow
#     down the page (e.g., top paragraph aligned, bottom paragraph recorded too high)
#     or across it (tilt). So after (a) and (b), a linear model is fitted:
#         recorded_y = a + b * line_y + c * x
#     using fixations whose chain lies within half a line of its assigned line. The
#     model is inverted to correct the gaze, and (b) is repeated with the corrected
#     positions. This is done `n_refine` times. If the fitted stretch (b) or tilt (c) is
#     implausible, the simple offset from (a) is kept instead.

# (a) vertical offset for one reader x page
estimate_offset <- function(y, lines_y, spacing) {
  shifts <- seq(-max_offset, max_offset, by = offset_step * spacing)
  cost <- map_dbl(shifts, \(s) {
    d <- map_dbl(y - s, \(yy) min(abs(yy - lines_y)))
    sum(pmin(d, spacing)^2)
  })
  shifts[which.min(cost)]
}

# (b) chains: returns a chain number for each fixation (in time order)
make_chains <- function(x, y, spacing) {
  new_chain <- c(TRUE, abs(diff(x)) > chain_dx | abs(diff(y)) > chain_dy_lines * spacing)
  cumsum(new_chain)
}

# Reader x page combinations to process: those Tobii labelled, plus any pages listed in
# `relabel_pages` (pages without Tobii labels whose sentences should be assigned from the
# rebuilt layout alone; none at present).
relabel_pages <- tibble(recording = character(), page = integer())

# Pages with fixations that are deliberately not used (none at present).
skip_pages <- tibble(recording = character(), page = integer(), reason = character())

labelled_pages <- fix_raw |>
  group_by(recording, page) |>
  summarise(n_labelled = sum(!is.na(aoi)), .groups = "drop") |>
  filter(n_labelled > 0) |>
  bind_rows(relabel_pages)

# Any other recording x page with fixations but no Tobii labels would be dropped
# silently; stop instead, so it can be checked and added to relabel_pages if appropriate
unlabelled <- fix_raw |>
  distinct(recording, page) |>
  anti_join(labelled_pages, by = c("recording", "page")) |>
  anti_join(skip_pages, by = c("recording", "page"))
if (nrow(unlabelled) > 0) {
  stop("Pages with fixations but no Tobii labels: ",
       paste(unlabelled$recording, unlabelled$page, collapse = "; "))
}

fix <- fix_raw |>
  semi_join(labelled_pages, by = c("recording", "page")) |>
  # fixations outside the screen cannot be on the text
  filter(between(fixation_point_x, 0, 1), between(fixation_point_y, 0, 1)) |>
  arrange(recording, page, event_index)
n_short <- sum(fix$duration < min_fixation_ms)
n_long  <- sum(fix$duration > max_fixation_ms)
message(sprintf("Discarded %d fixations shorter than %d ms (%.1f%%) and %d longer than %d ms (%.2f%%)",
                n_short, min_fixation_ms, 100 * n_short / nrow(fix),
                n_long, max_fixation_ms, 100 * n_long / nrow(fix)))
fix <- filter(fix, between(duration, min_fixation_ms, max_fixation_ms))

# (b) applied to one reader x page: chains on the corrected positions, each chain
# assigned to its nearest line
assign_lines <- function(d, ly, sp) {
  d |>
    mutate(chain = make_chains(fixation_point_x, y_corrected, sp)) |>
    group_by(chain) |>
    mutate(line = which.min(abs(median(y_corrected) - ly)),
           # distance of the chain from its line, in line spacings; used to fit the
           # drift model and to drop chains that are not on any text line
           chain_dist = min(abs(median(y_corrected) - ly)) / sp) |>
    ungroup()
}

correct_drift <- function(d, ly, sp) {
  # (a) starting point: best single vertical offset
  offset <- estimate_offset(d$fixation_point_y, ly, sp)
  d <- d |> mutate(y_corrected = fixation_point_y - offset)
  d <- assign_lines(d, ly, sp)
  drift <- c(a = offset, b = 1, c = 0)

  # (c) refine with the linear drift model
  for (i in seq_len(n_refine)) {
    fit_data <- d |>
      filter(chain_dist < 0.5) |>
      mutate(line_y = ly[line])
    if (nrow(fit_data) < 20 || n_distinct(fit_data$line) < 3) break
    m <- lm(fixation_point_y ~ line_y + fixation_point_x, data = fit_data)
    cf <- unname(coef(m))
    # plausibility: stretch within 20%, tilt under one line across the screen, and the
    # implied shift nowhere on the page larger than `max_offset` (0.5 degrees)
    implied_shift <- outer(range(ly), c(0, 1), \(yy, xx) cf[1] + (cf[2] - 1) * yy + cf[3] * xx)
    if (abs(cf[2] - 1) > 0.2 || abs(cf[3]) > sp ||
        max(abs(implied_shift)) > max_offset) break
    drift <- c(a = cf[1], b = cf[2], c = cf[3])
    d <- d |>
      mutate(y_corrected = (fixation_point_y - drift[["a"]] -
                              drift[["c"]] * fixation_point_x) / drift[["b"]]) |>
      assign_lines(ly, sp)
  }
  d |> mutate(drift_a = drift[["a"]], drift_b = drift[["b"]], drift_c = drift[["c"]],
              y_offset = offset)
}

fix <- fix |>
  group_by(recording, page) |>
  group_modify(\(d, key) {
    correct_drift(d,
                  ly = line_y$y[line_y$page == key$page],
                  sp = line_spacing$spacing[line_spacing$page == key$page])
  }) |>
  ungroup()


# =====================================================================================
# Step 4. From line + horizontal position to sentence
# =====================================================================================
# The character column under a fixation is (x - left_margin) / char_width. A fixation
# on a space is given the sentence of the nearest letter on that line (ties go to the
# earlier letter). Fixations more than `edge_tolerance_chars` beyond either end of the
# line, or in chains more than half a line from any text line, are off the text.

# `what` = which property of the nearest letter to return (its sentence)
nearest_letter <- function(page, line, col, what) {
  letters <- layout |>
    filter(page == !!page, line == !!line, char != " ") |>
    arrange(col)
  idx <- map_int(col, \(cc) which.min(abs(letters$col - cc) + 1e-6 * (letters$col > cc)))
  letters[[what]][idx]
}
sentence_at <- function(page, line, col) nearest_letter(page, line, col, "sentence_index")

fix <- fix |>
  left_join(line_lengths, by = c("page", "line")) |>
  mutate(col = floor((fixation_point_x - left_margin) / char_width),
         on_text = chain_dist <= 0.5 &
           col >= first_col - edge_tolerance_chars &
           col <= last_col + edge_tolerance_chars) |>
  group_by(page, line) |>
  mutate(sentence_corrected = if_else(
    on_text,
    sentence_at(first(page), first(line), pmin(pmax(col, first_col), last_col)),
    NA_real_)) |>
  ungroup()

# Tobii's own label, as a sentence number, for comparison
fix <- fix |>
  left_join(select(sentences, page, aoi, sentence_tobii = sentence_index),
            by = c("page", "aoi"))


# =====================================================================================
# Step 5. Where does reading start on each page?
# =====================================================================================
# Reading starts at the first fixation on the page's first sentence. Fixations before
# that (the landing on the page) still count towards total time but not towards any
# pass-based measure. If sentence 1 was never fixated, reading starts at the first
# fixation on the earliest sentence the reader did fixate.

fix_text <- fix |>
  filter(!is.na(sentence_corrected)) |>
  arrange(recording, page, event_index) |>
  group_by(recording, page) |>
  mutate(start_sentence = min(sentence_corrected),
         reading = cumsum(sentence_corrected == start_sentence) > 0) |>
  ungroup()


# =====================================================================================
# Step 6. Sentence-level measures
# =====================================================================================
# A "visit" is a sequence of consecutive fixations on the same sentence.

measures_one_page <- function(d) {
  # d: all on-text fixations of one reader on one page, in time order
  total <- d |>
    group_by(sentence_index = sentence_corrected) |>
    summarise(total_duration = sum(duration),
              # fixations before reading started on this page (Step 5)
              landing_duration = sum(duration[!reading]), .groups = "drop")

  r <- filter(d, reading)
  visits <- tibble(s = r$sentence_corrected, dur = r$duration) |>
    mutate(visit = consecutive_id(s)) |>
    group_by(visit) |>
    summarise(s = first(s), dur = sum(dur), .groups = "drop") |>
    # furthest sentence reached before this visit began
    mutate(furthest_before = lag(cummax(s), default = 0))

  map(sort(unique(d$sentence_corrected)), \(k) {
    first_visit <- which(visits$s == k)[1]

    # Skipped on first pass: never visited after reading started, or a later sentence
    # had already been read when it was first visited
    if (is.na(first_visit) || visits$furthest_before[first_visit] > k) {
      return(tibble(sentence_index = k, first_pass_duration = NA_real_,
                    first_pass_regression = NA_integer_,
                    selective_regression_path = NA_real_, regressed_in = NA_integer_))
    }

    next_s <- if (first_visit < nrow(visits)) visits$s[first_visit + 1] else NA
    # regression-path window: from the first visit up to (not including) the first visit
    # to a later sentence, or to the end of the page
    first_later <- which(visits$s > k & seq_len(nrow(visits)) > first_visit)[1]
    window <- first_visit:(if (is.na(first_later)) nrow(visits) else first_later - 1)
    # later visits to the sentence
    later_visits <- which(visits$s == k & seq_len(nrow(visits)) > first_visit)

    tibble(sentence_index = k,
           first_pass_duration = visits$dur[first_visit],
           # no earlier text exists for sentence 1, so a regression is impossible there
           first_pass_regression = if (is.na(next_s) || k == 1) NA_integer_ else
             as.integer(next_s < k),
           selective_regression_path = sum(visits$dur[window][visits$s[window] == k]),
           # a later visit that arrives from a later sentence = a regression into it
           regressed_in = as.integer(any(visits$s[later_visits - 1] > k)))
  }) |>
    bind_rows() |>
    full_join(total, by = "sentence_index")
}

derived <- fix_text |>
  group_by(recording, page) |>
  group_modify(\(d, key) measures_one_page(d)) |>
  ungroup() |>
  # time on the sentence after the reader first moved on to later text
  mutate(rereading_duration = total_duration - landing_duration - selective_regression_path)


# =====================================================================================
# Step 7. Save, with Tobii's values alongside, and print checks
# =====================================================================================

# the relabelled pages, which are missing from that export (their Tobii values are NA)
# One row per processed recording x page x sentence (the page's sentences from
# stimuli/sentences.tsv)

out <- labelled_pages |>
  select(recording, page) |>
  left_join(distinct(fix_raw, recording, participant, group, toi, page),
            by = c("recording", "page")) |>
  inner_join(sentences, by = "page") |>
  select(recording, participant, group, toi, page, aoi, type, sentence_index,
         number_of_units) |>
  arrange(recording, page, sentence_index) |>
  left_join(derived, by = c("recording", "page", "sentence_index")) |>
  mutate(
    # Pages that were not processed have no derived values (none at present). On
    # processed pages, a sentence that was never fixated has zero time and no passes.
    derived_available = paste(recording, page) %in%
      paste(labelled_pages$recording, labelled_pages$page),
    total_duration = if_else(derived_available, replace_na(total_duration, 0), NA_real_),
    landing_duration = if_else(derived_available, replace_na(landing_duration, 0), NA_real_)
  ) |>
  select(recording:number_of_units, total_duration, landing_duration,
         selective_regression_path, rereading_duration, regressed_in,
         first_pass_duration, first_pass_regression, derived_available)

write_tsv(out, out_file)

# Fixation-level positions and assignments (for figures and checks)
fix |>
  left_join(select(fix_text, recording, page, event_index, reading),
            by = c("recording", "page", "event_index")) |>
  transmute(recording, participant, page, event_index, duration,
            x = fixation_point_x, y_recorded = fixation_point_y, y_corrected,
            line, sentence_tobii, sentence_corrected,
            reading = replace_na(reading, FALSE)) |>
  write_tsv(fixations_file)

# Sentence regions: for every line, the horizontal span of each sentence on it (from the
# first to the last letter, plus half a character on each side) and the line's vertical
# band (half a line spacing above and below its centre)
layout |>
  filter(char != " ") |>
  group_by(page, line, sentence_index) |>
  summarise(first_col = min(col), last_col = max(col), .groups = "drop") |>
  left_join(line_y, by = c("page", "line")) |>
  left_join(line_spacing, by = "page") |>
  left_join(select(sentences, page, sentence_index, type), by = c("page", "sentence_index")) |>
  transmute(page, line, sentence_index, type,
            x0 = left_margin + (first_col - 0.5) * char_width,
            x1 = left_margin + (last_col + 1.5) * char_width,
            y0 = y - spacing / 2, y1 = y + spacing / 2) |>
  write_tsv(regions_file)

# ---- Checks ------------------------------------------------------------------------
cat("\n==== Checks ====\n")

# Relabelled pages (P01 page 2): do the fixations line up with the rebuilt text lines as
# well as other readers' fixations on the same page? Compared with every other reader on
# that page: share of fixations assigned to a sentence, median distance of fixation
# chains from their line (in line spacings), and the size of the vertical correction.
align <- fix |>
  group_by(recording, page) |>
  summarise(assigned = mean(!is.na(sentence_corrected)),
            chain_dist = median(chain_dist),
            offset_lines = abs(first(y_offset)) / line_spacing$spacing[first(page)],
            .groups = "drop")
for (k in seq_len(nrow(relabel_pages))) {
  rp <- relabel_pages[k, ]
  others <- filter(align, page == rp$page, recording != rp$recording)
  me <- filter(align, page == rp$page, recording == rp$recording)
  stopifnot(nrow(me) == 1)
  cat(sprintf(paste0("Relabelled %s page %d: assigned %.1f%% (others: median %.1f%%), chain distance %.2f ",
                     "lines (others: median %.2f, %.0fth percentile), offset %.2f lines (others: median %.2f)\n"),
              rp$recording, rp$page, 100 * me$assigned, 100 * median(others$assigned),
              me$chain_dist, median(others$chain_dist),
              100 * mean(others$chain_dist <= me$chain_dist),
              me$offset_lines, median(others$offset_lines)))
}

drift_summary <- fix |>
  distinct(recording, page, y_offset, drift_a, drift_b, drift_c) |>
  mutate(sp = line_spacing$spacing[page])
cat(sprintf("Initial vertical offset (median across readers x pages): %.2f line spacings %s\n",
            median(drift_summary$y_offset / drift_summary$sp),
            "(negative = recorded gaze was above the text)"))
cat(sprintf("Linear drift model: stretch b median %.3f (IQR %.3f-%.3f); tilt c median %.3f line spacings across the screen\n",
            median(drift_summary$drift_b), quantile(drift_summary$drift_b, .25),
            quantile(drift_summary$drift_b, .75), median(drift_summary$drift_c / drift_summary$sp)))

n_on <- sum(!is.na(fix$sentence_corrected))
cat(sprintf(paste0("Fixations on screen: %d; assigned to a sentence after correction: %d (%.1f%%); ",
                   "labelled by Tobii: %d (%.1f%%)\n"),
            nrow(fix), n_on, 100 * n_on / nrow(fix),
            sum(!is.na(fix$sentence_tobii)), 100 * mean(!is.na(fix$sentence_tobii))))

agree <- fix |> filter(!is.na(sentence_tobii), !is.na(sentence_corrected))
cat(sprintf("Fixations where the corrected and Tobii sentence agree: %.1f%%\n",
            100 * mean(agree$sentence_tobii == agree$sentence_corrected)))

# Between-sentence moves: a move to an earlier sentence that goes rightward along the
# same text line is impossible in real reading (earlier text on a line is to the left),
# so its rate shows how much label noise remains.
transition_check <- function(d, s_col) {
  d |>
    filter(!is.na(.data[[s_col]])) |>
    arrange(recording, page, event_index) |>
    group_by(recording, page) |>
    mutate(next_s = lead(.data[[s_col]]),
           dx = lead(fixation_point_x) - fixation_point_x,
           dy = lead(fixation_point_y) - fixation_point_y,
           sp = line_spacing$spacing[first(page)]) |>
    ungroup() |>
    filter(!is.na(next_s), next_s < .data[[s_col]]) |>
    summarise(moves_to_earlier_sentence = n(),
              share_rightward_same_line = mean(dx > 0.01 & abs(dy) < 0.5 * sp))
}
cat("\nMoves to an earlier sentence that go rightward along the same line (label noise):\n")
print(bind_rows(Tobii = transition_check(fix, "sentence_tobii"),
                Corrected = transition_check(fix, "sentence_corrected"), .id = "labels"))

cat("\nTarget sentences (PO / TB) with any fixation:\n")
print(out |>
        filter(type %in% c("PO", "TB"), total_duration > 0) |>
        summarise(first_pass_recorded = mean(!is.na(first_pass_duration)),
                  fp_regression_rate  = mean(first_pass_regression, na.rm = TRUE),
                  median_first_pass   = median(first_pass_duration, na.rm = TRUE),
                  median_total        = median(total_duration, na.rm = TRUE)) |>
        pivot_longer(everything()) |>
        mutate(value = round(value, 3)),
      n = Inf)

# Landing: on how many pages did the first fixation on the text fall below sentence 1?
cat("\nPages where the first fixation on the text was not on sentence 1:\n")
print(fix |>
        filter(!is.na(sentence_corrected)) |>
        group_by(recording, page) |>
        summarise(first_sentence = sentence_corrected[which.min(event_index)], .groups = "drop") |>
        summarise(pages = n(), landed_below_sentence_1 = mean(first_sentence > 1)))

# =====================================================================================
# Step 8. Overlay plots for visual checking
# =====================================================================================
# For a few randomly chosen readers, each page is drawn with the fixations twice:
# left = recorded position coloured by Tobii's sentence label; right = drift-corrected
# position coloured by the corrected sentence. Grey = not assigned to any sentence.
# Consistent colours along each line on the right mean the correction worked.

dir.create(check_dir, showWarnings = FALSE, recursive = TRUE)
# four random readers, plus any reader with a page labelled from the layout only
check_recordings <- union(sample(unique(fix$recording), 4), relabel_pages$recording)

# one colour per sentence (pages have up to 11 sentences): viridis, reordered so that
# neighbouring sentences differ strongly in lightness (colour-blind safe; no 11-colour
# categorical palette is)
sentence_palette <- viridisLite::viridis(11, end = 0.92)[c(1, 7, 3, 9, 5, 11, 2, 8, 4, 10, 6)]

for (rec in check_recordings) {
  for (p in 1:4) {
    d <- filter(fix, recording == rec, page == p)
    if (nrow(d) == 0) next
    img <- readPNG(page_image(p))
    plot_data <- bind_rows(
      d |> transmute(panel = "Recorded gaze, Tobii labels", x = fixation_point_x,
                     y = fixation_point_y, sentence = sentence_tobii, duration),
      d |> transmute(panel = "Drift-corrected gaze, corrected labels", x = fixation_point_x,
                     y = y_corrected, sentence = sentence_corrected, duration)
    ) |>
      mutate(panel = fct_inorder(panel),
             sentence = factor(sentence, levels = 1:11))
    g <- ggplot(plot_data, aes(x, 1 - y)) +
      annotation_raster(img, 0, 1, 0, 1) +
      geom_path(colour = "grey40", alpha = 0.3, linewidth = 0.3) +
      geom_point(aes(colour = sentence, size = duration), alpha = 0.75) +
      scale_colour_manual(values = sentence_palette, na.value = "grey55", drop = FALSE,
                          name = "Sentence") +
      scale_size_area(max_size = 3.5, guide = "none") +
      scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) +
      scale_y_continuous(limits = c(0, 1), expand = c(0, 0)) +
      facet_wrap(~ panel, ncol = 2) +
      coord_fixed(9 / 16) +
      labs(title = sprintf("%s, page %d (drift model: recorded y = %.3f + %.3f * line y + %.3f * x)",
                           rec, p, first(d$drift_a), first(d$drift_b), first(d$drift_c))) +
      theme_void(base_size = 11) +
      theme(strip.text = element_text(face = "bold"), legend.position = "bottom")
    ggsave(file.path(check_dir, sprintf("%s_page%d.png", rec, p)), g,
           width = 16, height = 5.4, dpi = 110, bg = "white")
  }
}
cat(sprintf("\nOverlay plots for %s saved in %s/\n",
            paste(check_recordings, collapse = ", "), check_dir))
