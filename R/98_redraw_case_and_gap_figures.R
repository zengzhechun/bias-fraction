# ===========================================================================
# R/98_redraw_case_and_gap_figures.R
#
# Redraws the two stale case-study panels and produces the artwork that the
# long-form and medRxiv tracks list in their "Figures and tables" section but
# that never existed as a file, plus one new figure for the directional grid.
#
# Why this script exists
# ----------------------
# (1) output/figures/v40/fig3_null_bf_panels.png -- the two-panel case figure
#     embedded in the JAMA track -- was composed by R/22 from
#     fig01_calibration_plot.png and fig02_BF_main.png, both last written
#     2026-09-04, i.e. BEFORE the guideline-restricted negative-control panel
#     landed (R/92, 2026-09-17). It drew mu = -0.190, BAF = 0.91 [0.74, 0.99]
#     and a calibrated P of 0.946 for question 1, while the text draws
#     0.875 [0.385, 0.992], 0.894 and mu = -0.168 from
#     output/tables/v40_all_numbers.json. A figure that contradicts its own
#     caption is not submittable.
# (2) The long-form and medRxiv tracks listed ten figures in their
#     "Figures and tables" section with no artwork at all, and the numbering
#     had a hole at 5.
# (3) The directional grid (R/96, R/97) was reported in tables only. This
#     script adds the matching figure.
#
# Every plotted value is read from the same objects the text uses:
#   output/tables/v40_all_numbers.json                    case values, BAF, CI
#   output/data/negative_controls_expanded_guideline.rds  the 12-control panel
#   output/data/bsr_results_v35_guideline.rds             current null fit
#   output/data/bias_calibration_results_guideline.rds    case estimates + SEs
#   output/simulation/comparison_results_v37p1.rds        per-repetition BAF
#   output/tables/v40_part2_strategy_comparison.csv       rule performance
#   output/tables/v40_part2_confusion3x3.csv              zone confusion
#   output/tables/v40_direction_summary.csv               directional grid
#
# Nothing is re-simulated and no result object is overwritten. Only PNG files
# inside output/figures are written.
#
# Run from the working root (第40版):
#   Rscript R/98_redraw_case_and_gap_figures.R
# ===========================================================================

suppressPackageStartupMessages({
  library(jsonlite)
  library(ggplot2)
  library(patchwork)
  library(magick)
})

source("R/00_config.R")

V40_FIG <- file.path(FIG_DIR, "v40")
dir.create(V40_FIG, showWarnings = FALSE, recursive = TRUE)

th <- theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        panel.grid.major = element_line(colour = COLOR_GRID),
        text            = element_text(colour = COLOR_TEXT),
        plot.title      = element_text(face = "bold", size = 12),
        plot.caption    = element_text(size = 8, colour = COLOR_NEUTRAL, hjust = 0))

say <- function(...) cat(sprintf(...), "\n")

# ---------------------------------------------------------------------------
# Inputs
# ---------------------------------------------------------------------------
say("[1] reading inputs ...")

NUM   <- jsonlite::fromJSON(file.path(TAB_DIR, "v40_all_numbers.json"),
                            simplifyVector = FALSE)
cases <- NUM$part3$cases

nc_obj <- readRDS(file.path(OUT_DIR, "data",
                            "negative_controls_expanded_guideline.rds"))
nc_est <- nc_obj$estimates          # 12 rows: logRr, seLogRr, label

gdl   <- readRDS(file.path(OUT_DIR, "data", "bsr_results_v35_guideline.rds"))
MU    <- gdl$diagnostics$mu
SIGMA <- gdl$diagnostics$sigma
RESID <- gdl$diagnostics$residuals
K_NC  <- length(RESID)
SE_MU <- sd(RESID) / sqrt(K_NC)     # standard error of the fitted centre

# Case estimates and their standard errors. These come from the calibrated
# case object, whose logRr values match the JSON to the last digit; only that
# file's stored null_fit predates R/92, so the null is taken from the
# guideline object above instead.
cal_obj <- readRDS(file.path(OUT_DIR, "data", "bias_calibration_results_guideline.rds"))
cal_lst <- cal_obj$calibrated

case_df <- do.call(rbind, lapply(seq_along(cases), function(i) {
  q  <- cases[[i]]
  nm <- names(cal_lst)[i]
  data.frame(
    question = q$exposure,
    short    = if (grepl("^Beta", q$exposure)) "Q1" else "Q2",
    log_rr   = q$log_rr_uncal,
    se_logrr = as.numeric(cal_lst[[nm]]$seLogRr),
    log_rr_c = as.numeric(q$log_rr_cal),
    baf      = q$bf,
    baf_lo   = q$bf_lo,
    baf_hi   = q$bf_hi,
    stringsAsFactors = FALSE)
}))
case_df$se_cal <- sqrt(case_df$se_logrr^2 + SIGMA^2)

