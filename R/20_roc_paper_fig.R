# R/20_roc_paper_fig.R
# Dual-view ROC figure (Figure 2): the nested reporting rules of Table 2 read
# from both ends at once.
#
# A reporting rule does two things at once. It declares a repetition usable as
# effect evidence, and in doing so withholds every repetition it does not
# declare usable. Scored one way it is a detector of trustworthy estimates;
# scored the other way it is a detector of bias-dominated ones. The rules were
# written in the first language ("declare usable when ...") but were previously
# only reported in the second ("sensitivity for bias dominance"), which is why
# the definitions and the numbers read in opposite directions. Both readings are
# shown here:
#
#   Panel A  effect-dominated view  reference standard = truly effect-dominated
#                                   a positive call is "declared usable"
#   Panel B  bias-dominated view    reference standard = truly bias-dominated
#                                   a positive call is "withheld"
#
# The two panels are not mirror images. Truth has three levels
# (effect-dominated / mixed / bias-dominated, 18.8% / 28.7% / 52.5%), and the
# mixed zone falls outside the positive group of BOTH views, so it drags on both
# panels at once. That is the reason each view needs its own four numbers.
#
# The curves come from the continuous predictors (calibrated P alone, BAF-hat
# alone, BAF-hat with its interval half-width); the rules are discrete and appear
# as operating points on those curves' axes. All coordinates are precomputed by
# R/23_dual_view_metrics.R so that the figure and Table 2 cannot disagree.
#
# Journal style: no in-image title (the caption lives in the figure legend),
# panel letters and a one-line reading note inside each panel, shared legend.
#
# Input : output/tables/v39_dual_view_roc.csv
#         output/tables/v39_dual_view_auc.csv
#         output/tables/v39_dual_view_strategy.csv
# Output: output/figures/v39/figP2C_roc_paper.png   (landscape, 9.0 x 4.0 in)
#         output/tables/v39_roc_paper_auc.txt       (AUCs, both views)

suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
})
source("R/00_config.R")

V38_FIG <- file.path(FIG_DIR, "v39")
dir.create(V38_FIG, showWarnings = FALSE, recursive = TRUE)

cat("[1] loading precomputed dual-view curves and metrics ...\n")
ROC <- read.csv(file.path(TAB_DIR, "v39_dual_view_roc.csv"),  stringsAsFactors = FALSE)
AUC <- read.csv(file.path(TAB_DIR, "v39_dual_view_auc.csv"),  stringsAsFactors = FALSE)
ST  <- read.csv(file.path(TAB_DIR, "v39_dual_view_strategy.csv"), stringsAsFactors = FALSE)

# Fixed curve order and colours; the factor levels, not the row order, decide
# the legend, so a change in R/23's output order cannot reshuffle the colours.
SCORE_LAB <- c("Calibrated P alone", "BAF-hat alone", "BAF-hat + CI half-width")
CURVE_COL <- c(COLOR_OHDSI, COLOR_COMPETITIVE, "#4B5BD6")
names(CURVE_COL) <- SCORE_LAB
ROC$score <- factor(ROC$score, levels = SCORE_LAB)
AUC$score <- factor(AUC$score, levels = SCORE_LAB)
stopifnot(nlevels(ROC$score) == 3L, !any(is.na(ROC$score)),
          nlevels(AUC$score) == 3L, !any(is.na(AUC$score)),
          setequal(ST$rule, c("R0", "R1", "R2", "R3", "R4", "C1", "C2")))

writeLines(
  paste(sprintf("%-24s ED view %.4f | BD view %.4f",
                as.character(AUC$score), AUC$auc_ed, AUC$auc_bd),
        collapse = "\n"),
  file.path(TAB_DIR, "v39_roc_paper_auc.txt"))
print(AUC, digits = 4)

## -- operating points: one row per rule, coordinates in both views -----------
# x = 1 - specificity, y = sensitivity, always within the view's own truth
# groups. Nudges are per panel because the two panels crowd in different places.
pts <- data.frame(
  lab  = ST$rule,
  x_ed = 1 - ST$spec_ed / 100, y_ed = ST$sens_ed / 100,
  x_bd = 1 - ST$spec_bd / 100, y_bd = ST$sens_bd / 100,
  stringsAsFactors = FALSE)
