# Phase 1-2 (v35): BF Case Study Analysis
# v34: Bias Fraction (BF) is the primary metric; BER retained as auxiliary ratio.
# Point estimates are bootstrap medians (log scale); CIs are log-scale bootstrap
# percentiles back-transformed (logit scale for BF). Fieller intervals computed
# as robustness checks. bsr_bootstrap uses seed = 42, so re-runs are bit-identical.
# v35: output file bumped to bsr_results_v35.rds (analysis logic unchanged).
source("R/00_config.R")
source("R/01_bsr_core.R")
library(data.table)
library(EmpiricalCalibration)

cat("============================================\n")
cat("PHASE 1-2 (v35): BF Case Study Analysis\n")
cat("============================================\n\n")

# ---- Load Data (v33-derived RDS files, copied into v35/output) ----
nc    <- readRDS(file.path(DATA_DIR, "negative_controls_expanded.rds"))
cal   <- readRDS(file.path(DATA_DIR, "bias_calibration_results.rds"))
grace <- readRDS(file.path(DATA_DIR, "grace_period_guideline_results.rds"))
sl    <- readRDS(file.path(DATA_DIR, "sl_three_config.rds"))
gp_sens <- readRDS(file.path(OUT_DIR, "data", "grace_period_sensitivity.rds"))

nc_est <- nc$estimates
nc_log_rr <- nc_est$logRr
nc_se <- nc_est$seLogRr
names(nc_log_rr) <- nc_est$outcome
names(nc_se) <- nc_est$outcome

# ---- 1. BB 1-Year BF ----
cat("\n===== 1. BB 1-Year Mortality BF =====\n")
ex <- grace$grace_period_exclusion
bb_log_rr <- log(ex$rr)
bb_se <- (log(ex$rr_ci[2]) - log(ex$rr_ci[1])) / (2 * 1.96)

bb_bsr <- bsr_estimate(bb_log_rr, bb_se, nc_log_rr, nc_se)
bb_boot <- bsr_bootstrap(bb_log_rr, bb_se, nc_log_rr, nc_se)
bb_class <- bsr_classify(bb_bsr$bsr, bb_boot$ci_lo, bb_boot$ci_hi)

# Fieller robustness: v11 = Var(mu_B) estimated from the bootstrap draws of mu_B.
bb_mu_var <- var(bb_boot$mu_draws, na.rm = TRUE)
bb_fieller <- tryCatch(
  bsr_fieller(bb_bsr$mu_bias, bb_mu_var, bb_log_rr, bb_se),
  error = function(e) NULL)
if (!is.null(bb_fieller)) {
  cat(sprintf("Fieller set for mu_B/psi_tilde: region=%s, bounds=[%.4f, %.4f]\n",
    bb_fieller$region, bb_fieller$lo, bb_fieller$hi))
} else cat("Fieller interval: failed\n")

cat(sprintf("BB uncal RR: %.3f (logRR=%.4f)\n", bb_bsr$rr_uncal, bb_bsr$log_rr_uncal))
cat(sprintf("Bias mu: %.4f (RR=%.3f), sigma_B: %.4f\n", bb_bsr$mu_bias, bb_bsr$rr_bias, bb_bsr$sigma_bias))
cat(sprintf("Calibrated RR: %.3f (logRR=%.4f)\n", bb_bsr$rr_true, bb_bsr$log_rr_true))
cat(sprintf("BER (raw ratio): %.3f\n", bb_bsr$bsr))
cat(sprintf("BER (bootstrap median): %.3f [%.3f, %.3f]\n", bb_boot$ber_median, bb_boot$ci_lo, bb_boot$ci_hi))
cat(sprintf("BF (bootstrap median): %.4f [%.4f, %.4f]\n", bb_boot$bf_median, bb_boot$bf_ci_lo, bb_boot$bf_ci_hi))
cat(sprintf("BF (raw ratio): %.4f\n", bb_bsr$bf))
cat(sprintf("Classification: %s\n", bb_class))
cat(sprintf("Calibrated p: %.4f\n", bb_bsr$cal_p))