# Human-readable question labels for the axes.
qlab <- c(
  "Beta-blocker >=50% target dose" = "Question 1\nBeta-blocker at target dose",
  "GDMT >=2 of 3 classes"          = "Question 2\nGuideline-directed therapy")
case_df$qlab <- unname(qlab[case_df$question])

say("    mu = %.4f  sigma = %.4f  SE(mu) = %.4f  K = %d", MU, SIGMA, SE_MU, K_NC)
for (i in seq_len(nrow(case_df)))
  say("    %s BAF = %.3f [%.3f, %.3f]  cal P = %.4f",
      case_df$short[i], case_df$baf[i], case_df$baf_lo[i], case_df$baf_hi[i],
      cases[[i]]$cal_p)

# Axis ranges driven by the data, so nothing is silently clipped.
Y_MAX <- max(nc_est$seLogRr) * 1.03
X_LO  <- min(c(nc_est$logRr, case_df$log_rr, case_df$log_rr_c,
               MU - 1.96 * Y_MAX)) - 0.06
X_HI  <- max(c(nc_est$logRr, case_df$log_rr, case_df$log_rr_c,
               MU + 1.96 * Y_MAX)) + 0.06

# ---------------------------------------------------------------------------
# (a) fig01_calibration_plot.png -- empirical calibration funnel
#     Source panel A of the JAMA case figure.
# ---------------------------------------------------------------------------
say("[2] calibration funnel ...")

fun_df <- do.call(rbind, lapply(seq_len(nrow(case_df)), function(i) {
  r  <- case_df[i, ]
  se <- seq(0, Y_MAX, length.out = 200)
  data.frame(question = r$question,
             sup = MU + 1.96 * se,
             inf = MU - 1.96 * se,
             se  = se)
}))
fun_df$question <- factor(fun_df$question, levels = case_df$question)

nc_df <- do.call(rbind, lapply(seq_len(nrow(case_df)), function(i) {
  data.frame(question = case_df$question[i],
             logRr    = nc_est$logRr,
             seLogRr  = nc_est$seLogRr)
}))
nc_df$question <- factor(nc_df$question, levels = case_df$question)
nc_df$lo <- nc_df$logRr - 1.96 * nc_df$seLogRr
nc_df$hi <- nc_df$logRr + 1.96 * nc_df$seLogRr

pt_df <- rbind(
  data.frame(question = case_df$question, kind = "Uncalibrated",
             x = case_df$log_rr,   se = case_df$se_logrr),
  data.frame(question = case_df$question, kind = "Calibrated",
             x = case_df$log_rr_c, se = case_df$se_cal))
pt_df$question <- factor(pt_df$question, levels = case_df$question)
pt_df$kind <- factor(pt_df$kind, levels = c("Uncalibrated", "Calibrated"))

gA <- ggplot() +
  annotate("rect", xmin = MU - 1.96 * SE_MU, xmax = MU + 1.96 * SE_MU,
           ymin = -Inf, ymax = Inf, fill = COLOR_NEUTRAL, alpha = 0.16) +
  geom_line(data = fun_df, aes(sup, se), colour = COLOR_NEUTRAL,
            linetype = "dotted", linewidth = 0.35) +
  geom_line(data = fun_df, aes(inf, se), colour = COLOR_NEUTRAL,
            linetype = "dotted", linewidth = 0.35) +
  geom_errorbarh(data = nc_df, aes(y = seLogRr, xmin = lo, xmax = hi),
                 height = 0.008, colour = COLOR_NEUTRAL, linewidth = 0.3,
                 alpha = 0.9) +
  geom_point(data = nc_df, aes(logRr, seLogRr), colour = COLOR_NEUTRAL,
             size = 1.6, alpha = 0.9) +
  geom_vline(xintercept = 0, colour = COLOR_GRID, linewidth = 0.6) +
  geom_vline(xintercept = MU, colour = COLOR_UNCAL, linewidth = 0.6) +
  geom_errorbarh(data = pt_df, aes(y = se, xmin = x - 1.96 * se,
                                   xmax = x + 1.96 * se, colour = kind),
                 height = 0.014, linewidth = 0.8) +
  geom_point(data = pt_df, aes(x, se, colour = kind, shape = kind), size = 3.2) +
  facet_wrap(~question, nrow = 1,
             labeller = as_labeller(qlab)) +
  scale_colour_manual(values = c(Uncalibrated = COLOR_UNCAL,
                                 Calibrated   = COLOR_EFFECT_DOM)) +
  scale_shape_manual(values = c(Uncalibrated = 16, Calibrated = 18)) +
  scale_x_continuous(limits = c(X_LO, X_HI)) +
  scale_y_continuous(limits = c(0, Y_MAX),
                     expand = expansion(mult = c(0.02, 0.04))) +
  labs(x = "log relative risk", y = "Standard error",
       colour = NULL, shape = NULL,
       title = "Empirical calibration of the two clinical questions",
       caption = sprintf(paste0(
         "Grey points are the ", K_NC, " negative-control outcomes; the dotted funnel is ",
         "the region compatible with the fitted bias centre (red line, mu_B = %.3f; ",
         "grey strip, its 95%% band, %.3f to %.3f)."),
         MU, MU - 1.96 * SE_MU, MU + 1.96 * SE_MU)) +
  th + theme(legend.position = "top",
             strip.text = element_text(face = "bold", size = 9),
             plot.caption = element_text(size = 7))

