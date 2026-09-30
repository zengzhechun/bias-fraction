# Phase 4 (v34): Figure + Table Generation — Bias Fraction (BF) primary
# Generates 7 publication-quality figures (PDF+PNG) + 2 tables (CSV)
# v34: BF is the primary metric (zone thresholds 1/3 and 0.5); BER retained
#   as auxiliary ratio. Point estimates are bootstrap medians.
source("R/00_config.R")
source("R/01_bsr_core.R")
library(data.table)
library(EmpiricalCalibration)
library(ggplot2)
library(ggrepel)
library(viridis)
library(gridExtra)
library(patchwork)

theme_academic <- theme_classic(base_size = 10, base_family = "sans") +
  theme(
    panel.grid.major = element_line(color = COLOR_GRID, linewidth = 0.25),
    panel.grid.minor = element_blank(),
    axis.line = element_line(color = "grey40", linewidth = 0.4),
    axis.text = element_text(color = COLOR_TEXT, size = 8),
    axis.title = element_text(color = COLOR_TEXT, size = 9),
    plot.title = element_text(face = "bold", size = 10, color = COLOR_TEXT),
    plot.subtitle = element_text(size = 8, color = "grey50"),
    legend.position = "bottom",
    legend.title = element_text(size = 8),
    legend.text = element_text(size = 7),
    strip.background = element_rect(fill = "grey95", color = NA),
    strip.text = element_text(size = 8, color = COLOR_TEXT)
  )

class_colors <- c(
  "bias-dominated" = COLOR_BIAS_DOM,
  "mixed" = COLOR_COMPETITIVE,
  "effect-dominated" = COLOR_EFFECT_DOM
)

save_both <- function(p, fname, w, h) {
  pdf(file.path(FIG_DIR, paste0(fname, ".pdf")), width = w, height = h); print(p); dev.off()
  png(file.path(FIG_DIR, paste0(fname, ".png")), width = w, height = h,
      units = "in", res = 300); print(p); dev.off()
  cat(sprintf("  Saved: %s\n", fname))
}

# For grid.arrange panels: arrange INSIDE each device so both PNG and PDF render.
save_both_arrange <- function(plots, fname, w, h, ncol = 2, widths = NULL) {
  pdf(file.path(FIG_DIR, paste0(fname, ".pdf")), width = w, height = h)
  do.call(gridExtra::grid.arrange, c(plots, list(ncol = ncol, widths = widths)))
  dev.off()
  png(file.path(FIG_DIR, paste0(fname, ".png")), width = w, height = h,
      units = "in", res = 300)
  do.call(gridExtra::grid.arrange, c(plots, list(ncol = ncol, widths = widths)))
  dev.off()
  cat(sprintf("  Saved: %s\n", fname))
}

# ---- Load Data ----
bsr_res <- readRDS(file.path(OUT_DIR, "data", "bsr_results_v34.rds"))
sim     <- readRDS(file.path(SIM_DIR, "simulation_merged_v34.rds"))
ci_sim  <- readRDS(file.path(SIM_DIR, "ci_simulation_merged.rds"))
nc      <- readRDS(file.path(DATA_DIR, "negative_controls_expanded.rds"))
nc_est  <- nc$estimates
nc_log_rr <- setNames(nc_est$logRr, nc_est$outcome)
nc_se     <- setNames(nc_est$seLogRr, nc_est$outcome)

bb    <- bsr_res$bb$bsr
bb_b  <- bsr_res$bb$boot
gdmt  <- bsr_res$gdmt$bsr
gdmt_b<- bsr_res$gdmt$boot
grace <- readRDS(file.path(DATA_DIR, "grace_period_guideline_results.rds"))
ex <- grace$grace_period_exclusion
bb_se <- (log(ex$rr_ci[2]) - log(ex$rr_ci[1])) / (2 * 1.96)
cal <- readRDS(file.path(DATA_DIR, "bias_calibration_results.rds"))
gdmt_se <- cal$calibrated[["GDMT >=2/3 Classes (1-Year)"]]$seLogRr