# ---- 2. GDMT BF ----
cat("\n===== 2. GDMT BF =====\n")
gdmt <- cal$calibrated[["GDMT >=2/3 Classes (1-Year)"]]
gdmt_log_rr <- log(gdmt$rr)
gdmt_se <- gdmt$seLogRr

gdmt_bsr <- bsr_estimate(gdmt_log_rr, gdmt_se, nc_log_rr, nc_se)
gdmt_boot <- bsr_bootstrap(gdmt_log_rr, gdmt_se, nc_log_rr, nc_se)
gdmt_class <- bsr_classify(gdmt_bsr$bsr, gdmt_boot$ci_lo, gdmt_boot$ci_hi)

cat(sprintf("GDMT uncal RR: %.3f (logRR=%.4f)\n", gdmt_bsr$rr_uncal, gdmt_bsr$log_rr_uncal))
cat(sprintf("Calibrated RR: %.3f (logRR=%.4f)\n", gdmt_bsr$rr_true, gdmt_bsr$log_rr_true))
cat(sprintf("BER (bootstrap median): %.3f [%.3f, %.3f]\n", gdmt_boot$ber_median, gdmt_boot$ci_lo, gdmt_boot$ci_hi))
cat(sprintf("BF (bootstrap median): %.4f [%.4f, %.4f]\n", gdmt_boot$bf_median, gdmt_boot$bf_ci_lo, gdmt_boot$bf_ci_hi))
cat(sprintf("Classification: %s\n", gdmt_class))

# ---- 3. LOO Sensitivity (BF) ----
cat("\n===== 3. BF LOO Sensitivity =====\n")
bb_loo <- bsr_loo(bb_log_rr, bb_se, nc_log_rr, nc_se)
cat(sprintf("BB LOO BF range: [%.3f, %.3f]\n", min(bb_loo$bf), max(bb_loo$bf)))
cat(sprintf("All LOO classifications consistent: %s\n",
  all(bb_loo$class == bb_loo$class[1])))
print(bb_loo[, c("excluded_nc", "bf", "class")])

# ---- 4. SL Configurations (BF) ----
cat("\n===== 4. BF SL Sensitivity =====\n")
sl_configs <- c("SL.glm", "SL.glm+SL.gam", "SL.glm+SL.gam+SL.xgboost")
sl_rr <- c(sl$glm_only$rr, sl$glm_gam$rr, sl$full$rr)
sl_ci_lo <- c(sl$glm_only$rr_ci_lo, sl$glm_gam$rr_ci_lo, sl$full$rr_ci_lo)
sl_ci_hi <- c(sl$glm_only$rr_ci_hi, sl$glm_gam$rr_ci_hi, sl$full$rr_ci_hi)
sl_bsr_vals <- numeric(3); sl_bf_vals <- numeric(3)
sl_bf_ci <- matrix(NA_real_, nrow = 3, ncol = 2)
for (i in seq_along(sl_configs)) {
  sl_log_rr <- log(sl_rr[i])
  sl_se <- (log(sl_ci_hi[i]) - log(sl_ci_lo[i])) / (2 * 1.96)
  res <- bsr_estimate(sl_log_rr, sl_se, nc_log_rr, nc_se)
  boot <- bsr_bootstrap(sl_log_rr, sl_se, nc_log_rr, nc_se)
  sl_bsr_vals[i] <- res$bsr
  sl_bf_vals[i]  <- boot$bf_median
  sl_bf_ci[i, ]  <- c(boot$bf_ci_lo, boot$bf_ci_hi)
  cat(sprintf("  %s: raw BER=%.1f; BF (boot median)=%.3f [%.3f, %.3f]; class=%s\n",
    sl_configs[i], res$bsr, boot$bf_median, boot$bf_ci_lo, boot$bf_ci_hi,
    bsr_classify(res$bsr, boot$ci_lo, boot$ci_hi)))
}