ggsave(file.path(FIG_DIR, "fig01_calibration_plot.png"), gA,
       width = 10, height = 5.0, dpi = 300)

# ---------------------------------------------------------------------------
# (b) fig02_BF_main.png -- the two questions on the BAF scale with zones
#     Source panel B of the JAMA case figure, and the last figure of the long
#     track.
# ---------------------------------------------------------------------------
say("[3] BAF classification panel ...")

zone_df <- data.frame(
  xmin = c(0, BF_THRESH_EFFECT, BF_THRESH_BIAS),
  xmax = c(BF_THRESH_EFFECT, BF_THRESH_BIAS, 1),
  zone = factor(c("Effect-dominated", "Mixed", "Bias-dominated"),
                levels = c("Effect-dominated", "Mixed", "Bias-dominated")))

cl_df <- case_df
cl_df$question <- factor(cl_df$question, levels = rev(case_df$question))
cl_df$ypos <- as.numeric(cl_df$question)
cl_df$lab  <- sprintf("BAF = %.2f [%.2f, %.2f]",
                      cl_df$baf, cl_df$baf_lo, cl_df$baf_hi)
# Colour each point by the zone its point estimate falls in.
cl_df$col <- ifelse(cl_df$baf > BF_THRESH_BIAS, COLOR_BIAS_DOM,
             ifelse(cl_df$baf < BF_THRESH_EFFECT, COLOR_EFFECT_DOM,
                    COLOR_COMPETITIVE))

gB <- ggplot() +
  geom_rect(data = zone_df, aes(xmin = xmin, xmax = xmax,
                                ymin = -Inf, ymax = Inf, fill = zone),
            alpha = 0.28) +
  geom_vline(xintercept = c(BF_THRESH_EFFECT, BF_THRESH_BIAS),
             linetype = "dashed", colour = COLOR_NEUTRAL, linewidth = 0.45) +
  geom_errorbarh(data = cl_df, aes(y = ypos, xmin = baf_lo, xmax = baf_hi),
                 colour = cl_df$col, height = 0.10, linewidth = 0.9) +
  geom_point(data = cl_df, aes(baf, ypos), colour = cl_df$col, size = 3.6) +
  geom_text(data = cl_df, aes(x = baf, y = ypos + 0.30, label = lab),
            hjust = 0.5, size = 2.9, colour = COLOR_TEXT) +
  geom_text(data = zone_df,
            aes(x = (xmin + xmax) / 2, y = 2.68, label = zone),
            inherit.aes = FALSE, size = 3.1, fontface = "bold",
            colour = c(COLOR_EFFECT_DOM, COLOR_COMPETITIVE, COLOR_BIAS_DOM)) +
  scale_fill_manual(values = c("Effect-dominated" = COLOR_EFFECT_DOM,
                               "Mixed"            = COLOR_COMPETITIVE,
                               "Bias-dominated"   = COLOR_BIAS_DOM),
                    guide = "none") +
  scale_x_continuous(limits = c(-0.02, 1.02), breaks = seq(0, 1, 0.25)) +
  scale_y_continuous(limits = c(0.55, 2.90), breaks = cl_df$ypos,
                     labels = cl_df$qlab) +
  labs(x = expression(widehat(BAF)~"= |"*hat(mu)[B]*"| / (|"*hat(mu)[B]*"| + |"*tilde(psi)*"|)"),
       y = NULL,
       title = "Bias attribution fraction for the two clinical questions",
       caption = paste0("Zones: effect-dominated below 1/3, mixed between 1/3 and 1/2, ",
                        "bias-dominated above 1/2. Bars are 95% credible intervals; ",
                        "points are coloured by zone.")) +
  th + theme(legend.position = "none",
             panel.grid.major.y = element_blank(),
             plot.caption = element_text(size = 7.5))