# ---- Summary numbers (printed for manuscript use) ----
bd_idx <- sim$bsr_true > 1 | is.infinite(sim$bsr_true)
cp_idx <- sim$bsr_true >= 0.5 & sim$bsr_true <= 1
sd_idx <- sim$bsr_true < 0.5
bd0_idx  <- bd_idx & (abs(sim$true_log_rr) < 1e-9)
bdnz_idx <- bd_idx & (abs(sim$true_log_rr) >= 1e-9)
cat(sprintf("SIM: overall=%.1f bd=%.1f (bd0=%.1f, bdnz=%.1f) cp=%.1f sd=%.1f\n",
  100*mean(sim$bsr_class_accuracy), 100*mean(sim$bsr_class_accuracy[bd_idx]),
  100*mean(sim$bsr_class_accuracy[bd0_idx]), 100*mean(sim$bsr_class_accuracy[bdnz_idx]),
  100*mean(sim$bsr_class_accuracy[cp_idx]), 100*mean(sim$bsr_class_accuracy[sd_idx])))
exv0_acc <- mean(sim$bsr_class_accuracy[sim$ex_violation == 0])*100
exv3_acc <- mean(sim$bsr_class_accuracy[sim$ex_violation == 0.3])*100
exv0_null <- mean(sim$ohdsi_rejection_rate[sim$ex_violation == 0 & sim$true_log_rr == 0])*100
exv3_null <- mean(sim$ohdsi_rejection_rate[sim$ex_violation == 0.3 & sim$true_log_rr == 0])*100
cat(sprintf("SIM: exv0_acc=%.1f exv3_acc=%.1f exv0_null=%.1f exv3_null=%.1f\n",
  exv0_acc, exv3_acc, exv0_null, exv3_null))
ohdsi_rej_null <- mean(sim$ohdsi_rejection_rate[sim$true_log_rr == 0])*100
uncal_rej <- mean(sim$uncal_rejection_rate)*100
ohdsi_rej_all <- mean(sim$ohdsi_rejection_rate)*100
cat(sprintf("SIM: ohdsi_null=%.1f uncal_rej=%.1f ohdsi_all=%.1f\n", ohdsi_rej_null, uncal_rej, ohdsi_rej_all))
finite_idx <- is.finite(sim$bsr_true)
cat(sprintf("SIM: BF rel bias finite=%.1f%% (exV0=%.1f, exV3=%.1f); RMSE mean=%.4f median=%.4f\n",
  100*mean(sim$bf_rel_bias[finite_idx]),
  100*mean(sim$bf_rel_bias[finite_idx & sim$ex_violation==0]),
  100*mean(sim$bf_rel_bias[finite_idx & sim$ex_violation==0.3]),
  mean(sim$bf_rmse[finite_idx]), median(sim$bf_rmse[finite_idx])))

ci_reps <- ci_sim$reps
ci_conds <- ci_sim$conditions
ci_decisive <- !is.na(ci_reps$ci_class) & ci_reps$ci_class != "competitive"
ci_decisive_rate <- 100*mean(ci_decisive)
ci_decisive_acc <- 100*mean(ci_reps$ci_class[ci_decisive] == ci_reps$true_class[ci_decisive])
ci_acc_overall <- 100*mean(ci_reps$ci_class == ci_reps$true_class, na.rm=TRUE)
ci_acc_bd <- 100*with(ci_reps[ci_reps$true_class=="bias-dominated",], mean(ci_class==true_class, na.rm=TRUE))
ci_acc_cp <- 100*with(ci_reps[ci_reps$true_class=="competitive",], mean(ci_class==true_class, na.rm=TRUE))
ci_acc_sd <- 100*with(ci_reps[ci_reps$true_class=="effect-dominated",], mean(ci_class==true_class, na.rm=TRUE))
cat(sprintf("CISIM: overall=%.1f bd=%.1f cp=%.1f sd=%.1f decisive_rate=%.1f decisive_acc=%.1f\n",
  ci_acc_overall, ci_acc_bd, ci_acc_cp, ci_acc_sd, ci_decisive_rate, ci_decisive_acc))
cat(sprintf("CISIM: decisive rate K12=%.1f K25=%.1f\n",
  100*mean(ci_conds$decisive_rate[ci_conds$n_nc==12]), 100*mean(ci_conds$decisive_rate[ci_conds$n_nc==25])))
