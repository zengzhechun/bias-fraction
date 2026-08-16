# Merge v35 simulation worker outputs (BF scale)
# v35 changes (review M6/M4): adds bsr_rel_bias (BER relative bias, non-null only,
# undefined at the null) and null-condition BF statistics columns to the summary
# table, supporting eTable 7 (BER vs BF relative bias per configuration).
source("R/00_config.R")
files <- list.files(SIM_DIR, pattern = "^sim_results_v35_.*\\.rds$", full.names = TRUE)
cat("Worker files found:\n"); print(basename(files))
dfs <- lapply(files, readRDS)
sim <- do.call(rbind, dfs)
cat(sprintf("Merged: %d conditions x %d columns\n", nrow(sim), ncol(sim)))

# BF-scale zone partition (identical to BER partition)
sim$zone <- ifelse(is.infinite(sim$bsr_true) | sim$bsr_true > 1, "bias-dominated",
            ifelse(sim$bsr_true < 0.5, "effect-dominated", "competitive"))
cat("Zone counts (conditions):\n"); print(table(sim$zone))

simulation_merged_v35 <- sim
saveRDS(simulation_merged_v35, file.path(SIM_DIR, "simulation_merged_v35.rds"))

# ---- Summary table (BF scale) ----
# bf_* columns: non-null conditions (continuity with v34 reporting); *_null
# columns: null conditions (psi = 0, bf_true = 1), where BER relative bias is
# undefined (reported as NA) but BF remains finite — review M6/G1.
finite_idx <- is.finite(sim$bsr_true)
null_idx <- sim$true_log_rr == 0
groups_all <- interaction(sim$ex_violation, sim$n_nc, sim$bias_sigma)
ugroups <- unique(groups_all[finite_idx])
tab <- do.call(rbind, lapply(ugroups, function(g) {
  idx <- finite_idx & groups_all == g
  gnull <- null_idx & groups_all == g
  data.frame(
    ex_violation = sim$ex_violation[idx][1],
    n_nc         = sim$n_nc[idx][1],
    bias_sigma   = sim$bias_sigma[idx][1],
    class_acc    = round(100 * mean(sim$bsr_class_accuracy[idx], na.rm = TRUE), 1),
    ohdsi_rej    = round(100 * mean(sim$ohdsi_rejection_rate[idx], na.rm = TRUE), 1),
    uncal_rej    = round(100 * mean(sim$uncal_rejection_rate[idx], na.rm = TRUE), 1),
    bsr_rel_bias = round(100 * mean(sim$bsr_rel_bias[idx], na.rm = TRUE), 1),
    bf_rel_bias  = round(100 * mean(sim$bf_rel_bias[idx], na.rm = TRUE), 1),
    bf_rmse      = round(mean(sim$bf_rmse[idx], na.rm = TRUE), 4),
    bf_rel_bias_null = round(100 * mean(sim$bf_rel_bias[gnull], na.rm = TRUE), 1),
    bf_rmse_null = round(mean(sim$bf_rmse[gnull], na.rm = TRUE), 4),
    ohdsi_rej_null = round(100 * mean(sim$ohdsi_rejection_rate[gnull], na.rm = TRUE), 1)
  )
}))
tab <- tab[order(tab$ex_violation, tab$n_nc, tab$bias_sigma), ]
write.csv(tab, file.path(TAB_DIR, "table02_simulation_summary_v35.csv"), row.names = FALSE)
cat("\nBF-scale simulation summary saved.\n")
print(tab)

cat(sprintf("\nOverall (non-null BF): mean rel bias = %.1f%%; mean RMSE = %.4f; median RMSE = %.4f\n",
  100 * mean(sim$bf_rel_bias[finite_idx], na.rm = TRUE),
  mean(sim$bf_rmse[finite_idx], na.rm = TRUE),
  median(sim$bf_rmse[finite_idx], na.rm = TRUE)))
cat(sprintf("Exchangeable (exV=0, non-null): mean rel bias = %.1f%%; violation (exV=0.3): %.1f%%\n",
  100 * mean(sim$bf_rel_bias[finite_idx & sim$ex_violation == 0], na.rm = TRUE),
  100 * mean(sim$bf_rel_bias[finite_idx & sim$ex_violation == 0.3], na.rm = TRUE)))
cat(sprintf("NULL conditions (v35, bf_true=1, n=%d): BF mean rel bias = %.1f%%; BF RMSE = %.4f; BER rel bias undefined\n",
  sum(null_idx),
  100 * mean(sim$bf_rel_bias[null_idx], na.rm = TRUE),
  mean(sim$bf_rmse[null_idx], na.rm = TRUE)))
cat(sprintf("All conditions incl. null: BF mean RMSE = %.4f; median RMSE = %.4f\n",
  mean(sim$bf_rmse, na.rm = TRUE), median(sim$bf_rmse, na.rm = TRUE)))
