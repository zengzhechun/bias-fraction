# R/16_sim_v37p1_80grid.R
# 80-cell simulation rerun (psi 10 levels x mu_B 8 levels)
# v39b - 2026-09-01: added a third negative-control panel size, K = 50, giving
#   three levels (12, 25, 50). 12 and 25 are unchanged; 50 probes whether the
#   estimator keeps improving once the panel is far larger than the 12-control
#   cardiovascular panel actually available in MIMIC-IV. Per-condition cost is
#   driven by the 400-iteration Gibbs sampler, NOT by K (measured 2026-09-01:
#   19.9 s/condition at K = 25 vs 21.6 s at K = 50, +8.5%), so the 320 added
#   conditions cost roughly 1.5-2.5 h rather than a doubling of runtime.
# 10 x 8 x (2 sigma_ps) x (3 K) x (2 exV) = 960 conditions
# x 1000 reps = 960,000 analyses
#
# Replaces v37 (7 x 6 = 42 psi x mu_B pairs) with the finer 10 x 8 grid
# confirmed by user on 2026-08-21 (work-log ⑫ + ⑮). v37 backup is at
# output/simulation/_v37_backup/ (full RDS + cfg1-cfg8 splits).
#
# Same engine as R/02_comparison_study.R: MCMC Gibbs (mcmc_fit_null)
# vs EmpiricalCalibration fitNull (Monte Carlo). Same mcmc_iter=400,
# warmup=100, n_rep=1000, sigma_B fixed at 0.05.
# New design: 10 psi levels (evenly spaced -0.40 -> -0.01) and
# 8 mu_B levels (evenly spaced -0.40 -> -0.05); the v37 grid is a
# subset so direct comparison on shared cells stays clean.
#
# Resume: this script overwrites output/simulation/comparison_results.rds
# incrementally after every condition (atomic rename), and skips any
# condition already present in the RDS on relaunch.

source("R/00_config.R")
source("R/02_comparison_study.R")  # defines run_method_compare, build_design_matrix, demo_8_config, etc.

OUT_SIM <- SIM_DIR
# Save to v37p1-specific paths during the run so v37's main RDS stays untouched
# until the user explicitly swaps (post-completion). v37 backup remains at
# output/simulation/_v37_backup/comparison_results.rds as a safety net.
out_rds  <- file.path(OUT_SIM, "comparison_results_v37p1.rds")
prog_txt <- file.path(OUT_SIM, "run_progress_v37p1.txt")

# ---- v37p1 grids (10 x 8 = 80 psi x mu_B pairs) ----
psi_vals  <- round(seq(-0.40, -0.01, length.out = 10), 2)
mu_b_vals <- round(seq(-0.40, -0.05, length.out = 8),  2)
sigma_ps_vals     <- c(0.06, 0.10)
K_vals            <- c(12, 25, 50)   # v39b: 50 added 2026-09-01; appended LAST on purpose (see configs note below)
ex_violation_vals <- c(0.0, 0.3)
mcmc_iter <- 400; mcmc_warmup <- 100
n_rep <- 1000; seed <- 43    # v37 used seed=42; v37p1 uses seed=43 (independent RNG stream)

cat("=========================================================\n")
cat(sprintf(" v37p1 design: %d psi x %d mu_B x %d (sigma_ps,K,exV) configs\n",
            length(psi_vals), length(mu_b_vals),
            length(sigma_ps_vals) * length(K_vals) * length(ex_violation_vals)))
cat(sprintf(" total: %d conditions x %d reps = %d analyses\n",
            length(psi_vals) * length(mu_b_vals) *
              length(sigma_ps_vals) * length(K_vals) * length(ex_violation_vals),
            n_rep,
            length(psi_vals) * length(mu_b_vals) *
              length(sigma_ps_vals) * length(K_vals) * length(ex_violation_vals) * n_rep))