cat(sprintf("CASE: BB BF=%.3f [%.3f, %.3f] BERmed=%.1f [%.1f, %.1f]; GDMT BF=%.3f [%.3f, %.3f]\n",
  bb_b$bf_median, bb_b$bf_ci_lo, bb_b$bf_ci_hi, bb_b$ber_median, bb_b$ci_lo, bb_b$ci_hi,
  gdmt_b$bf_median, gdmt_b$bf_ci_lo, gdmt_b$bf_ci_hi))
cat(sprintf("CASE: LOO BF range [%.3f, %.3f]; SL BF: %.3f/%.3f/%.3f with CI lo %.3f/%.3f/%.3f\n",
  min(bsr_res$loo$bf), max(bsr_res$loo$bf),
  bsr_res$sl$bf[1], bsr_res$sl$bf[2], bsr_res$sl$bf[3],
  bsr_res$sl$bf_ci_lo[1], bsr_res$sl$bf_ci_lo[2], bsr_res$sl$bf_ci_lo[3]))

# ============================================================
# Figure 1: Empirical Calibration Plot
# ============================================================
cat("Figure 1: Calibration plot...\n")
make_calibration_plot <- function(nc_log_rr, nc_se, est_log_rr, est_se, est_name,
                                  bf_val, bf_lo, bf_hi, cal_p) {
  nf <- fitNull(nc_log_rr, nc_se)
  mu <- nf[1]; sigma <- nf[2]
  cal_log_rr <- est_log_rr - mu
  cal_se <- sqrt(est_se^2 + sigma^2)
  se_range <- seq(0.001, max(c(nc_se, est_se)) * 1.3, length.out = 300)
  bound <- 1.96 * sqrt(se_range^2 + sigma^2)
  funnel_df <- data.frame(se = se_range, upper = mu + bound, lower = mu - bound)
  nc_df <- data.frame(log_rr = nc_log_rr, se = nc_se, outcome = names(nc_log_rr))
  est_df <- data.frame(
    log_rr = c(est_log_rr, cal_log_rr),
    se = c(est_se, cal_se),
    label = c("Uncalibrated", "Calibrated"),
    rr = c(exp(est_log_rr), exp(cal_log_rr)))
  p <- ggplot() +
    geom_polygon(data = data.frame(x = c(funnel_df$upper, rev(funnel_df$lower)),
                                   y = c(funnel_df$se, rev(funnel_df$se))),
                 aes(x = x, y = y), fill = COLOR_BIAS_DOM, alpha = 0.06) +
    geom_line(data = funnel_df, aes(x = upper, y = se), color = COLOR_BIAS_DOM,
              linewidth = 0.4, linetype = "dashed", alpha = 0.5) +
    geom_line(data = funnel_df, aes(x = lower, y = se), color = COLOR_BIAS_DOM,
              linewidth = 0.4, linetype = "dashed", alpha = 0.5) +
    annotate("rect", xmin = mu - sigma, xmax = mu + sigma, ymin = 0,
             ymax = max(nc_se) * 1.3, fill = COLOR_NEUTRAL, alpha = 0.08) +
    geom_vline(xintercept = mu, linetype = "dotted", color = "grey50", linewidth = 0.4) +
    geom_errorbarh(data = nc_df, aes(xmin = log_rr - 1.96*se, xmax = log_rr + 1.96*se, y = se),
                   height = 0, color = "grey55", linewidth = 0.3) +
    geom_point(data = nc_df, aes(x = log_rr, y = se), shape = 21, fill = "grey70",
               color = "grey30", size = 1.8, stroke = 0.4) +
    geom_point(data = est_df, aes(x = log_rr, y = se, color = label), shape = 18, size = 3.5) +
    geom_text_repel(data = est_df, aes(x = log_rr, y = se,
                    label = sprintf("%s\nRR=%.2f", label, rr)),
                    color = c(COLOR_UNCAL, COLOR_EFFECT_DOM), size = 2.5,
                    nudge_y = max(nc_se) * 0.15, direction = "x",
                    segment.size = 0.2, segment.color = "grey60") +
    scale_color_manual(values = c("Uncalibrated" = COLOR_UNCAL, "Calibrated" = COLOR_EFFECT_DOM),
                       guide = "none") +
    annotate("text", x = mu, y = max(nc_se) * 1.25,
             label = sprintf("mu = %.3f", mu), size = 2.5, vjust = -0.5, color = "grey40") +
    labs(x = "log(RR)", y = "Standard Error",
         title = sprintf("Empirical calibration: %s", est_name),
         subtitle = sprintf("BF = %.2f [%.2f, %.2f]  |  Calibrated p = %.4f  |  %d NCs",
                            bf_val, bf_lo, bf_hi, cal_p, length(nc_log_rr))) +
    theme_academic
  p
}
p1a <- make_calibration_plot(nc_log_rr, nc_se, bb$log_rr_uncal, bb_se,
  "BB 1-Year Mortality", bb_b$bf_median, bb_b$bf_ci_lo, bb_b$bf_ci_hi, bb$cal_p)