ggsave(file.path(FIG_DIR, "fig02_BF_main.png"), gB,
       width = 10, height = 4.2, dpi = 300)

# ---------------------------------------------------------------------------
# (c) fig3_null_bf_panels.png -- A/B stack used by the JAMA track.
#     Same geometry as R/22 so the JAMA layout is unchanged.
# ---------------------------------------------------------------------------
say("[4] stacking the JAMA case figure ...")

merge_ab <- function(path_a, path_b, out) {
  a <- image_trim(image_read(path_a))
  b <- image_trim(image_read(path_b))
  W <- 2200
  a <- image_resize(a, paste0(W, "x"))
  b <- image_resize(b, paste0(W, "x"))
  lab <- function(im, txt) image_annotate(im, txt, location = "+18+46", size = 66,
                                          weight = 700, color = "black",
                                          font = "Helvetica")
  a <- lab(a, "A"); b <- lab(b, "B")
  gap   <- image_blank(width = W, height = 46, color = "white")
  panel <- image_append(c(a, gap, b), stack = TRUE)
  panel <- image_border(panel, "white", "20x20")
  image_write(panel, out, density = 300)
  info <- image_info(panel)
  say("    WROTE %s (%d x %d, %.0f KB)", basename(out), info$width, info$height,
      file.size(out) / 1024)
}

merge_ab(file.path(FIG_DIR, "fig01_calibration_plot.png"),
         file.path(FIG_DIR, "fig02_BF_main.png"),
         file.path(V40_FIG, "fig3_null_bf_panels.png"))

# ---------------------------------------------------------------------------
# (d) Long track figure 1: architecture of the three-part study
# ---------------------------------------------------------------------------
say("[5] architecture diagram ...")

mkbox <- function(x0, x1, y0, y1, lab, sub, fill) {
  data.frame(xmin = x0, xmax = x1, ymin = y0, ymax = y1, lab = lab, sub = sub,
             fill = fill, cx = (x0 + x1) / 2, title_y = y1 - 0.14)
}
arch <- rbind(
  mkbox(0.000, 0.290, 0.60, 2.70, "Part I\nDefinitions",
        paste0("BAF = |mu\u0302B| / (|mu\u0302B| + |psi\u0303|)\n",
               "bounded between 0 and 1\n",
               "three regions: effect-dominated\nbelow 1/3, mixed, bias-dominated\nabove 1/2"),
        COLOR_OHDSI),
  mkbox(0.355, 0.645, 0.60, 2.70, "Part II\nSimulation",
        paste0("five-factor factorial design (psi, muB,\nsigma_psi, K, exchangeability)\n",
               "960 conditions x 1,000 repetitions\n",
               "agreement, interval coverage,\nrule yield and misuse"),
        COLOR_EFFECT_DOM),
  mkbox(0.710, 1.000, 0.60, 2.70, "Part III\nCase study",
        paste0("beta-blocker target trial emulation\nin MIMIC-IV\n",
               "two clinical questions\n",
               "14,677 patients, 12 negative-control\noutcomes, guideline-matched null"),
        COLOR_BIAS_DOM))
arch$title_col <- "white"

segs <- data.frame(
  x    = c(0.290, 0.645),
  xend = c(0.355, 0.710),
  y    = 1.65, yend = 1.65)

gArch <- ggplot() +
  geom_rect(data = arch, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
            fill = arch$fill, colour = "white", linewidth = 1.0) +
  geom_text(data = arch, aes(x = cx, y = title_y, label = lab),
            vjust = 1, size = 4.0, fontface = "bold", colour = "white",
            lineheight = 1.05) +
  geom_text(data = arch, aes(x = cx, y = 1.55, label = sub),
            size = 2.55, colour = "white", lineheight = 1.30) +
  geom_segment(data = segs, aes(x = x, xend = xend, y = y, yend = yend),
               arrow = arrow(length = unit(0.16, "inches"), type = "closed"),
               colour = COLOR_NEUTRAL, linewidth = 0.9) +
  scale_x_continuous(limits = c(-0.01, 1.01), expand = c(0, 0)) +
  scale_y_continuous(limits = c(0.40, 2.88), expand = c(0, 0)) +
  labs(title = "Architecture of the three-part study",
       caption = paste0("Part I defines the metric and its regions. Part II evaluates the ",
                        "estimator and the reporting rules in a factorial simulation. ",
                        "Part III applies both to two beta-blocker questions in a target ",
                        "trial emulation.")) +
  th + theme(axis.title = element_blank(), axis.text = element_blank(),
             axis.ticks = element_blank(), panel.grid = element_blank(),
             plot.caption = element_text(size = 7.5))

