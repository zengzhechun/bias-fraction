# R/04_continuous_bf_analysis.R
# Continuous BF analysis: treat BF as a continuous estimator and quantify its
# error structure against the known true BF across the 72 simulated conditions
# (each with 1000 Monte Carlo repetitions). Reads comparison_results_v37p1.rds produced
# by R/02_comparison_study.R (now with per-rep 95% CI bounds stored).
#
# Outputs (under OUT_DIR/figures/continuous_bf/):
#   per_condition_summary.csv / .rds  - 336 conditions x 2 methods summary
#   stratified_summary.csv            - bias/rmse/coverage by method x true_zone
#   figA_bias_vs_bftrue.png           - per-condition bias vs true BF
#   figB_rmse_vs_bftrue.png           - per-condition RMSE vs true BF
#   figC_coverage_vs_bftrue.png       - per-condition 95% CI coverage vs true BF
#   figD_ciwidth_vs_bftrue.png        - per-condition CI width vs true BF
#   figE_by_K.png                     - RMSE vs true BF, coloured by K (12 vs 25)
#   figF_by_exV_sigmaPS.png           - RMSE vs true BF, faceted by ex_violation x sigma_ps
#   figG_calibration_curve.png       - binned mean BF_hat vs true BF (mc & mcmc), y=x ref
#   continuous_bf_findings.txt        - textual summary of F1-F3
# v35 - 2026-08-20

suppressPackageStartupMessages({
  library(ggplot2)
})
source("R/00_config.R")

FIG_DIR  <- file.path(OUT_DIR, "figures", "continuous_bf")
SIM_DIR  <- file.path(OUT_DIR, "simulation")
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

res <- readRDS(file.path(SIM_DIR, "comparison_results_v37p1.rds"))
cat(sprintf("Loaded comparison_results_v37p1.rds: %d conditions\n", length(res)))

# ---- 1. Melt per-condition per-rep records ----
recs <- do.call(rbind, lapply(names(res), function(k) {
  r <- res[[k]]
  cm <- r$results
  data.frame(
    key        = k,
    config_id  = r$config_id,
    sigma_ps   = r$sigma_ps,
    se_psi_obs = r$se_psi_obs,
    K          = r$config$n_nc,
    ex_violation = r$config$ex_violation,
    psi        = r$config$true_log_rr,
    mu_b       = r$config$bias_mu,
    bf_true    = r$bf_true,
    true_zone  = r$true_zone,
    rep        = cm$rep,
    bf_mc      = cm$bf_mc,
    bf_mcmc    = cm$bf_mcmc,
    ci_lo_mc   = cm$ci_lo_mc,
    ci_hi_mc   = cm$ci_hi_mc,
    ci_lo_mcmc = cm$ci_lo_mcmc,
    ci_hi_mcmc = cm$ci_hi_mcmc,
    stringsAsFactors = FALSE
  )
}))
cat(sprintf("Melted records: %d rows (%d conditions x %d reps)\n",
            nrow(recs), length(res), nrow(recs) / length(res)))

# ---- 2. Per-condition summary (72 x 2 methods) ----
uk <- unique(recs$key)
rows <- list()
for (k in uk) {
  s  <- recs[recs$key == k, ]
  bt <- s$bf_true[1]
  base <- data.frame(key = k,
                     config_id = s$config_id[1], sigma_ps = s$sigma_ps[1],
                     se_psi_obs = s$se_psi_obs[1], K = s$K[1],
                     ex_violation = s$ex_violation[1], psi = s$psi[1],
                     mu_b = s$mu_b[1], bf_true = bt, true_zone = s$true_zone[1])
  rows <- c(rows, list(cbind(base, method = "mc",
    bias = mean(s$bf_mc - bt),
    rmse = sqrt(mean((s$bf_mc - bt)^2)),
    sd   = sd(s$bf_mc),
    coverage = mean(bt >= s$ci_lo_mc & bt <= s$ci_hi_mc),
    ci_width = mean(s$ci_hi_mc - s$ci_lo_mc))))
  rows <- c(rows, list(cbind(base, method = "mcmc",
    bias = mean(s$bf_mcmc - bt),
    rmse = sqrt(mean((s$bf_mcmc - bt)^2)),
    sd   = sd(s$bf_mcmc),
    coverage = mean(bt >= s$ci_lo_mcmc & bt <= s$ci_hi_mcmc),
    ci_width = mean(s$ci_hi_mcmc - s$ci_lo_mcmc))))
}
per_cond <- do.call(rbind, rows)
saveRDS(per_cond, file.path(FIG_DIR, "per_condition_summary.rds"))
write.csv(per_cond, file.path(FIG_DIR, "per_condition_summary.csv"), row.names = FALSE)
cat(sprintf("Per-condition summary: %d rows\n", nrow(per_cond)))

