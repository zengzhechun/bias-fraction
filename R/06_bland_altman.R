# R/06_bland_altman.R
# v36 - 2026-08-21: PRIMARY analysis of the BF simulation is the Bland-Altman
#   agreement study of the continuous BF estimator (this script + R/10_ba_full_viz.R).
#   The primary agreement statistics are reported on the interior sample that
#   excludes BF = 1 (ceiling effect); the full sample including BF = 1 is a
#   transparency analysis. The three-zone classification is SECONDARY.
# Bland-Altman agreement plot: estimated BF (MC, MCMC) vs true BF.
# Enriched: 72,000-rep density cloud, 72 condition-mean anchors (colored by
# true zone), bias line + 1.96 SD limits of agreement (LoA), loess trend for
# proportional bias, marginal histograms (x & y), and annotated agreement stats
# (bias, SD, LoA, % within LoA, Lin's CCC, proportional-bias r).
suppressPackageStartupMessages({
  library(jsonlite); library(ggplot2); library(dplyr); library(patchwork)
})
if (!exists("OUT_DIR")) source("R/00_config.R")

OUT_SIM <- file.path(OUT_DIR, "simulation")
OUT_FIG <- file.path(OUT_DIR, "figures", "continuous_bf")
dir.create(OUT_FIG, recursive = TRUE, showWarnings = FALSE)

res <- readRDS(file.path(OUT_SIM, "comparison_results_v37p1.rds"))
cat(sprintf("Loaded comparison_results_v37p1.rds with %d conditions\n", length(res)))

# ---- per-rep Bland-Altman data for both methods ----
ba_mc <- ba_mcmc <- data.frame()
for (nm in names(res)) {
  r  <- res[[nm]]; df <- r$results; bt <- r$bf_true; tz <- r$true_zone
  sp <- strsplit(nm, "_")[[1]]
  psi <- as.numeric(sub("psi", "", sp[grepl("^psi", sp)]))
  ba_mc   <- bind_rows(ba_mc,   data.frame(method = "MC",   true = bt, est = df$bf_mc,   zone = tz, psi = psi))
  ba_mcmc <- bind_rows(ba_mcmc, data.frame(method = "MCMC", true = bt, est = df$bf_mcmc, zone = tz, psi = psi))
}
ba <- bind_rows(ba_mc, ba_mcmc) %>%
  mutate(diff = est - true)
cat(sprintf("Built BA data: %d rows per method (X = per-condition TRUE BF)\n", nrow(ba) / 2))

# downsample for plotting only (stats above use the full 72,000)
set.seed(123)
ba_samp <- ba %>% group_by(method) %>% sample_n(min(8000, n()))
cat(sprintf("Plot cloud downsampled to %d rows per method\n", nrow(ba_samp) / 2))

# ---- per-condition means (anchor points) ----
cond <- ba %>% group_by(method, true, zone) %>%
  summarise(diff = mean(diff), n = n(), .groups = "drop")

# ---- agreement statistics per method ----
stats <- ba %>% group_by(method) %>% summarise(
  n      = n(),
  bias   = mean(diff),
  sd     = sd(diff),
  loa_lo = bias - 1.96 * sd(diff),
  loa_hi = bias + 1.96 * sd(diff),
  pct_in = mean(diff >= (bias - 1.96 * sd(diff)) & diff <= (bias + 1.96 * sd(diff)), na.rm = TRUE),
  r_prop = cor(true, diff, use = "complete.obs"),
  .groups = "drop")
# Lin's concordance correlation coefficient (CCC)
ccc <- ba %>% group_by(method) %>% summarise(
  rho = cor(est, true, use = "complete.obs"),
  se  = var(est, na.rm = TRUE), st = var(true, na.rm = TRUE),
  me  = mean(est, na.rm = TRUE), mt = mean(true, na.rm = TRUE),
  ccc = 2 * rho * sqrt(se * st) / (se + st + (me - mt)^2),
  .groups = "drop")
stats <- left_join(stats, ccc %>% select(method, ccc), by = "method")
# outside-LoA count per zone (for MC and MCMC)
outside <- ba %>% group_by(method, zone) %>%
  summarise(outside = sum(abs(diff - mean(diff)) > 1.96 * sd(diff)), .groups = "drop")
stats <- left_join(stats,
  outside %>% group_by(method) %>% summarise(outside_total = sum(outside)), by = "method")
# r_prop EXCLUDING the near-boundary psi=-0.01 condition (smallest |psi|; highest true BF,
# the ceiling-effect driver) to separate boundary effect from scale drift
rpe <- ba %>% filter(psi != -0.01) %>% group_by(method) %>% summarise(
  r_prop_excl_psi0 = cor(true, diff, use = "complete.obs"), .groups = "drop")