ggsave(file.path(V40_FIG, "figP0_architecture.png"), gArch,
       width = 10, height = 4.2, dpi = 300)

# ---------------------------------------------------------------------------
# (e) Long track figure 2: empirical null distribution + the 12 controls
# ---------------------------------------------------------------------------
say("[6] null distribution ...")

# The axis has to hold every negative-control estimate as well as the fitted
# density, otherwise the track silently drops the most extreme controls.
X0 <- min(c(MU - 4 * SIGMA, nc_est$logRr)) - 0.03
X1 <- max(c(MU + 4 * SIGMA, nc_est$logRr)) + 0.03
xs   <- seq(X0, X1, length.out = 600)
dens <- data.frame(x = xs, y = dnorm(xs, MU, SIGMA))
y_hi <- max(dens$y)
trk  <- -0.085 * y_hi
nc_track <- data.frame(x = nc_est$logRr, y = trk)
say("    axis %.3f to %.3f; %d controls plotted, x range %.3f to %.3f",
    X0, X1, nrow(nc_track), min(nc_track$x), max(nc_track$x))

gNull <- ggplot() +
  annotate("rect", xmin = MU - 1.96 * SE_MU, xmax = MU + 1.96 * SE_MU,
           ymin = -Inf, ymax = Inf, fill = COLOR_NEUTRAL, alpha = 0.18) +
  geom_area(data = dens, aes(x, y), fill = COLOR_OHDSI, alpha = 0.32) +
  geom_line(data = dens, aes(x, y), colour = COLOR_OHDSI, linewidth = 0.9) +
  geom_vline(xintercept = 0, colour = COLOR_NEUTRAL, linetype = "dashed",
             linewidth = 0.5) +
  geom_vline(xintercept = MU, colour = COLOR_UNCAL, linewidth = 0.9) +
  geom_hline(yintercept = trk, colour = COLOR_GRID, linewidth = 0.5) +
  geom_point(data = nc_track, aes(x, y), colour = COLOR_BIAS_DOM, size = 2.6) +
  annotate("text", x = MU + 0.02, y = y_hi * 0.92,
           label = sprintf("mu\u0302B = %.3f", MU), colour = COLOR_UNCAL,
           size = 3.5, hjust = 0, fontface = "bold") +
  annotate("text", x = MU - 1.96 * SE_MU - 0.02, y = y_hi * 0.92,
           label = sprintf("95%% band %.3f to %.3f", MU - 1.96 * SE_MU,
                           MU + 1.96 * SE_MU),
           colour = COLOR_NEUTRAL, size = 2.8, hjust = 1) +
  annotate("text", x = X0 + 0.02, y = trk - 0.10 * y_hi,
           label = sprintf("the %d negative-control outcomes", K_NC),
           colour = COLOR_BIAS_DOM, size = 2.9, hjust = 0, vjust = 1) +
  scale_x_continuous(limits = c(X0, X1),
                     breaks = seq(floor(X0 * 5) / 5, ceiling(X1 * 5) / 5, 0.2),
                     labels = function(x) sprintf("%.1f", x)) +
  scale_y_continuous(limits = c(trk - 0.20 * y_hi, y_hi * 1.08),
                     expand = c(0, 0)) +
  labs(x = "log relative risk of the negative-control outcome",
       y = "Density of the fitted empirical null",
       title = sprintf("Empirical null fitted to the %d negative controls", K_NC),
       caption = sprintf(paste0(
         "Red line: fitted centre, %.3f; grey strip: its 95%% band, %.3f to %.3f.\n",
         "Fitted spread sigma\u0302B = %.3f; Shapiro-Wilk P = %.3f. ",
         "Controls sit on their own track."),
         MU, MU - 1.96 * SE_MU, MU + 1.96 * SE_MU, SIGMA,
         gdl$diagnostics$shapiro_p)) +
  th + theme(plot.caption = element_text(size = 7.5))

ggsave(file.path(V40_FIG, "figP0B_null_distribution.png"), gNull,
       width = 8.4, height = 4.6, dpi = 300)

# ---------------------------------------------------------------------------
# (f) Long track figure 4: distribution of BAF-hat against BAF-true
# ---------------------------------------------------------------------------
say("[7] BAF-hat against BAF-true ...")

res <- readRDS(file.path(SIM_DIR, "comparison_results_v37p1.rds"))
bt  <- unlist(lapply(res, function(e) rep(e$bf_true, nrow(e$results))))
bh  <- unlist(lapply(res, function(e) e$results$bf_mcmc))
ok  <- is.finite(bt) & is.finite(bh)
band <- data.frame(bf_true = bt[ok], baf = bh[ok])
say("    %s repetitions, %d unique true values", format(nrow(band), big.mark = ","),
    length(unique(round(band$bf_true, 6))))

