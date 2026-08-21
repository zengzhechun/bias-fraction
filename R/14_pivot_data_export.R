## Compute per-condition summary stats for the new interactive pivot table.
## Output: pivot_data.json embedded by the HTML.

suppressPackageStartupMessages({
  library(data.table)
  library(jsonlite)
})

BASE <- "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/manuscript_v37"
OUT_JSON <- file.path(BASE, "output/figures/continuous_bf/pivot_data.json")

sim <- readRDS(file.path(BASE, "output/simulation/comparison_results_v37p1.rds"))

rows <- list()
for (nm in names(sim)) {
  cond <- sim[[nm]]
  r <- cond$results
  bt <- cond$bf_true
  bf <- r$bf_mc
  diff <- bf - bt

  ## classification accuracy (MC)
  acc <- mean(r$zone_mc == cond$true_zone, na.rm = TRUE) * 100

  rows[[nm]] <- data.table(
    cond_key   = nm,
    psi        = cond$config$true_log_rr,
    mu_b       = cond$config$bias_mu,
    sigma_ps   = cond$sigma_ps,
    K          = cond$config$n_nc,
    ex_violation = cond$config$ex_violation,
    bf_true    = bt,
    mae        = mean(abs(diff), na.rm = TRUE),
    rmse       = sqrt(mean(diff^2, na.rm = TRUE)),
    mean_bias  = mean(diff, na.rm = TRUE),
    coverage   = mean(r$ci_lo_mc <= bt & bt <= r$ci_hi_mc, na.rm = TRUE) * 100,
    ci_width   = mean(r$ci_hi_mc - r$ci_lo_mc, na.rm = TRUE),
    accuracy   = acc
  )
}
dt <- rbindlist(rows, use.names = TRUE)
cat(sprintf("Conditions: %d, columns: %d\n", nrow(dt), ncol(dt)))

## Build factor labels for dropdowns
factor_levels <- list(
  psi    = c(-0.01, -0.05, -0.10, -0.15, -0.20, -0.30, -0.40),
  mu_b   = c(-0.05, -0.10, -0.15, -0.20, -0.30, -0.40),
  sigma_ps = c(0.06, 0.10),
  K      = c(12, 25),
  ex_violation = c(0, 0.3)
)

stat_cols <- c("mae", "rmse", "mean_bias", "coverage", "ci_width", "accuracy")
stat_labels <- c(
  mae = "MAE (mean |BF̂−BF_true|)",
  rmse = "RMSE",
  mean_bias = "Mean bias",
  coverage = "95% CI coverage (%)",
  ci_width = "Mean CI width",
  accuracy = "Classification accuracy (%)"
)

dt_json <- list(
  factor_levels = factor_levels,
  stat_cols = stat_cols,
  stat_labels = stat_labels,
  records = dt
)

write_json(dt_json, OUT_JSON, auto_unbox = TRUE, digits = 6, pretty = FALSE)
cat("Wrote:", OUT_JSON, sprintf("(%d KB)\n", file.info(OUT_JSON)$size %/% 1024))