# Measured, not extrapolated from v37. The v39b K = 50 top-up ran 320 fresh
# conditions in 6,720 s = 21.0 s/condition (1000 reps, MCMC 400 iter / 100 warmup).
# The old "n_conditions / 336 * 6 h" line treated 336 (a v33 *condition* count) as
# if it were a repetition count, and predicted 17.1 h for work that actually took
# well under 6 h. K = 50 is the slowest tier, so this rate is mildly conservative
# for a full grid that also contains K = 12 and K = 25 conditions.
SEC_PER_COND_EST <- 21
n_cond_total <- length(psi_vals) * length(mu_b_vals) *
  length(sigma_ps_vals) * length(K_vals) * length(ex_violation_vals)
cat(sprintf(" estimated wall-clock: ~%.1f hours (at %.0f s/condition, measured on the v39b K=50 top-up)\n",
            n_cond_total * SEC_PER_COND_EST / 3600, SEC_PER_COND_EST))
cat("=========================================================\n")

# ---- configs and combo_grid (mirror R/02b_incremental.R) ----
configs <- expand.grid(sigma_ps = sigma_ps_vals, K = K_vals,
                       ex_violation = ex_violation_vals, stringsAsFactors = FALSE)

# RESUME SAFETY (critical, do not remove):
# The record key of every condition is sprintf("cfg%d_psi%s_mu%s_sps%s", cfg_i, ...)
# -- it embeds the configs ROW INDEX, not the config content. Because
# expand.grid() varies the FIRST factor fastest and the last slowest, K is the
# middle factor here and inserting K = 50 pushes the K = 12 and K = 25 rows of
# the ex_violation = 0.3 block from indices 5-8 down to 9-12. Those 320
# already-finished conditions would then miss on resume and be recomputed from
# scratch. Reordering so that every row with K = 50 sits at the END keeps the
# eight original rows at indices 1-8 exactly as they were in the completed
# v37p1 run, so only the 4 x 80 = 320 genuinely new K = 50 conditions run
# (verified by dry run: 960 planned keys, 640 already present, 320 to run, and
# every pre-existing key still present in the new plan).
configs <- rbind(configs[configs$K != 50, ], configs[configs$K == 50, ])
rownames(configs) <- NULL

configs$config_id <- sprintf("sps%s_K%d_exV%s",
                             configs$sigma_ps, configs$K, configs$ex_violation)

combo_grid <- expand.grid(K = K_vals, ex_violation = ex_violation_vals,
                          psi = psi_vals, mu_b = mu_b_vals, stringsAsFactors = FALSE)
# Same resume-safety reordering, for the same reason. NOTE the direction:
# expand.grid varies the FIRST factor FASTEST and the last factor slowest, so K
# is the fastest-varying factor here and inserting K = 50 interleaves it between
# K = 12 and K = 25 in every (ex_violation, psi, mu_B) block. Left alone, every
# pre-existing combo would shift to a new combo_idx and therefore a new seed, so
# a future from-scratch rerun could not reproduce the 640 conditions already in
# the RDS. Pushing the K = 50 rows to the end leaves combo_idx (and hence the
# seed offset seed + combo_idx*100) bit-for-bit identical for all 320
# pre-existing combos, which then occupy rows 1-320; K = 50 takes rows 321-480.
combo_grid <- rbind(combo_grid[combo_grid$K != 50, ],
                    combo_grid[combo_grid$K == 50, ])
rownames(combo_grid) <- NULL
combo_grid$combo_id <- sprintf("K%d_exV%s_psi%s_mu%s",
                               combo_grid$K, combo_grid$ex_violation,
                               combo_grid$psi, combo_grid$mu_b)

# ---- resume: load existing results if any ----
results <- if (file.exists(out_rds)) {
  existing <- readRDS(out_rds)
  cat(sprintf("Resuming: loaded %d existing conditions from %s\n",
              length(existing), basename(out_rds)))
  existing
} else {
  list()
}

total_n <- length(psi_vals) * length(mu_b_vals) * nrow(configs)
done <- length(results)
cat(sprintf("Plan: %d total conditions, %d already done, %d remaining\n",
            total_n, done, total_n - done))