# True BAF takes 66 distinct values on the grid; at the top of the scale a
# single condition carries a value, so per-value quantiles are noisy. The
# distribution is therefore summarised in 0.05-wide bins of the true BAF.
BINW <- 0.05
band$bin  <- pmin(floor(band$bf_true / BINW), 1 / BINW - 1)
band$mid  <- (band$bin + 0.5) * BINW
grp <- split(band$baf, band$mid)
qs  <- data.frame(
  bf_true = as.numeric(names(grp)),
  n = vapply(grp, length, 0L),
  q05 = vapply(grp, quantile, 0.05, FUN.VALUE = 0),
  q25 = vapply(grp, quantile, 0.25, FUN.VALUE = 0),
  q50 = vapply(grp, quantile, 0.50, FUN.VALUE = 0),
  q75 = vapply(grp, quantile, 0.75, FUN.VALUE = 0),
  q95 = vapply(grp, quantile, 0.95, FUN.VALUE = 0))
qs <- qs[order(qs$bf_true), ]
say("    %d bins, %d to %s repetitions per bin", nrow(qs), min(qs$n),
    format(max(qs$n), big.mark = ","))

gD <- ggplot(qs, aes(bf_true)) +
  geom_ribbon(aes(ymin = q05, ymax = q95), fill = COLOR_OHDSI, alpha = 0.18) +
  geom_ribbon(aes(ymin = q25, ymax = q75), fill = COLOR_OHDSI, alpha = 0.36) +
  geom_line(aes(y = q50), colour = COLOR_OHDSI, linewidth = 1.0) +
  geom_point(aes(y = q50), colour = COLOR_OHDSI, size = 1.5) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed",
              colour = COLOR_NEUTRAL, linewidth = 0.5) +
  geom_hline(yintercept = c(BF_THRESH_EFFECT, BF_THRESH_BIAS),
             linetype = "dotted", colour = COLOR_NEUTRAL, linewidth = 0.4) +
  scale_x_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.25)) +
  scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.25)) +
  labs(x = "True BAF", y = expression(widehat(BAF)),
       title = expression("Distribution of "~widehat(BAF)~"against the true BAF"),
       caption = paste0(
         "960,000 repetitions, grouped into 0.05-wide bins of the true BAF.\n",
         "Dark band: interquartile range. Light band: 5th to 95th percentile.\n",
         "Solid line: median. Dashed line: identity. Dotted lines: the zone ",
         "boundaries.")) +
  th + theme(plot.caption = element_text(size = 7.5))

ggsave(file.path(V40_FIG, "figP1B_baf_vs_true.png"), gD,
       width = 6.4, height = 5.0, dpi = 300)

# ---------------------------------------------------------------------------
# (g) Long track figure 6: nested strategy cascade
# ---------------------------------------------------------------------------
say("[8] nested strategy cascade ...")

strat <- read.csv(file.path(TAB_DIR, "v40_part2_strategy_comparison.csv"),
                  stringsAsFactors = FALSE)
strat$code <- sub(" .*", "", strat$strategy)
SHORT <- c(
  R0 = "R0  no bias correction",
  R1 = "R1  layer 1 only",
  R2 = "R2  R1 + BAF point below 0.5",
  R3 = "R3  R1 + whole interval below 0.5",
  R4 = "R4  R1 + two-layer verdict",
  C1 = "C1  BAF point alone",
  C2 = "C2  whole interval alone")
stopifnot(all(strat$code %in% names(SHORT)))
strat$rule <- factor(SHORT[strat$code], levels = rev(SHORT[strat$code]))

st_long <- rbind(
  data.frame(rule = strat$rule, part = "Truly bias-dominated",
             share = strat$bd_among_declared_pct),
  data.frame(rule = strat$rule, part = "Truly not bias-dominated",
             share = strat$declare_usable_pct - strat$bd_among_declared_pct))
# The two segments must add up to the declared-usable share, and no bar may
# run past the axis: a double-counting slip here silently inflates every bar.
stopifnot(isTRUE(all.equal(sum(st_long$share), sum(strat$declare_usable_pct))))
stopifnot(all(tapply(st_long$share, st_long$rule, sum) < 95))
# ggplot stacks the first level at the far end of the bar, so the level order
# is set to bias-dominated first in order to draw the genuine share on the
# left, with the misuse segment abutting it on the right.
st_long$part <- factor(st_long$part,
                       levels = c("Truly bias-dominated",
                                  "Truly not bias-dominated"))