# Panel A: R3 and C2 sit almost on top of each other near x = 0.19; R0 is hard
# against the top-right corner and its label has to come back inside.
pts$nx_a <- c(-0.030, 0.022,  0.022, -0.024,  0.022,  0.020, 0.020)
pts$ny_a <- c(-0.030, 0.000, -0.030, -0.030,  0.000,  0.000, 0.032)
pts$hj_a <- c( 1,     0,      0,      1,      0,      0,     0)
# Panel B: R3 and C2 overlap near the top; R0 sits on the diagonal at the left.
pts$nx_b <- c( 0.022, 0.022,  0.022,  0.022,  0.022,  0.020, 0.024)
pts$ny_b <- c( 0.000, 0.000,  0.000,  0.026, -0.026,  0.000, -0.030)
pts$hj_b <- c( 0,     0,      0,      0,      0,      0,     0)

## -- in-panel AUC table, lower right of each panel --------------------------
# Two aligned columns: the score name on the left, its AUC on the right. Kept
# inside the panel rather than in the legend because the two panels have
# different AUCs for the same curve, which is itself a finding.
mk_auc <- function(col) {
  data.frame(
    x   = 0.40,
    y   = c(0.36, 0.27, 0.18, 0.09),
    lab = c("Area under curve", as.character(AUC$score)),
    val = c("", sprintf("%.3f", AUC[[col]])),
    stringsAsFactors = FALSE)
}

th <- theme_minimal(base_size = 9) +
  theme(panel.grid.minor = element_blank(),
        panel.grid.major = element_line(colour = COLOR_GRID),
        text = element_text(colour = COLOR_TEXT),
        legend.background = element_rect(fill = "white", colour = NA),
        plot.title = element_text(size = 9.5, face = "bold", hjust = 0,
                                  margin = margin(b = 1)),
        plot.subtitle = element_text(size = 8, hjust = 0, colour = COLOR_NEUTRAL,
                                     margin = margin(b = 3)))

panel_roc <- function(view, col, nx, ny, hj) {
  xs <- paste0("x_", view); ys <- paste0("y_", view)
  p <- ggplot(ROC, aes(.data[[xs]], .data[[ys]], colour = score)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dotted", colour = COLOR_NEUTRAL) +
    annotate("text", x = 0.04, y = 0.07,
             label = "dotted grey = chance (reference)", colour = COLOR_NEUTRAL,
             size = 2.4, hjust = 0, vjust = 0) +
    geom_line(aes(linetype = score), linewidth = 0.8) +
    geom_point(data = pts, aes(.data[[xs]], .data[[ys]], shape = "Reporting rules"),
               size = 2.6, colour = COLOR_TEXT, inherit.aes = FALSE) +
    geom_text(data = pts, aes(.data[[xs]] + nx, .data[[ys]] + ny, label = lab),
              inherit.aes = FALSE, size = 2.9, fontface = "bold",
              hjust = hj, colour = COLOR_TEXT) +
    geom_text(data = mk_auc(col), aes(x, y, label = lab),
              inherit.aes = FALSE, size = 2.7, hjust = 0, colour = COLOR_NEUTRAL) +
    geom_text(data = mk_auc(col), aes(x = 0.97, y, label = val),
              inherit.aes = FALSE, size = 2.7, hjust = 1, colour = COLOR_NEUTRAL) +
    scale_colour_manual(values = CURVE_COL) +
    scale_linetype_manual(values = c("Calibrated P alone" = "solid",
                                     "BAF-hat alone" = "solid",
                                     "BAF-hat + CI half-width" = "dashed")) +
    scale_shape_manual(values = c("Reporting rules" = 17)) +
    scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) +
    scale_y_continuous(limits = c(0, 1), expand = c(0, 0)) +
    labs(x = "False-positive rate (1 \u2212 specificity)",
         y = "True-positive rate (sensitivity)",
         colour = NULL, shape = NULL) +
    th
  p
}

gA <- panel_roc("ed", "auc_ed", pts$nx_a, pts$ny_a, pts$hj_a) +
  labs(title    = "A. Effect-dominated view",
       subtitle = "Positive call: declared usable as effect evidence")
gB <- panel_roc("bd", "auc_bd", pts$nx_b, pts$ny_b, pts$hj_b) +
  labs(title    = "B. Bias-dominated view",
       subtitle = "Positive call: withheld")

g <- (gA | gB) +
  plot_layout(guides = "collect") &
  theme(legend.position = "bottom",
        legend.box = "horizontal",
        legend.margin = margin(t = -4),
        legend.text = element_text(size = 8))

ggsave(file.path(V38_FIG, "figP2C_roc_paper.png"), g,
       width = 9.0, height = 4.3, dpi = 300)
cat("saved figP2C_roc_paper.png (dual view, 9.0 x 4.3 in)\n")