# `done` counts every condition in the RDS, including ones restored from a
# previous run; `n_this_run` counts only conditions executed since t0. The
# per-condition average and the ETA must divide by n_this_run: using `done`
# would dilute the elapsed time across conditions that never consumed any of
# it, which on a resumed run makes the ETA read far too low (bug seen when the
# K = 50 top-up started from 640 preloaded conditions).
t0 <- Sys.time()
n_this_run <- 0
for (cfg_i in seq_len(nrow(configs))) {
  cfg <- configs[cfg_i, ]
  for (psi in psi_vals) {
    for (mu_b in mu_b_vals) {
      combo_id <- sprintf("K%d_exV%s_psi%s_mu%s",
                          cfg$K, cfg$ex_violation, psi, mu_b)
      combo_idx <- which(combo_grid$combo_id == combo_id)
      key <- sprintf("cfg%d_psi%s_mu%s_sps%s", cfg_i, psi, mu_b, cfg$sigma_ps)
      if (key %in% names(results)) next   # resume skip

      t1 <- Sys.time()
      res <- run_method_compare(
        true_log_rr = psi, bias_mu = mu_b, bias_sigma = 0.05,
        n_nc = cfg$K, ex_violation = cfg$ex_violation,
        n_rep = n_rep, seed = seed + combo_idx * 100,
        se_psi_obs = cfg$sigma_ps,
        mcmc_iter = mcmc_iter, mcmc_warmup = mcmc_warmup)
      res$elapsed_sec <- as.numeric(difftime(Sys.time(), t1, units = "secs"))
      res$config_id <- cfg$config_id
      res$sigma_ps  <- cfg$sigma_ps
      res$se_psi_obs <- cfg$sigma_ps

      results[[key]] <- res
      done <- done + 1
      n_this_run <- n_this_run + 1

      # incremental save (atomic rename so a kill mid-write can't corrupt)
      saveRDS(results, paste0(out_rds, ".tmp"))
      file.rename(paste0(out_rds, ".tmp"), out_rds)
      sec_per_cond <- as.numeric(difftime(Sys.time(), t0, units = "secs")) / n_this_run
      writeLines(sprintf("%s  done=%d/%d  last=%s  cond=%.1fs  avg=%.1fs  eta=%.1fhr",
                         format(Sys.time(), "%H:%M:%S"), done, total_n, key,
                         res$elapsed_sec, sec_per_cond,
                         sec_per_cond * (total_n - done) / 3600),
                 prog_txt)
      if (n_this_run %% 10 == 0)
        cat(sprintf("[%s] %d/%d done (last %s, %.1fs/cond, ETA ~%.1f hr)\n",
                    format(Sys.time(), "%H:%M:%S"), done, total_n, key,
                    res$elapsed_sec, sec_per_cond,
                    sec_per_cond * (total_n - done) / 3600))
    }
  }
}

# ---- finalize aggregates + diagnostics (mirror R/02b_incremental.R tail) ----
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
    rmse_mcmc = sqrt(mean((cm$bf_mcmc - r$bf_true)^2)),
    elapsed_sec = if (!is.null(r$elapsed_sec)) r$elapsed_sec else NA_real_)
}))
saveRDS(agg, file.path(OUT_SIM, "comparison_agg_v37p1.rds"))
jsonlite::write_json(agg, file.path(OUT_SIM, "comparison_agg_v37p1.json"),
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
saveRDS(diag_mc,   file.path(OUT_SIM, "diag_mc_v37p1.rds"))
saveRDS(diag_mcmc, file.path(OUT_SIM, "diag_mcmc_v37p1.rds"))

cat(sprintf("\n=== ALL DONE: %d/%d conditions in %.1f min ===\n",
            done, total_n, as.numeric(difftime(Sys.time(), t0, units = "mins"))))
writeLines(sprintf("COMPLETE %d/%d at %s", done, total_n,
                   format(Sys.time(), "%H:%M:%S")), prog_txt)