gS <- ggplot(st_long, aes(y = rule, x = share, fill = part)) +
  geom_col(width = 0.64) +
  geom_text(data = strat, aes(y = rule, x = declare_usable_pct,
                              label = sprintf("%.1f%%", declare_usable_pct)),
            hjust = -0.10, size = 2.8, colour = COLOR_TEXT, inherit.aes = FALSE) +
  scale_fill_manual(values = c("Truly not bias-dominated" = COLOR_EFFECT_DOM,
                               "Truly bias-dominated"     = COLOR_BIAS_DOM),
                    breaks = c("Truly not bias-dominated",
                               "Truly bias-dominated")) +
  scale_x_continuous(limits = c(0, 104),
                     labels = function(x) paste0(x, "%")) +
  labs(x = "Share of repetitions declared usable as effect evidence", y = NULL,
       fill = NULL,
       title = "Nested reporting rules: what each rule lets through",
       caption = paste0("Bar length: share declared usable as effect evidence. ",
                        "Dark segment: misuse rate, that is, the share of those ",
                        "repetitions that were truly bias-dominated.")) +
  th + theme(legend.position = "top",
             panel.grid.major.y = element_blank(),
             plot.caption = element_text(size = 7.5))

ggsave(file.path(V40_FIG, "figP2E_strategy_cascade.png"), gS,
       width = 8.0, height = 4.6, dpi = 300)

# ---------------------------------------------------------------------------
# (h) Long track figure 8: 3x3 confusion between truth zone and rule verdict
# ---------------------------------------------------------------------------
say("[9] zone confusion ...")

cf <- read.csv(file.path(TAB_DIR, "v40_part2_confusion3x3.csv"),
               stringsAsFactors = FALSE, check.names = FALSE)
vcols <- c("effect-dominated", "mixed", "bias-dominated")
lv    <- c("Effect-dominated", "Mixed", "Bias-dominated")
cf_long <- do.call(rbind, lapply(seq_len(nrow(cf)), function(i) {
  n <- as.numeric(cf[i, vcols])
  data.frame(truth = cf$truth[i], verdict = vcols, n = n,
             pct = 100 * n / as.numeric(cf$row_total[i]))
}))
cf_long$truth   <- factor(cf_long$truth, levels = rev(vcols))
cf_long$verdict <- factor(cf_long$verdict, levels = vcols)
cf_long$lab <- sprintf("%.1f%%\n%s", cf_long$pct,
                       format(cf_long$n, big.mark = ","))
# White text only where the tile is dark enough to carry it.
cf_long$tcol <- ifelse(cf_long$pct >= 25, "white", COLOR_TEXT)

gC <- ggplot(cf_long, aes(verdict, truth)) +
  geom_tile(aes(fill = pct), colour = "white", linewidth = 1.4) +
  geom_text(aes(label = lab, colour = tcol), size = 2.9, lineheight = 1.15) +
  scale_fill_gradient(low = "#E6DFD6", high = COLOR_BIAS_DOM, guide = "none") +
  scale_colour_identity() +
  scale_x_discrete(labels = lv) +
  scale_y_discrete(labels = lv) +
  labs(x = "Rule verdict", y = "Truth zone",
       title = "Truth zone against rule verdict",
       caption = paste0("Row percentages; the second line in each cell is the ",
                        "repetition count.")) +
  th + theme(panel.grid = element_blank(),
             axis.text = element_text(face = "bold"),
             plot.caption = element_text(size = 7.5))

ggsave(file.path(V40_FIG, "figP2F_confusion3x3.png"), gC,
       width = 6.6, height = 4.8, dpi = 300)

# ---------------------------------------------------------------------------
# (i) Directional grid: coverage and rule behaviour by the role of the bias
#     Reported in the supplementary material of every track.
# ---------------------------------------------------------------------------
say("[10] directional roles ...")

dreg <- read.csv(file.path(TAB_DIR, "v40_direction_summary.csv"),
                 stringsAsFactors = FALSE)
ROLE_ORD  <- c("inflation", "shrinkage", "cancellation", "reversal")
ROLE_LAB  <- c(inflation    = "Inflation\n(bias enlarges the effect)",
               shrinkage    = "Shrinkage\n(bias shrinks it toward the null)",
               cancellation = "Cancellation\n(bias equals the effect)",
               reversal     = "Reversal\n(bias flips its sign)")
ROLE_COL  <- c(inflation    = COLOR_OHDSI,
               shrinkage    = COLOR_COMPETITIVE,
               cancellation = COLOR_NEUTRAL,
               reversal     = COLOR_BIAS_DOM)