p1b <- make_calibration_plot(nc_log_rr, nc_se, gdmt$log_rr_uncal, gdmt_se,
  "GDMT >=2/3 Classes", gdmt_b$bf_median, gdmt_b$bf_ci_lo, gdmt_b$bf_ci_hi, gdmt$cal_p)
save_both_arrange(list(p1a, p1b), "fig01_calibration_plot", 12, 5.5, ncol = 2)

# ============================================================
# Figure 2: BF main results (bounded 0-1 scale)
# ============================================================
cat("Figure 2: BF main results...\n")
bf_plot_data <- data.frame(
  analysis = c("BB 1-Year Mortality", "GDMT >=2/3 Classes"),
  BF = c(bb_b$bf_median, gdmt_b$bf_median),
  ci_lo = c(bb_b$bf_ci_lo, gdmt_b$bf_ci_lo),
  ci_hi = c(bb_b$bf_ci_hi, gdmt_b$bf_ci_hi),
  class = c(bsr_res$bb$class, bsr_res$gdmt$class),
  value_label = c(
    sprintf("BF = %.2f [%.2f, %.2f]", bb_b$bf_median, bb_b$bf_ci_lo, bb_b$bf_ci_hi),
    sprintf("BF = %.2f [%.2f, %.2f]", gdmt_b$bf_median, gdmt_b$bf_ci_lo, gdmt_b$bf_ci_hi)))
bf_plot_data$analysis <- factor(bf_plot_data$analysis,
  levels = rev(c("BB 1-Year Mortality", "GDMT >=2/3 Classes")))

p2 <- ggplot(bf_plot_data, aes(x = BF, y = analysis)) +
  annotate("rect", xmin = 0, xmax = 1/3, ymin = -Inf, ymax = Inf,
           fill = COLOR_EFFECT_DOM, alpha = 0.06) +
  annotate("rect", xmin = 1/3, xmax = 0.5, ymin = -Inf, ymax = Inf,
           fill = COLOR_COMPETITIVE, alpha = 0.06) +
  annotate("rect", xmin = 0.5, xmax = 1, ymin = -Inf, ymax = Inf,
           fill = COLOR_BIAS_DOM, alpha = 0.06) +
  geom_vline(xintercept = c(1/3, 0.5), linetype = "dashed", color = "grey55", linewidth = 0.4) +
  geom_errorbarh(aes(xmin = ci_lo, xmax = ci_hi, color = class),
                 height = 0.15, linewidth = 0.6) +
  geom_point(aes(color = class), shape = 21, fill = "white", size = 2.5, stroke = 0.8) +
  geom_text(aes(x = 1.02, label = value_label, color = class),
            hjust = 0, vjust = 0.5, size = 3, family = "mono") +
  scale_color_manual(values = class_colors, guide = "none") +
  annotate("text", x = 0.165, y = 2.55, label = "Effect-dominated\n(BF < 1/3)",
           size = 2.8, color = COLOR_EFFECT_DOM, fontface = "bold", hjust = 0.5) +
  annotate("text", x = 0.417, y = 2.55, label = "Mixed\n(1/3 <= BF <= 1/2)",
           size = 2.8, color = "#8B7530", fontface = "bold", hjust = 0.5) +
  annotate("text", x = 0.75, y = 2.55, label = "Bias-dominated\n(BF > 1/2)",
           size = 2.8, color = COLOR_BIAS_DOM, fontface = "bold", hjust = 0.5) +
  labs(x = "Bias fraction BF = |mu_B| / (|mu_B| + |psi_tilde|)", y = "",
       title = "BF classification of observational causal estimates") +
  coord_cartesian(xlim = c(0, 1.35), ylim = c(0.7, 2.8), clip = "off") +
  theme_academic +
  theme(plot.margin = margin(t = 5, r = 10, b = 5, l = 10, unit = "pt"))