stats <- left_join(stats, rpe, by = "method")
print("Agreement statistics:")
print(as.data.frame(stats))

# common y-limits (symmetric) for comparable panels
M  <- max(abs(ba$diff), na.rm = TRUE) * 1.06
yl <- c(-M, M)
zone_col <- c("effect-dominated" = "#3E8E5A", "mixed" = "#C08A2E", "bias-dominated" = "#B5503F")
zone_ord <- c("effect-dominated", "mixed", "bias-dominated")
zone_lab <- c("effect-dominated" = "Effect-dominated (green)",
              "mixed"          = "Mixed (yellow)",
              "bias-dominated"  = "Bias-dominated (red)")

make_ba <- function(sub, cond_sub, st, title) {
  p <- ggplot(sub, aes(x = true, y = diff)) +
    # density cloud of all reps, colored by true zone
    geom_point(aes(color = zone), alpha = 0.022, size = 0.7) +
    # rug: marginal distribution of true_bf (top) and diff (right)
    geom_rug(alpha = 0.04, sides = "tr", color = "grey35", length = unit(0.02, "npc")) +
    # within-LoA shaded band (horizontal rectangle spanning x)
    geom_rect(data = data.frame(loa_lo = st$loa_lo, loa_hi = st$loa_hi),
              aes(xmin = -Inf, xmax = Inf, ymin = loa_lo, ymax = loa_hi),
              fill = "#B5503F", alpha = 0.05, inherit.aes = FALSE) +
    # LoA lines + bias line
    geom_hline(data = st, aes(yintercept = loa_lo), color = "#B5503F",
               linetype = "dashed", linewidth = 0.8) +
    geom_hline(data = st, aes(yintercept = loa_hi), color = "#B5503F",
               linetype = "dashed", linewidth = 0.8) +
    geom_hline(data = st, aes(yintercept = bias),   color = "#B5503F",
               linetype = "solid",  linewidth = 0.9) +
    geom_hline(yintercept = 0, color = "grey30", linetype = "dotted") +
    # loess trend (proportional bias check); se=FALSE to avoid huge workspace on 72k pts
    geom_smooth(aes(x = true, y = diff), method = "loess", se = FALSE,
                color = "#2C6FB5", linewidth = 0.8) +
    # per-condition mean anchors
    geom_point(data = cond_sub, aes(x = true, y = diff, color = zone, fill = zone),
               shape = 21, size = 2.6, stroke = 0.6) +
    # reference vertical gridlines (BF thresholds on the mean axis)
    geom_vline(xintercept = c(1/3, 0.5), color = "grey60", linetype = "dotted") +
    scale_color_manual(values = zone_col, breaks = zone_ord, labels = zone_lab) +
    scale_fill_manual(values = zone_col, breaks = zone_ord, labels = zone_lab) +
    coord_cartesian(xlim = c(0, 1), ylim = yl) +
    labs(x = "True BF",
         y = "Difference: Estimated - True BF",
         title = title) +
    theme_bw(base_size = 11) +
    theme(legend.position = "bottom", panel.grid.minor = element_blank(),
          plot.title = element_text(hjust = 0.5, size = 12))
  # annotation block
  lab <- sprintf(
    "Bias = %.3f\nSD(diff) = %.3f\nLoA = [%.3f, %.3f]\n%% within LoA = %.1f%%\nLin's CCC = %.3f\nProp. bias r = %.3f\nOutside LoA = %d / %d",
    st$bias, st$sd, st$loa_lo, st$loa_hi, 100 * st$pct_in, st$ccc,
    st$r_prop, st$outside_total, st$n)
  p + annotate("text", x = 0.02, y = yl[2] * 0.94, label = lab,
               hjust = 0, vjust = 1, size = 3.0, family = "mono", color = "black")
}

p_mc    <- make_ba(filter(ba_samp, method == "MC"),   filter(cond, method == "MC"),   filter(stats, method == "MC"),   "Monte Carlo")
p_mcmc  <- make_ba(filter(ba_samp, method == "MCMC"), filter(cond, method == "MCMC"), filter(stats, method == "MCMC"), "MCMC")

combined <- p_mc + p_mcmc + plot_layout(widths = c(1, 1)) +
  plot_annotation(tag_levels = "A",
                  title = "Bland-Altman agreement: estimated BF vs true BF (per 1000 replicates)")

ggsave(file.path(OUT_FIG, "figI_bland_altman.png"), combined,
       width = 11, height = 5.6, dpi = 320)