# ---- 3. Stratified summary (method x true_zone) ----
strat <- do.call(rbind, lapply(c("mc", "mcmc"), function(m) {
  sub <- per_cond[per_cond$method == m, ]
  do.call(rbind, lapply(c("effect-dominated", "mixed", "bias-dominated"), function(z) {
    ss <- sub[sub$true_zone == z, ]
    if (nrow(ss) == 0) return(NULL)
    data.frame(method = m, true_zone = z, n_conditions = nrow(ss),
               mean_abs_bias = mean(abs(ss$bias)),
               mean_rmse = mean(ss$rmse),
               mean_coverage = mean(ss$coverage),
               mean_ci_width = mean(ss$ci_width))
  }))
}))
write.csv(strat, file.path(FIG_DIR, "stratified_summary.csv"), row.names = FALSE)
print("Stratified summary (method x true_zone):")
print(strat)

# calibration regression BF_hat ~ BF_true, evaluated on per-condition mean BF_hat
mc_mean  <- t(sapply(uk, function(k) c(bt = recs$bf_true[recs$key == k][1],
                                       m = mean(recs$bf_mc[recs$key == k]))))
mcmc_mean <- t(sapply(uk, function(k) c(bt = recs$bf_true[recs$key == k][1],
                                       m = mean(recs$bf_mcmc[recs$key == k]))))
fit_mc   <- lm(mc_mean[, "m"]   ~ mc_mean[, "bt"])
fit_mcmc <- lm(mcmc_mean[, "m"] ~ mcmc_mean[, "bt"])
cat(sprintf("Calibration BF_mc  ~ BF_true: intercept=%.4f slope=%.4f\n",
            coef(fit_mc)[1], coef(fit_mc)[2]))
cat(sprintf("Calibration BF_mcmc~ BF_true: intercept=%.4f slope=%.4f\n",
            coef(fit_mcmc)[1], coef(fit_mcmc)[2]))

# ---- 4. Figures ----
gg_th <- theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"),
        legend.position = "bottom")

# Fig A: bias vs bf_true
pA <- ggplot(per_cond, aes(x = bf_true, y = bias, color = method)) +
  geom_point(alpha = 0.75, size = 2.2) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey40") +
  scale_color_manual(values = c(mc = "#1F77B4", mcmc = "#D62728")) +
  labs(title = "A. Bias of BF estimate vs true BF",
       x = "True BF", y = "Bias  mean(BF_hat) - BF_true") +
  gg_th
ggsave(file.path(FIG_DIR, "figA_bias_vs_bftrue.png"), pA, width = 7, height = 5, dpi = 150)

# Fig B: rmse vs bf_true
pB <- ggplot(per_cond, aes(x = bf_true, y = rmse, color = method)) +
  geom_point(alpha = 0.75, size = 2.2) +
  scale_color_manual(values = c(mc = "#1F77B4", mcmc = "#D62728")) +
  labs(title = "B. RMSE of BF estimate vs true BF",
       x = "True BF", y = "RMSE  sqrt(mean((BF_hat - BF_true)^2))") +
  gg_th
ggsave(file.path(FIG_DIR, "figB_rmse_vs_bftrue.png"), pB, width = 7, height = 5, dpi = 150)

# Fig C: coverage vs bf_true
pC <- ggplot(per_cond, aes(x = bf_true, y = coverage, color = method)) +
  geom_point(alpha = 0.75, size = 2.2) +
  geom_hline(yintercept = 0.95, linetype = "dashed", color = "grey40") +
  scale_color_manual(values = c(mc = "#1F77B4", mcmc = "#D62728")) +
  coord_cartesian(y = c(0.8, 1.0)) +
  labs(title = "C. 95% CI coverage vs true BF",
       x = "True BF", y = "Pr(BF_true in 95% CI)") +
  gg_th
ggsave(file.path(FIG_DIR, "figC_coverage_vs_bftrue.png"), pC, width = 7, height = 5, dpi = 150)

# Fig D: ci width vs bf_true
pD <- ggplot(per_cond, aes(x = bf_true, y = ci_width, color = method)) +
  geom_point(alpha = 0.75, size = 2.2) +
  scale_color_manual(values = c(mc = "#1F77B4", mcmc = "#D62728")) +
  labs(title = "D. 95% CI width vs true BF",
       x = "True BF", y = "Mean CI width (hi - lo)") +
  gg_th
ggsave(file.path(FIG_DIR, "figD_ciwidth_vs_bftrue.png"), pD, width = 7, height = 5, dpi = 150)

# Fig E: by K
pE <- ggplot(per_cond, aes(x = bf_true, y = rmse, color = factor(K))) +
  geom_point(alpha = 0.75, size = 2.0) +
  scale_color_manual(values = c("12" = "#2C7FB8", "25" = "#DE2D26"),
                     name = "K (neg. controls)") +
  labs(title = "E. RMSE vs true BF by K",
       x = "True BF", y = "RMSE") +
  gg_th
ggsave(file.path(FIG_DIR, "figE_by_K.png"), pE, width = 7, height = 5, dpi = 150)