save_both(p2, "fig02_BF_main", 9, 3.5)

# ============================================================
# Figure 3: Simulation Heatmap
# ============================================================
cat("Figure 3: Simulation heatmap...\n")
sim_plot <- sim
sim_plot$true_lab <- sprintf("logRR=%.1f", sim_plot$true_log_rr)
sim_plot$true_lab <- factor(sim_plot$true_lab,
  levels = c("logRR=0.0", "logRR=-0.05", "logRR=-0.1", "logRR=-0.15",
            "logRR=-0.2", "logRR=-0.3", "logRR=-0.4"))
sim_plot$exv_lab <- sprintf("ExV=%.0f%%", sim_plot$ex_violation * 100)
sim_plot$nc_lab  <- paste("K =", sim_plot$n_nc)
sim_plot$sig_lab <- paste("sigma =", sim_plot$bias_sigma)
sim_plot$bias_lab <- paste("mu =", sim_plot$bias_mu)
min_bf_finite <- min(sim_plot$bf_true[is.finite(sim_plot$bsr_true)])

p3 <- ggplot(sim_plot, aes(x = bias_lab, y = true_lab, fill = bsr_class_accuracy * 100)) +
  geom_tile(color = NA) +
  geom_text(aes(label = sprintf("%.0f", bsr_class_accuracy * 100),
                color = bsr_class_accuracy > 0.5), size = 2.5, fontface = "bold") +
  facet_grid(nc_lab + exv_lab ~ sig_lab) +
  scale_fill_viridis_c(option = "plasma", direction = -1,
                       limits = c(0, 100), name = "Accuracy (%)") +
  scale_color_manual(values = c("TRUE" = "white", "FALSE" = "black"), guide = "none") +
  labs(x = "Bias mean (mu)", y = "True effect (log RR)",
       title = "BF classification accuracy across simulation conditions",
       subtitle = sprintf("336 conditions x 200 reps  |  BF_true range: [%.2f, %.2f] plus the null (BF_true = 1)",
                          min_bf_finite, max(sim_plot$bf_true[is.finite(sim_plot$bsr_true)]))) +
  theme_academic +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 7))
save_both(p3, "fig03_simulation_heatmap", 12, 8)

# ============================================================
# Figure 4: Classification performance by zone
# ============================================================
cat("Figure 4: Classification performance...\n")
sim$zone <- ifelse(is.infinite(sim$bsr_true) | sim$bsr_true > 1, "bias-dominated",
            ifelse(sim$bsr_true < 0.5, "effect-dominated", "mixed"))
sim$zone <- factor(sim$zone, levels = c("effect-dominated", "mixed", "bias-dominated"))
panel_a_data <- aggregate(bsr_class_accuracy ~ zone, data = sim,
                          FUN = function(x) c(mean = mean(x)*100, sd = sd(x)*100))
panel_a_df <- data.frame(zone = panel_a_data$zone,
  mean = panel_a_data$bsr_class_accuracy[, "mean"],
  sd = panel_a_data$bsr_class_accuracy[, "sd"])
p4a <- ggplot(panel_a_df, aes(x = zone, y = mean, fill = zone)) +
  geom_bar(stat = "identity", width = 0.65) +
  geom_errorbar(aes(ymin = pmax(0, mean - sd), ymax = pmin(100, mean + sd)),
                width = 0.15, linewidth = 0.4) +
  geom_text(aes(label = sprintf("%.1f%%", mean)), vjust = -0.5, size = 2.8) +
  geom_hline(yintercept = 33.3, linetype = "dashed", color = "grey50", linewidth = 0.4) +
  annotate("text", x = 3.7, y = 35, label = "Chance level (3-class)", size = 2.3,
           color = "grey50", hjust = 1) +
  scale_fill_manual(values = class_colors, guide = "none") +
  scale_x_discrete(labels = c("effect-dominated" = "Effect-dominated",
                              "mixed" = "Mixed", "bias-dominated" = "Bias-dominated")) +
  labs(x = "", y = "Classification accuracy (%)",
       title = "A. BF classification accuracy by zone") +
  coord_cartesian(ylim = c(0, 110)) +
  theme_academic
