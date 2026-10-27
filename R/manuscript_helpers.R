# Functions the manuscript needs (text helpers, page figures), kept here so that the
# manuscript does not re-run the analysis documents. The data they use (preq_by_cond,
# regions, region_labels) come from data/derived/manuscript_inputs.rds
# (scripts/manuscript_inputs.R). Requires R/setup.R (topic_cols, fmt_num).

# ---- Prequestion scores (preq_by_cond from data/derived/manuscript_inputs.rds) -------
pq_pct <- \(x) paste0(fmt_num(100 * x, 1), "%")
PQ <- function(cnd, col) pq_pct(filter(preq_by_cond, condition == cnd)[[col]])

# ---- Page figures: sentence regions on the four text pages ---------------------------
role_cols <- c(`Polio target` = unname(topic_cols["Polio"]),
               `TB target` = unname(topic_cols["TB"]), `Other sentence` = "grey45")
# label_size: size of the sentence-number labels (mm)
page_panel <- function(p, title = sprintf("Page %d", p), label_size = 2.6) {
  img <- png::readPNG(here::here("stimuli", "pages", sprintf("page%d_full.png", p)))
  r <- filter(regions, page == p)
  ggplot(r) +
    annotation_raster(img, 0, 1, 0, 1) +
    geom_rect(aes(xmin = x0, xmax = x1, ymin = 1 - y1, ymax = 1 - y0, colour = role,
                  fill = role), alpha = 0.12, linewidth = 0.35) +
    geom_label(data = filter(region_labels, page == p),
               aes(x = x0, y = 1 - (y0 + y1) / 2, label = sentence_index, colour = role),
               size = label_size, fontface = "bold", label.padding = unit(0.08, "lines"),
               hjust = 1.1,
               show.legend = FALSE) +
    # one legend (fill), shared by all four panels
    scale_colour_manual(values = role_cols, guide = "none", drop = FALSE) +
    scale_fill_manual(values = role_cols, name = NULL, drop = FALSE,
                      guide = guide_legend(override.aes = list(alpha = 0.35,
                                                               colour = role_cols))) +
    scale_x_continuous(limits = c(-0.02, 1), expand = c(0, 0)) +
    scale_y_continuous(limits = c(0, 1), expand = c(0, 0)) +
    coord_fixed(9 / 16) +
    labs(title = title) +
    theme_void(base_size = 11) +
    theme(plot.title = element_text(face = "bold")) +
    # only page 2 contains all three sentence types, so only its legend is kept
    (if (p == 2) NULL else guides(fill = "none"))
}

