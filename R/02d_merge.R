# R/02d_merge.R
# Merge the 8 per-config slice RDS files (comparison_results_cfg1..cfg8.rds) into the
# main comparison_results.rds and finalize aggregate + diagnostic outputs, exactly as the
# tail of R/02b_incremental.R would. Run ONLY after all 8 slices report COMPLETE.
source("R/00_config.R")
source("R/02_comparison_study.R")  # for compute_region_diagnostics

OUT_SIM <- SIM_DIR
slices  <- 1:8
results <- list()
for (s in slices) {
  f <- file.path(OUT_SIM, sprintf("comparison_results_cfg%d.rds", s))
  if (!file.exists(f)) stop(sprintf("slice %d RDS missing: %s", s, f))
  r <- readRDS(f)
  cat(sprintf("slice %d: %d conditions\n", s, length(r)))
  results <- c(results, r)
}
cat(sprintf("merged total n_keys = %d\n", length(results)))
stopifnot(length(results) == 336)

out_rds <- file.path(OUT_SIM, "comparison_results.rds")
saveRDS(results, paste0(out_rds, ".tmp"))
file.rename(paste0(out_rds, ".tmp"), out_rds)
cat("wrote comparison_results.rds (336 conditions)\n")

# ---- finalize aggregates + diagnostics (identical to R/02b tail) ----
agg <- do.call(rbind, lapply(names(results), function(k) {
  r <- results[[k]]; cm <- r$results
  data.frame(
    config_id = r$config_id, sigma_ps = r$sigma_ps,
    K = r$config$n_nc, ex_violation = r$config$ex_violation,
    psi = r$config$true_log_rr, mu_b = r$config$bias_mu,
    bf_true = r$bf_true, true_zone = r$true_zone,
    acc_mc = mean(cm$zone_mc == r$true_zone),
    acc_mcmc = mean(cm$zone_mcmc == r$true_zone),
    agree = mean(cm$zone_mc == cm$zone_mcmc),
    bias_mc = mean(cm$bf_mc - r$bf_true),
    bias_mcmc = mean(cm$bf_mcmc - r$bf_true),
    rmse_mc = sqrt(mean((cm$bf_mc - r$bf_true)^2)),
    rmse_mcmc = sqrt(mean((cm$bf_mcmc - r$bf_true)^2)))
}))
saveRDS(agg, file.path(OUT_SIM, "comparison_agg.rds"))
jsonlite::write_json(agg, file.path(OUT_SIM, "comparison_agg.json"),
                     dataframe = "columns", auto_unbox = TRUE, digits = 6, pretty = TRUE)

all_mc <- do.call(rbind, lapply(names(results), function(k) {
  r <- results[[k]]
  cbind(r$results[, c("rep", "bf_mc", "zone_mc")],
        true_zone = r$true_zone, config_id = r$config_id, sigma_ps = r$sigma_ps)
}))
all_mcmc <- do.call(rbind, lapply(names(results), function(k) {
  r <- results[[k]]
  cbind(r$results[, c("rep", "bf_mcmc", "zone_mcmc")],
        true_zone = r$true_zone, config_id = r$config_id, sigma_ps = r$sigma_ps)
}))
diag_mc   <- compute_region_diagnostics(all_mc$true_zone,   all_mc$zone_mc)
diag_mcmc <- compute_region_diagnostics(all_mcmc$true_zone, all_mcmc$zone_mcmc)
saveRDS(diag_mc,   file.path(OUT_SIM, "diag_mc.rds"))
saveRDS(diag_mcmc, file.path(OUT_SIM, "diag_mcmc.rds"))

cat(sprintf("=== MERGE COMPLETE: %d/%d conditions ===\n", length(results), 336))
writeLines(sprintf("COMPLETE %d/%d at %s", length(results), 336,
                   format(Sys.time(), "%H:%M:%S")),
           file.path(OUT_SIM, "run_progress.txt"))