panel_b_data <- aggregate(
  cbind(ohdsi_rej = ohdsi_rejection_rate, uncal_rej = uncal_rejection_rate) ~ zone,
  data = sim, FUN = function(x) c(mean = mean(x)*100, sd = sd(x)*100))
panel_b_df <- data.frame(
  zone = rep(panel_b_data$zone, 2),
  method = rep(c("OHDSI calibration", "Uncalibrated"), each = 3),
  mean = c(panel_b_data$ohdsi_rej[, "mean"], panel_b_data$uncal_rej[, "mean"]),
  sd = c(panel_b_data$ohdsi_rej[, "sd"], panel_b_data$uncal_rej[, "sd"]))
panel_b_df$method <- factor(panel_b_df$method, levels = c("OHDSI calibration", "Uncalibrated"))
p4b <- ggplot(panel_b_df, aes(x = zone, y = mean, fill = method)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.75), width = 0.65) +
  geom_errorbar(aes(ymin = pmax(0, mean - sd), ymax = pmin(100, mean + sd)),
                position = position_dodge(width = 0.75), width = 0.15, linewidth = 0.4) +
  geom_hline(yintercept = 5, linetype = "dashed", color = "grey50", linewidth = 0.4) +
  annotate("text", x = 3.7, y = 7, label = "Nominal alpha = 5%", size = 2.3,
           color = "grey50", hjust = 1) +
  annotate("text", x = 1, y = 95, label = "High rejection\n= power (psi != 0)",
           size = 2.2, color = "grey40", hjust = 0.5) +
  scale_fill_manual(values = c("OHDSI calibration" = COLOR_OHDSI, "Uncalibrated" = COLOR_UNCAL)) +
  scale_x_discrete(labels = c("effect-dominated" = "Effect-dominated",
                              "mixed" = "Mixed", "bias-dominated" = "Bias-dominated")) +
  labs(x = "", y = "Rejection rate (%)", title = "B. Rejection rates by zone", fill = "Method") +
  coord_cartesian(ylim = c(0, 110)) +
  theme_academic +
  theme(legend.position = "bottom")
save_both_arrange(list(p4a, p4b), "fig04_classification_domain", 10, 4.5, ncol = 2, widths = c(1, 1.3))

# ============================================================
# Figure 5: LOO Sensitivity (BF scale)
# ============================================================
cat("Figure 5: LOO sensitivity (BF scale)...\n")
loo <- bsr_res$loo
loo$excluded_nc <- factor(loo$excluded_nc, levels = loo$excluded_nc[order(loo$bf)])
p5 <- ggplot(loo, aes(x = bf, y = excluded_nc, color = class)) +
  annotate("rect", xmin = 0, xmax = 1/3, ymin = -Inf, ymax = Inf,
           fill = COLOR_EFFECT_DOM, alpha = 0.06) +
  annotate("rect", xmin = 1/3, xmax = 0.5, ymin = -Inf, ymax = Inf,
           fill = COLOR_COMPETITIVE, alpha = 0.06) +
  annotate("rect", xmin = 0.5, xmax = 1, ymin = -Inf, ymax = Inf,
           fill = COLOR_BIAS_DOM, alpha = 0.06) +
  geom_vline(xintercept = c(1/3, 0.5), linetype = "dashed", color = "grey55", linewidth = 0.4) +
  geom_vline(xintercept = bb_b$bf_median, color = COLOR_OHDSI, linewidth = 0.8) +
  geom_errorbarh(aes(xmin = bf_ci_lo, xmax = bf_ci_hi), height = 0.2, linewidth = 0.5) +
  geom_point(shape = 21, fill = "white", size = 2.2, stroke = 0.6) +
  annotate("text", x = bb_b$bf_median + 0.05, y = levels(loo$excluded_nc)[1],
           label = sprintf("Full data (BF = %.2f)", bb_b$bf_median),
           size = 2.5, color = COLOR_OHDSI, hjust = 0) +
  scale_color_manual(values = class_colors, guide = "none") +
  labs(x = "BF [after removing one NC]", y = "Excluded negative control",
       title = "Leave-one-out BF sensitivity (BB 1-Year)",
       subtitle = sprintf("BF range: [%.2f, %.2f]  |  All consistently bias-dominated",
                          min(loo$bf), max(loo$bf))) +
  coord_cartesian(xlim = c(0.5, 1)) +
  theme_academic