# ---- Eye-movement measures figure: a schematic reading example ------------------------
# A made-up two-line text (a target sentence between a preceding and a next sentence) with
# a numbered fixation sequence, coloured by the measure each fixation counts towards, and
# below it the measures, which fixations of the example each one sums, and the model.
measures_schematic <- function() {
  lines <- c("the virus spread quickly. Children who drank",
             "dirty water fell ill. Wells were then sealed.")
  # target sentence: from "Children" (line 1) to "ill." (line 2)
  tgt_start <- str_locate(lines[1], "Children")[1]
  tgt_end   <- str_locate(lines[2], "ill\\.")[2]
  line_y <- c(2.25, 0.9)

  chars <- map2(lines, seq_along(lines), \(s, l) tibble(
    line = l, col = seq_len(nchar(s)), char = strsplit(s, "")[[1]])) |>
    bind_rows() |>
    mutate(y = line_y[line],
           target = (line == 1 & col >= tgt_start) | (line == 2 & col <= tgt_end))

  # fixations: word they land on, line, and what they count towards for the target
  word_x <- \(l, w) { p <- str_locate(lines[l], fixed(w)); mean(p) }
  fix <- tribble(
    ~n, ~line, ~word,      ~role,
    1,  1,     "virus",    "other",
    2,  1,     "quickly",  "other",
    3,  1,     "Children", "srp",
    4,  1,     "drank",    "srp",
    5,  2,     "dirty",    "srp",
    6,  1,     "spread",   "other",
    7,  2,     "water",    "srp",
    8,  2,     "ill.",     "srp",
    9,  2,     "Wells",    "other",
    10, 2,     "sealed.",  "other",
    11, 1,     "who",      "reread",
    12, 2,     "fell",     "reread"
  ) |>
    mutate(x = map2_dbl(line, word, word_x), y = line_y[line] + 0.36)

  sacc <- tibble(x = head(fix$x, -1), y = head(fix$y, -1),
                 xend = tail(fix$x, -1), yend = tail(fix$y, -1),
                 from = head(fix$n, -1), l0 = head(fix$line, -1), l1 = tail(fix$line, -1)) |>
    mutate(kind = case_when(from == 10 ~ "regin",                 # from later text into target
                            l1 < l0 | (l1 == l0 & xend < x) ~ "regout",
                            l1 > l0 ~ "sweep",
                            TRUE ~ "fwd"))

  key <- tribble(
    ~role,    ~measure,                              ~type,    ~example,                          ~model,
    "srp",    "Selective regression-path duration",  "Local",  "3 + 4 + 5 + 7 + 8",              "Ex-Gaussian (\u03bc, \u03c4)",
    "total",  "Total gaze duration",                 "Global", "3 + 4 + 5 + 7 + 8 + 11 + 12",    "Ex-Gaussian (\u03bc, \u03c4)",
    "regin",  "Regression-in (look-back)",           "Global", "1 (move from 10 to 11)",         "Logistic",
    "reread", "Re-reading time",                     "Global", "11 + 12",                        "Gamma (if re-read)",
    "other",  "Fixation on another sentence",        "",       "not counted for the target",     ""
  ) |> mutate(y = -0.05 - 0.3 * (row_number() - 1))
  key_head <- tibble(x = c(2.2, 21, 26, 41.8), label = c("Measure", "Type", "Fixations in the example", "Analysed as"))
  head_y <- 0.32

  role_fill <- c(srp = "#2b6cb0", reread = "#dd6b20", other = "white", total = "#fbe9a6", regin = "#c53030")
  role_text <- c(srp = "white", reread = "white", other = "grey25", total = "grey25", regin = "white")
  shrink <- \(d, k = 0.9) d |> mutate(dx = xend - x, dy = yend - y, len = sqrt(dx^2 + (dy * 8)^2),
                                     x = x + dx * k / len, xend = xend - dx * k / len,
                                     y = y + dy * k / len, yend = yend - dy * k / len)
  arr <- arrow(length = unit(0.12, "cm"), type = "closed")

  ggplot() +
    # target sentence highlight
    geom_tile(data = filter(chars, target), aes(col, y), width = 1, height = 0.5,
              fill = "#fbe9a6") +
    geom_text(data = chars, aes(col, y, label = char), family = "mono", size = 4.3) +
    geom_curve(data = shrink(filter(sacc, kind == "fwd")), aes(x, y, xend = xend, yend = yend),
               curvature = -0.45, colour = "grey45", linewidth = 0.4, arrow = arr) +
    geom_curve(data = shrink(filter(sacc, kind == "regout")), aes(x, y, xend = xend, yend = yend),
               curvature = 0.15, colour = "grey45", linewidth = 0.5, linetype = "22", arrow = arr) +
    geom_curve(data = shrink(filter(sacc, kind == "sweep")), aes(x, y, xend = xend, yend = yend),
               curvature = 0, colour = "grey60", linewidth = 0.4, linetype = "13", arrow = arr) +
    geom_curve(data = shrink(filter(sacc, kind == "regin")), aes(x, y, xend = xend, yend = yend),
               curvature = 0.25, colour = "#c53030", linewidth = 0.8, linetype = "42", arrow = arr) +
    geom_point(data = fix, aes(x, y, fill = role), shape = 21, size = 5.2, stroke = 0.4,
               colour = "grey25") +
    geom_text(data = fix, aes(x, y, label = n, colour = role), size = 2.7, fontface = "bold") +
    annotate("text", x = 4.4, y = 1.66, label = "brief return\nto earlier text", hjust = 1,
             size = 2.8, colour = "grey35", fontface = "italic", lineheight = 0.9) +
    annotate("text", x = 44, y = 1.75, label = "regression-in\n(look-back)", hjust = 0,
             size = 2.8, colour = "#c53030", fontface = "italic", lineheight = 0.9) +
    annotate("text", x = c(12.5, (tgt_start + 44) / 2, 11, 32.5), y = c(1.93, 1.93, 0.58, 0.58),
             label = c("preceding sentence", "target sentence", "target sentence (cont.)", "next sentence"),
             size = 2.6, colour = "grey40") +
    # key: one row per measure
    geom_text(data = key_head, aes(x, head_y, label = label), hjust = 0, size = 3,
              fontface = "bold") +
    annotate("segment", x = 0.3, xend = 52, y = head_y - 0.15, yend = head_y - 0.15,
             linewidth = 0.3) +
    annotate("segment", x = 0.3, xend = 52, y = min(key$y) - 0.17, yend = min(key$y) - 0.17,
             linewidth = 0.3) +
    geom_point(data = key, aes(1, y, fill = role), shape = 21, size = 3.4, stroke = 0.4,
               colour = "grey25") +
    geom_text(data = key, aes(2.2, y, label = measure), hjust = 0, size = 3) +
    geom_text(data = key, aes(21, y, label = type), hjust = 0, size = 3) +
    geom_text(data = key, aes(26, y, label = example), hjust = 0, size = 3) +
    geom_text(data = key, aes(41.8, y, label = model), hjust = 0, size = 3) +
    scale_fill_manual(values = role_fill, guide = "none") +
    scale_colour_manual(values = role_text, guide = "none") +
    coord_cartesian(xlim = c(0, 52), ylim = c(-1.35, 2.95), clip = "off") +
    theme_void()
}
