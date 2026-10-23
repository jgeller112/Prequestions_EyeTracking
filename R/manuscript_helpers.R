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