save_both(p5, "fig05_loo_sensitivity", 8, 5)

# ============================================================
# Figure 6: QQ diagnostics
# ============================================================
cat("Figure 6: QQ diagnostics...\n")
diag <- bsr_res$diagnostics
std_res <- diag$std_residuals
nc_names <- names(nc_log_rr)
qq_df <- data.frame(theoretical = qnorm(ppoints(length(std_res))), sample = sort(std_res))
envelope_df <- local({
  set.seed(42); n_sim <- 1000
  envelope_mat <- matrix(NA, nrow = length(std_res), ncol = n_sim)
  for (i in 1:n_sim) envelope_mat[, i] <- sort(rnorm(length(std_res)))
  data.frame(theoretical = qq_df$theoretical,
             lower = apply(envelope_mat, 1, quantile, 0.025),
             upper = apply(envelope_mat, 1, quantile, 0.975))
})
p6a <- ggplot(qq_df, aes(x = theoretical, y = sample)) +
  geom_ribbon(data = envelope_df, aes(x = theoretical, ymin = lower, ymax = upper),
              fill = COLOR_NEUTRAL, alpha = 0.15, inherit.aes = FALSE) +
  geom_abline(slope = 1, intercept = 0, color = COLOR_BIAS_DOM, linewidth = 0.5) +
  geom_point(shape = 21, fill = "white", color = COLOR_TEXT, size = 2, stroke = 0.5) +
  annotate("text", x = -Inf, y = Inf, hjust = -0.2, vjust = 1.5,
           label = sprintf("Shapiro-Wilk p = %.3f %s", diag$shapiro_p,
                           ifelse(diag$shapiro_p > 0.05, "(normal)", "(non-normal)")),
           size = 2.5, color = "grey30") +
  labs(x = "Theoretical quantiles", y = "Sample quantiles",
       title = "A. QQ plot: NC standardized residuals") +
  theme_academic
lolly_df <- data.frame(outcome = nc_names, abs_res = diag$std_residual_abs)
lolly_df$outcome <- factor(lolly_df$outcome, levels = lolly_df$outcome[order(lolly_df$abs_res)])
p6b <- ggplot(lolly_df, aes(x = outcome, y = abs_res)) +
  geom_segment(aes(x = outcome, xend = outcome, y = 0, yend = abs_res),
               color = "grey60", linewidth = 0.4) +
  geom_point(aes(color = abs_res > 2), size = 2.5) +
  geom_hline(yintercept = 2, linetype = "dashed", color = COLOR_BIAS_DOM, linewidth = 0.4) +
  annotate("text", x = 0.5, y = 2.2, label = "|residual| = 2", size = 2.3,
           color = COLOR_BIAS_DOM, hjust = 0) +
  scale_color_manual(values = c("TRUE" = COLOR_BIAS_DOM, "FALSE" = "grey50"), guide = "none") +
  labs(x = "", y = "|Standardized residual|", title = "B. |Standardized residual| by NC") +
  coord_flip() +
  theme_academic +
  theme(axis.text.y = element_text(size = 7))
save_both_arrange(list(p6a, p6b), "fig06_qq_diagnostics", 10, 4.5, ncol = 2, widths = c(1, 1.2))

