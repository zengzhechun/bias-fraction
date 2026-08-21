# R/12_build_sim_frame.R
# Rebuild the 22-column "simulation_merged_v35.rds" frame consumed by the four
# v36/v37 Quarto manuscripts, using the FRESH v37 per-repetition data
# (comparison_results_v37p1.rds: 336 conditions x 1000 reps, no psi=0 null design point,
# with OHDSI calibrated p-value cal_p and naive p-value naive_p).
#
# The qmd setup chunk classifies zones via bsr_true with the partition
#   bd_idx = bsr_true > 1 ; cp_idx = 0.5 <= bsr_true <= 1 ; sd_idx = bsr_true < 0.5
# which is algebraically identical to the v37 true_zone partition
#   bias-dominated  (bf_true > 0.5)
#   mixed           (0.33 <= bf_true <= 0.5)
#   effect-dominated (bf_true < 0.33)
# because bsr = bf/(1-bf). So rebuilding the frame with v37 data makes the qmd
# render correct v37 numbers without touching the setup chunk.
source("R/00_config.R")

bsr_to_bf <- function(bsr) bsr / (1 + bsr)

res <- readRDS(file.path(SIM_DIR, "comparison_results_v37p1.rds"))
cat(sprintf("loaded comparison_results_v37p1.rds: %d conditions\n", length(res)))

rows <- list()
for (k in names(res)) {
  r  <- res[[k]]
  cm <- r$results
  psi   <- r$config$true_log_rr
  mu_b  <- r$config$bias_mu
  bsr_t <- abs(mu_b) / abs(psi)                     # finite for all v37 psi != 0
  bf_t  <- bsr_to_bf(bsr_t)
  bt    <- r$true_zone

  bf_mc   <- cm$bf_mc
  bsr_mc  <- bf_mc / (1 - bf_mc)
  bf_mcmc <- cm$bf_mcmc

  rows[[k]] <- data.frame(
    true_log_rr   = psi,
    bias_mu       = mu_b,
    bias_sigma    = r$config$bias_sigma,    # 0.05 fixed in v37
    n_nc          = r$config$n_nc,
    ex_violation  = r$config$ex_violation,
    bsr_true      = bsr_t,
    bf_true       = bf_t,
    bsr_mean      = mean(bsr_mc),
    bsr_median    = median(bsr_mc),
    bsr_sd        = stats::sd(bsr_mc),
    bsr_rmse      = sqrt(mean((bsr_mc - bsr_t)^2)),
    bsr_rel_bias  = mean((bsr_mc - bsr_t) / bsr_t),
    bf_mean       = mean(bf_mc),
    bf_median     = median(bf_mc),
    bf_sd         = stats::sd(bf_mc),
    bf_rmse       = sqrt(mean((bf_mc - bf_t)^2)),
    bf_rel_bias   = mean((bf_mc - bf_t) / bf_t),
    bsr_class_accuracy    = mean(cm$zone_mc == bt),
    ohdsi_rejection_rate  = mean(cm$cal_p   < 0.05),
    uncal_rejection_rate  = mean(cm$naive_p < 0.05),
    n_success     = nrow(cm),
    zone          = bt,
    stringsAsFactors = FALSE
  )
}
sim <- do.call(rbind, rows)
rownames(sim) <- NULL
stopifnot(nrow(sim) == 640, ncol(sim) == 22)

out_rds <- file.path(SIM_DIR, "simulation_merged_v35.rds")
saveRDS(sim, paste0(out_rds, ".tmp"))
file.rename(paste0(out_rds, ".tmp"), out_rds)
cat(sprintf("wrote %s (%d x %d)\n", out_rds, nrow(sim), ncol(sim)))

# ---- replicate the qmd setup chunk computations for a sanity check ----
bd_idx <- sim$bsr_true > 1 | is.infinite(sim$bsr_true)
cp_idx <- sim$bsr_true >= 0.5 & sim$bsr_true <= 1
sd_idx <- sim$bsr_true < 0.5
finite_idx <- is.finite(sim$bsr_true)
cat("\n=== SANITY CHECK (should match v37 manuscript) ===\n")
cat(sprintf("N bias-dom / mixed / effect-dom / overall = %d / %d / %d / %d\n",
            sum(bd_idx), sum(cp_idx), sum(sd_idx), nrow(sim)))
cat(sprintf("BF_Acc bias-dom / mixed / effect-dom / overall = %.1f / %.1f / %.1f / %.1f\n",
            100*mean(sim$bsr_class_accuracy[bd_idx]),
            100*mean(sim$bsr_class_accuracy[cp_idx]),
            100*mean(sim$bsr_class_accuracy[sd_idx]),
            100*mean(sim$bsr_class_accuracy)))
cat(sprintf("OHDSI_Rej bias-dom / mixed / effect-dom / overall = %.1f / %.1f / %.1f / %.1f\n",
            100*mean(sim$ohdsi_rejection_rate[bd_idx]),
            100*mean(sim$ohdsi_rejection_rate[cp_idx]),
            100*mean(sim$ohdsi_rejection_rate[sd_idx]),
            100*mean(sim$ohdsi_rejection_rate)))
cat(sprintf("exV0 acc / exV3 acc = %.1f / %.1f\n",
            100*mean(sim$bsr_class_accuracy[sim$ex_violation==0]),
            100*mean(sim$bsr_class_accuracy[sim$ex_violation==0.3])))
cat(sprintf("exV0 OHDSI / exV3 OHDSI = %.1f / %.1f\n",
            100*mean(sim$ohdsi_rejection_rate[sim$ex_violation==0]),
            100*mean(sim$ohdsi_rejection_rate[sim$ex_violation==0.3])))
cat(sprintf("bf_relbias all / exV0 / exV3 = %.1f / %.1f / %.1f\n",
            100*mean(sim$bf_rel_bias[finite_idx]),
            100*mean(sim$bf_rel_bias[finite_idx & sim$ex_violation==0]),
            100*mean(sim$bf_rel_bias[finite_idx & sim$ex_violation==0.3])))
cat(sprintf("bf_rmse mean / median = %.3f / %.3f\n",
            mean(sim$bf_rmse[finite_idx]), median(sim$bf_rmse[finite_idx])))
cat(sprintf("finite conditions = %d (expect 640)\n", sum(finite_idx)))