# ---- 5. Diagnostics ----
cat("\n===== 5. Diagnostics =====\n")
diag <- bsr_diagnostics(nc_log_rr, nc_se)
cat(sprintf("Shapiro-Wilk p = %.4f %s\n", diag$shapiro_p,
  ifelse(diag$shapiro_p > 0.05, "(normal OK)", "(non-normal)")))
cat(sprintf("Max |Standardized Residual| = %.3f (NC: %s)\n",
  max(diag$std_residual_abs), names(nc_log_rr)[which.max(diag$std_residual_abs)]))
en_fit <- fitNull(nc_log_rr, nc_se)
cat(sprintf("Empirical null: mu=%.4f, sigma=%.4f\n", en_fit[1], en_fit[2]))

# ---- 6. Grace Period Sensitivity (BF) ----
cat("\n===== 6. Grace Period Sensitivity (BF) =====\n")
gp_results <- data.frame(
  grace_period = integer(), n_cohort = integer(),
  uncal_rr = numeric(), cal_rr = numeric(),
  bsr = numeric(), bf = numeric(), class = character(),
  stringsAsFactors = FALSE
)
for (gp_day in names(gp_sens)) {
  rr_uncal <- gp_sens[[gp_day]]$rr
  log_rr <- log(rr_uncal)
  res <- bsr_estimate(log_rr, bb_se, nc_log_rr, nc_se)
  cls <- bsr_classify(res$bsr, NA, NA)
  gp_results <- rbind(gp_results, data.frame(
    grace_period = as.integer(gp_day),
    n_cohort = gp_sens[[gp_day]]$n_survivors,
    uncal_rr = round(rr_uncal, 4),
    cal_rr = round(res$rr_true, 4),
    bsr = round(res$bsr, 2),
    bf = round(res$bf, 4),
    class = cls,
    stringsAsFactors = FALSE
  ))
  cat(sprintf("  GP=%2d days: uncal_rr=%.4f, cal_rr=%.4f, BF=%.3f, class=%s\n",
    as.integer(gp_day), rr_uncal, res$rr_true, res$bf, cls))
}
cal_range <- range(gp_results$cal_rr)
cat(sprintf("\n  Calibrated RR range: [%.4f, %.4f]\n", cal_range[1], cal_range[2]))
cat(sprintf("  All classifications: %s\n",
  ifelse(length(unique(gp_results$class)) == 1,
    paste0("consistent (all ", unique(gp_results$class), ")"), "INCONSISTENT")))

# ---- Save Results (v35) ----
gdmt_mu_var <- var(gdmt_boot$mu_draws, na.rm = TRUE)
gdmt_fieller <- tryCatch(
  bsr_fieller(gdmt_bsr$mu_bias, gdmt_mu_var, gdmt_log_rr, gdmt_se),
  error = function(e) NULL)
if (!is.null(gdmt_fieller)) {
  cat(sprintf("GDMT Fieller set: region=%s, bounds=[%.4f, %.4f]\n",
    gdmt_fieller$region, gdmt_fieller$lo, gdmt_fieller$hi))
}

results <- list(
  bb = list(bsr = bb_bsr, boot = bb_boot, class = bb_class, fieller = bb_fieller),
  gdmt = list(bsr = gdmt_bsr, boot = gdmt_boot, class = gdmt_class, fieller = gdmt_fieller),
  loo = bb_loo,
  sl = data.frame(config = sl_configs, rr = sl_rr,
                  rr_ci_lo = sl_ci_lo, rr_ci_hi = sl_ci_hi,
                  bsr = sl_bsr_vals, bf = sl_bf_vals,
                  bf_ci_lo = sl_bf_ci[, 1], bf_ci_hi = sl_bf_ci[, 2],
                  stringsAsFactors = FALSE),
  diagnostics = diag,
  grace_period_sensitivity = gp_results,
  timestamp = Sys.time()
)
saveRDS(results, file.path(OUT_DIR, "data", "bsr_results_v35.rds"))
cat(sprintf("\nSaved: %s\n", file.path(OUT_DIR, "data", "bsr_results_v35.rds")))
cat("===== PHASE 1-2 (v35) COMPLETE =====\n")