# ============================================================
# Figure 7: Bootstrap distributions (BF scale)
# ============================================================
cat("Figure 7: Bootstrap distributions (BF scale)...\n")
bb_bf_dist <- data.frame(BF = bb_b$boot_bf_dist)
gdmt_bf_dist <- data.frame(BF = gdmt_b$boot_bf_dist)
p7a <- ggplot(bb_bf_dist, aes(x = BF)) +
  geom_histogram(bins = 50, fill = COLOR_BIAS_DOM, color = "white", linewidth = 0.2, alpha = 0.7) +
  geom_density(aes(y = after_stat(count)), color = COLOR_BIAS_DOM, linewidth = 0.5) +
  geom_vline(xintercept = bb_b$bf_median, color = COLOR_BIAS_DOM, linewidth = 0.6) +
  geom_vline(xintercept = c(bb_b$bf_ci_lo, bb_b$bf_ci_hi), color = COLOR_BIAS_DOM,
             linetype = "dashed", linewidth = 0.4) +
  geom_vline(xintercept = 0.5, color = "grey40", linetype = "dotted") +
  annotate("text", x = bb_b$bf_median + 0.02, y = Inf, vjust = 1.5,
           label = sprintf("BF = %.2f", bb_b$bf_median), size = 2.5,
           color = COLOR_BIAS_DOM, hjust = 0) +
  labs(title = "Bootstrap distribution (BB)", x = "BF", y = "Count") +
  coord_cartesian(xlim = c(0, 1)) +
  theme_classic(base_size = 9) +
  theme(panel.grid.major = element_line(color = COLOR_GRID, linewidth = 0.25),
        axis.line = element_line(color = "grey40", linewidth = 0.4))
p7b <- ggplot(gdmt_bf_dist, aes(x = BF)) +
  geom_histogram(bins = 50, fill = COLOR_COMPETITIVE, color = "white", linewidth = 0.2, alpha = 0.7) +
  geom_density(aes(y = after_stat(count)), color = COLOR_COMPETITIVE, linewidth = 0.5) +
  geom_vline(xintercept = gdmt_b$bf_median, color = COLOR_COMPETITIVE, linewidth = 0.6) +
  geom_vline(xintercept = c(gdmt_b$bf_ci_lo, gdmt_b$bf_ci_hi), color = COLOR_COMPETITIVE,
             linetype = "dashed", linewidth = 0.4) +
  geom_vline(xintercept = c(1/3, 0.5), color = "grey40", linetype = "dotted") +
  annotate("text", x = gdmt_b$bf_median + 0.02, y = Inf, vjust = 1.5,
           label = sprintf("BF = %.2f", gdmt_b$bf_median), size = 2.5,
           color = "#8B7530", hjust = 0) +
  labs(title = "Bootstrap distribution (GDMT)", x = "BF", y = "Count") +
  coord_cartesian(xlim = c(0, 1)) +
  theme_classic(base_size = 9) +
  theme(panel.grid.major = element_line(color = COLOR_GRID, linewidth = 0.25),
        axis.line = element_line(color = "grey40", linewidth = 0.4))
save_both(p7a + p7b, "fig07_bootstrap_BF", 9, 4)

# ============================================================
# Table 1: BF results
# ============================================================
cat("Table 1: BF results...\n")
tab1 <- data.frame(
  Analysis = c("BB 1-Year Mortality", "GDMT >=2/3 Classes"),
  logRR_uncal = c(bb$log_rr_uncal, gdmt$log_rr_uncal),
  se_logRR    = c(bb_se, gdmt_se),
  RR_uncal    = c(bb$rr_uncal, gdmt$rr_uncal),
  mu_bias     = c(bb$mu_bias, gdmt$mu_bias),
  sigma_bias  = c(bb$sigma_bias, gdmt$sigma_bias),
  logRR_cal   = c(bb$log_rr_true, gdmt$log_rr_true),
  RR_cal      = c(bb$rr_true, gdmt$rr_true),
  BF          = c(bb_b$bf_median, gdmt_b$bf_median),
  BF_CI_lo    = c(bb_b$bf_ci_lo, gdmt_b$bf_ci_lo),
  BF_CI_hi    = c(bb_b$bf_ci_hi, gdmt_b$bf_ci_hi),
  BER_aux     = c(bb_b$ber_median, gdmt_b$ber_median),
  BER_CI_lo   = c(bb_b$ci_lo, gdmt_b$ci_lo),
  BER_CI_hi   = c(bb_b$ci_hi, gdmt_b$ci_hi),
  Calibrated_P = c(bb$cal_p, gdmt$cal_p),
  Class       = c(bsr_res$bb$class, bsr_res$gdmt$class))
write.csv(tab1, file.path(TAB_DIR, "table01_BF_results.csv"), row.names = FALSE)
cat("  Saved: table01_BF_results.csv\n")

cat("\n===== PHASE 4 (v34) COMPLETE =====\n")
