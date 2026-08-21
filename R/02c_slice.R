# R/02c_slice.R
# Parallel slice driver for the full 336-condition x 1000-rep simulation (v37 redesign).
# Usage: Rscript R/02c_slice.R <slice>   where slice in 1..8 (one config per slice).
#
# Each slice runs ONLY its own (sigma_ps, K, ex_violation) config (42 conditions =
# 7 psi-levels x 6 mu_B-levels) and writes its own RDS
# (comparison_results_cfg{slice}.rds) with incremental atomic save + resume, so it is
# robust to the sandbox's ~17-min background-task timeout. After all 8 slices finish,
# run R/02d_merge.R to combine them into comparison_results.rds and finalize aggregates.
#
# Seeds are IDENTICAL to the sequential R/02b_incremental.R run: seed = 42 + combo_idx*100,
# where combo_idx is the row index in the full combo_grid (1..336). Because combo_idx depends
# only on (psi, mu_b, K, ex_violation) and not on which slice runs it, splitting by config
# reproduces the exact same random draws as a single sequential pass.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) >= 1)
slice <- as.integer(args[1])
stopifnot(slice >= 1 && slice <= 8)

source("R/00_config.R")
source("R/02_comparison_study.R")  # defines run_method_compare, compute_region_diagnostics;
                                   # its own driver block is skipped (sys.nframe() > 0)

OUT_SIM  <- SIM_DIR
out_rds  <- file.path(OUT_SIM, sprintf("comparison_results_cfg%d.rds", slice))
prog_txt <- file.path(OUT_SIM, sprintf("run_progress_cfg%d.txt", slice))

# ---- grids (full v37 design: psi starts at -0.01, not 0) ----
psi_vals  <- c(-0.01, -0.05, -0.10, -0.15, -0.20, -0.30, -0.40)   # 7 levels; v37 removes BF=1 singularity
mu_b_vals <- c(-0.05, -0.10, -0.15, -0.20, -0.30, -0.40)         # 6 levels
sigma_ps_vals     <- c(0.06, 0.10)
K_vals            <- c(12, 25)
ex_violation_vals <- c(0.0, 0.3)
mcmc_iter <- 400; mcmc_warmup <- 100
n_rep <- 1000; seed <- 42

configs <- expand.grid(sigma_ps = sigma_ps_vals, K = K_vals,
                       ex_violation = ex_violation_vals, stringsAsFactors = FALSE)
configs$config_id <- sprintf("sps%s_K%d_exV%s", configs$sigma_ps, configs$K, configs$ex_violation)

combo_grid <- expand.grid(K = K_vals, ex_violation = ex_violation_vals,
                          psi = psi_vals, mu_b = mu_b_vals, stringsAsFactors = FALSE)
combo_grid$combo_id <- sprintf("K%d_exV%s_psi%s_mu%s",
                               combo_grid$K, combo_grid$ex_violation,
                               combo_grid$psi, combo_grid$mu_b)

# ---- resume: load existing results for this slice ----
results <- if (file.exists(out_rds)) readRDS(out_rds) else list()
total <- length(psi_vals) * length(mu_b_vals)   # 42 per slice
done  <- length(results)
cat(sprintf("SLICE %d: plan %d conditions, %d already done, %d remaining\n",
            slice, total, done, total - done))

t0 <- Sys.time()
cfg <- configs[slice, ]   # only this config
for (psi in psi_vals) {
  for (mu_b in mu_b_vals) {
    combo_id  <- sprintf("K%d_exV%s_psi%s_mu%s", cfg$K, cfg$ex_violation, psi, mu_b)
    combo_idx <- which(combo_grid$combo_id == combo_id)
    key <- sprintf("cfg%d_psi%s_mu%s_sps%s", slice, psi, mu_b, cfg$sigma_ps)
    if (key %in% names(results)) next   # resume skip
    res <- run_method_compare(
      true_log_rr = psi, bias_mu = mu_b, bias_sigma = 0.05,
      n_nc = cfg$K, ex_violation = cfg$ex_violation,
      n_rep = n_rep, seed = seed + combo_idx * 100,
      se_psi_obs = cfg$sigma_ps,
      mcmc_iter = mcmc_iter, mcmc_warmup = mcmc_warmup)
    res$config_id <- cfg$config_id
    res$sigma_ps  <- cfg$sigma_ps
    res$se_psi_obs <- cfg$sigma_ps
    results[[key]] <- res
    done <- done + 1
    # incremental save (atomic: write tmp then rename, so a mid-write kill cannot
    # corrupt the slice RDS and break resume)
    saveRDS(results, paste0(out_rds, ".tmp"))
    file.rename(paste0(out_rds, ".tmp"), out_rds)
    writeLines(sprintf("%s done=%d/%d last=%s",
                       format(Sys.time(), "%H:%M:%S"), done, total, key),
               prog_txt)
  }
}

cat(sprintf("\n=== SLICE %d DONE: %d/%d conditions in %.1f min ===\n",
            slice, done, total, as.numeric(difftime(Sys.time(), t0, units = "mins"))))
writeLines(sprintf("COMPLETE %d/%d at %s", done, total,
                   format(Sys.time(), "%H:%M:%S")), prog_txt)