stopifnot(setequal(dreg$regime, ROLE_ORD))
dreg$role <- factor(ROLE_LAB[dreg$regime], levels = ROLE_LAB[ROLE_ORD])
dreg$col  <- ROLE_COL[dreg$regime]
say("    %d roles, %s conditions, %s repetitions",
    nrow(dreg), format(sum(dreg$n_cond), big.mark = ","),
    format(sum(dreg$n_rep), big.mark = ","))

# Panel A: interval coverage by role, with the point error printed on the bar.
gDA <- ggplot(dreg, aes(y = role, x = 100 * coverage)) +
  geom_vline(xintercept = 95, linetype = "dashed", colour = COLOR_UNCAL,
             linewidth = 0.6) +
  geom_col(aes(fill = role), width = 0.62) +
  geom_text(aes(label = sprintf("%.1f%%\nmean signed error %+.3f",
                                100 * coverage, bias_mean)),
            hjust = -0.08, size = 2.75, colour = COLOR_TEXT) +
  annotate("text", x = 95, y = 4, label = "nominal 95%",
           colour = COLOR_UNCAL, size = 2.7, hjust = 1.06, vjust = -0.5) +
  scale_fill_manual(values = setNames(dreg$col, as.character(dreg$role)),
                    guide = "none") +
  scale_x_continuous(limits = c(0, 108),
                     labels = function(x) paste0(x, "%")) +
  scale_y_discrete(expand = expansion(add = 0.80)) +
  labs(x = "Coverage of the 95% credible interval", y = NULL, title = NULL,
       subtitle = "A  Point accuracy survives a change in the direction of the bias; interval coverage does not") +
  th + theme(panel.grid.major.y = element_blank(),
             plot.subtitle = element_text(size = 9.5, face = "bold",
                                          colour = COLOR_TEXT))

# Panel B: yield and misuse of rule R3 by role.
st_b <- rbind(
  data.frame(role = dreg$role, measure = "R3 declares usable (yield)",
             pct = 100 * dreg$R3_yield),
  data.frame(role = dreg$role,
             measure = "of those, truly bias-dominated (misuse)",
             pct = 100 * dreg$R3_misuse))
st_b$measure <- factor(st_b$measure,
                       levels = c("R3 declares usable (yield)",
                                  "of those, truly bias-dominated (misuse)"))

gDB <- ggplot(st_b, aes(y = role, x = pct, fill = measure)) +
  geom_col(position = position_dodge(width = 0.72), width = 0.66) +
  geom_text(aes(label = sprintf("%.1f%%", pct)),
            position = position_dodge(width = 0.72), hjust = -0.10,
            size = 2.7, colour = COLOR_TEXT) +
  scale_fill_manual(values = c("R3 declares usable (yield)" = COLOR_EFFECT_DOM,
                               "of those, truly bias-dominated (misuse)" = COLOR_BIAS_DOM)) +
  scale_x_continuous(limits = c(0, 118),
                     labels = function(x) paste0(x, "%")) +
  labs(x = "Share of repetitions", y = NULL, fill = NULL, title = NULL,
       subtitle = "B  The reporting rule inherits the shortfall: its misuse rate rises to 100% where the bias reverses the effect") +
  th + theme(legend.position = "top",
             panel.grid.major.y = element_blank(),
             plot.subtitle = element_text(size = 9.5, face = "bold",
                                          colour = COLOR_TEXT))

gDir <- (gDA / gDB) +
  plot_annotation(caption = paste0(
    "Inflation is the primary grid; shrinkage, cancellation and reversal come from a ",
    "mirror grid that changes only the sign of the bias centre.\n",
    "Together ", format(sum(dreg$n_cond), big.mark = ","), " conditions and ",
    format(sum(dreg$n_rep), big.mark = ","), " repetitions. Cancellation sets the ",
    "true BAF to exactly 0.5 by identity."),
    theme = theme(plot.caption = element_text(size = 7.5, colour = COLOR_NEUTRAL,
                                              hjust = 0)))

ggsave(file.path(V40_FIG, "figP3_direction_roles.png"), gDir,
       width = 9.2, height = 6.8, dpi = 300)

say("")
say("[11] done. Figures written:")
for (f in c("fig01_calibration_plot.png", "fig02_BF_main.png"))
  say("   output/figures/%s (%.0f KB)", f,
      file.size(file.path(FIG_DIR, f)) / 1024)
for (f in c("fig3_null_bf_panels.png", "figP0_architecture.png",
            "figP0B_null_distribution.png", "figP1B_baf_vs_true.png",
            "figP2E_strategy_cascade.png", "figP2F_confusion3x3.png",
            "figP3_direction_roles.png"))
  say("   output/figures/v40/%s (%.0f KB)", f,
      file.size(file.path(V40_FIG, f)) / 1024)