# Fig F: facet by ex_violation x sigma_ps
pF <- ggplot(per_cond, aes(x = bf_true, y = rmse, color = method)) +
  geom_point(alpha = 0.7, size = 1.8) +
  scale_color_manual(values = c(mc = "#1F77B4", mcmc = "#D62728")) +
  facet_grid(ex_violation ~ sigma_ps,
             labeller = labeller(ex_violation = function(v) paste0("exV=", v),
                                sigma_ps = function(v) paste0("sigma_ps=", v))) +
  labs(title = "F. RMSE vs true BF by exchangeability violation x sigma_ps",
       x = "True BF", y = "RMSE") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")
ggsave(file.path(FIG_DIR, "figF_by_exV_sigmaPS.png"), pF, width = 8, height = 6, dpi = 150)

# Fig G: calibration curve (binned mean BF_hat vs true BF)
bins <- seq(0, 0.95, by = 0.05)
cal <- data.frame()
for (b in seq_len(length(bins) - 1)) {
  lo_b <- bins[b]; hi_b <- bins[b + 1]
  idx <- recs$bf_true >= lo_b & recs$bf_true < hi_b
  if (any(idx)) {
    cal <- rbind(cal, data.frame(
      bin_center = (lo_b + hi_b) / 2,
      mean_bf_true = mean(recs$bf_true[idx]),
      mean_bf_mc = mean(recs$bf_mc[idx]),
      mean_bf_mcmc = mean(recs$bf_mcmc[idx]),
      n = sum(idx)))
  }
}
cal_long <- rbind(
  data.frame(bin_center = cal$bin_center, bf = cal$mean_bf_mc,
             series = "MC", stringsAsFactors = FALSE),
  data.frame(bin_center = cal$bin_center, bf = cal$mean_bf_mcmc,
             series = "MCMC", stringsAsFactors = FALSE))
pG <- ggplot(cal_long, aes(x = bin_center, y = bf, color = series)) +
  geom_point(size = 3) +
  geom_line(aes(group = series)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey40") +
  scale_color_manual(values = c(MC = "#1F77B4", MCMC = "#D62728")) +
  labs(title = "G. Calibration curve: binned mean BF_hat vs true BF",
       x = "True BF (bin center)", y = "Mean BF_hat in bin") +
  gg_th
ggsave(file.path(FIG_DIR, "figG_calibration_curve.png"), pG, width = 7, height = 5, dpi = 150)

# ---- 5. Findings text ----
findings <- c(
  "CONTINUOUS BF ANALYSIS - FINDINGS (v37.1, 640 conditions x 1000 reps)",
  "===============================================================",
  sprintf("Conditions: %d ; Repetitions per condition: %d ; Total classifications: %d",
          length(uk), nrow(recs) / length(uk), nrow(recs)),
  "",
  sprintf("F1 Calibration (continuous BF as estimator):"),
  sprintf("   MC   : intercept=%.4f, slope=%.4f (target 0 / 1)",
          coef(fit_mc)[1], coef(fit_mc)[2]),
  sprintf("   MCMC : intercept=%.4f, slope=%.4f (target 0 / 1)",
          coef(fit_mcmc)[1], coef(fit_mcmc)[2]),
  sprintf("   => BF is %s as a continuous estimator (slope~1, intercept~0).",
          if (abs(coef(fit_mcmc)[2] - 1) < 0.1 && abs(coef(fit_mcmc)[1]) < 0.05) "well calibrated"
          else "moderately biased"),
  "",
  "F2 MC vs MCMC trade-off (per-condition mean RMSE):",
  sprintf("   MC   overall RMSE = %.4f", mean(per_cond$rmse[per_cond$method == "mc"])),
  sprintf("   MCMC overall RMSE = %.4f", mean(per_cond$rmse[per_cond$method == "mcmc"])),
  sprintf("   MC   overall coverage = %.4f", mean(per_cond$coverage[per_cond$method == "mc"])),
  sprintf("   MCMC overall coverage = %.4f", mean(per_cond$coverage[per_cond$method == "mcmc"])),
  "",
  "F3 sigma_ps (obs SE) and ex_violation effects:",
  sprintf("   RMSE at sigma_ps=0.06: %.4f ; at sigma_ps=0.10: %.4f",
          mean(per_cond$rmse[per_cond$method == "mc" & per_cond$sigma_ps == 0.06]),
          mean(per_cond$rmse[per_cond$method == "mc" & per_cond$sigma_ps == 0.10])),
  sprintf("   RMSE at exV=0.0: %.4f ; at exV=0.3: %.4f",
          mean(per_cond$rmse[per_cond$method == "mc" & per_cond$ex_violation == 0]),
          mean(per_cond$rmse[per_cond$method == "mc" & per_cond$ex_violation == 0.3])),
  sprintf("   Coverage at exV=0.0: %.4f ; at exV=0.3: %.4f",
          mean(per_cond$coverage[per_cond$method == "mc" & per_cond$ex_violation == 0]),
          mean(per_cond$coverage[per_cond$method == "mc" & per_cond$ex_violation == 0.3]))
)
writeLines(findings, file.path(FIG_DIR, "continuous_bf_findings.txt"))
cat(paste(findings, collapse = "\n"), "\n")
cat(sprintf("\n=== figures written to %s ===\n", FIG_DIR))