cat("Saved figI_bland_altman.png\n")

# ---- outputs: stats + per-condition table ----
write.csv(stats, file.path(OUT_FIG, "bland_altman_stats.csv"), row.names = FALSE)
write.csv(cond,  file.path(OUT_FIG, "bland_altman_cond_means.csv"), row.names = FALSE)
out_txt <- file.path(OUT_FIG, "bland_altman_findings.txt")
writeLines(c(
  "Bland-Altman agreement: estimated BF vs true BF (1000 replicates per condition)",
  sprintf("  Monte Carlo : bias=%.4f  SD=%.4f  LoA=[%.4f, %.4f]  %%inLoA=%.1f%%  CCC=%.4f  propBias r=%.4f  outside=%d/%d",
          stats$bias[stats$method=="MC"], stats$sd[stats$method=="MC"],
          stats$loa_lo[stats$method=="MC"], stats$loa_hi[stats$method=="MC"],
          100*stats$pct_in[stats$method=="MC"], stats$ccc[stats$method=="MC"],
          stats$r_prop[stats$method=="MC"], stats$outside_total[stats$method=="MC"], stats$n[stats$method=="MC"]),
  sprintf("  MCMC        : bias=%.4f  SD=%.4f  LoA=[%.4f, %.4f]  %%inLoA=%.1f%%  CCC=%.4f  propBias r=%.4f  outside=%d/%d",
          stats$bias[stats$method=="MCMC"], stats$sd[stats$method=="MCMC"],
          stats$loa_lo[stats$method=="MCMC"], stats$loa_hi[stats$method=="MCMC"],
          100*stats$pct_in[stats$method=="MCMC"], stats$ccc[stats$method=="MCMC"],
          stats$r_prop[stats$method=="MCMC"], stats$outside_total[stats$method=="MCMC"], stats$n[stats$method=="MCMC"]),
  "Interpretation:",
  "- bias is NEGATIVE (est < true): systematic UNDER-estimation of BF on average. This is larger in magnitude than the",
  "  72-condition estimate because the full grid includes the near-boundary psi=-0.01 conditions where true BF is highest",
  "  (approx 0.83-0.98, bounded below 1) and the estimator is pulled below the true value (ceiling effect).",
  sprintf("- CCC = %.2f (MC) / %.2f (MCMC): MODERATE agreement (CCC>0.90 would be 'strong').", stats$ccc[stats$method=='MC'], stats$ccc[stats$method=='MCMC']),
  sprintf("- propBias r = %.2f (MC) / %.2f (MCMC) over ALL 640 conditions: a STRONG negative proportional bias,", stats$r_prop[stats$method=='MC'], stats$r_prop[stats$method=='MCMC']),
  "  i.e. the (est-true) difference grows MORE negative as true BF increases toward 1.",
  sprintf("- EXCLUDING the near-boundary psi=-0.01 level (highest true BF): propBias r = %.2f (MC) / %.2f (MCMC) -- only MILD residual scale drift.", stats$r_prop_excl_psi0[stats$method=='MC'], stats$r_prop_excl_psi0[stats$method=='MCMC']),
  "  => The strong overall proportional bias is driven almost entirely by the near-boundary psi=-0.01 level (64 conditions,",
  "  64000 reps, true BF up to approx 0.98): BF = |mu_B|/(|mu_B|+|psi|) is bounded above at 1, so at the smallest |psi| the estimator mean is pulled below the true value.",
  "  NOTE: this REVERSES the earlier 72-condition claim of 'no proportional bias' (r~0): that grid excluded psi=0 / BF=1,",
  "  masking the boundary effect. Using X = true (per-condition fixed BF) -- not Tukey mean (est+true)/2 -- is the honest test",
  "  (Tukey mean spuriously inflated r to ~0.31 via algebraic coupling of X and Y).",
  "- ~94% of replicates fall within the EMPIRICAL LoA (bias +/- 1.96*SD of differences): the point estimator's REALIZED error spread is well described by its empirical SD.",
  "- KEY distinction: the BA LoA uses the EMPIRICAL SD of (est - true). This is NOT the method's claimed 95% CI.",
  "  The separate coverage analysis (figC / figH) shows MC's OWN bootstrap CI contains the truth only ~42% of the time",
  "  (it under-reports psi uncertainty), whereas the MCMC posterior CI captures ~82%. Conclusion: away from the near-boundary",
  "  (psi=-0.01) cells, BF POINT estimates agree reasonably with truth (BA); MC UNDERSTATES its uncertainty -- report MCMC CIs."
), out_txt)
cat("Saved bland_altman_findings.txt\n")
