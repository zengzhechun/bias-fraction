# R/02b_incremental.R
# Incremental + resumable driver for the full 336-condition x 1000-rep simulation.
# Robust against the sandbox's background-task timeout: saves after every condition,
# and on relaunch skips conditions already present in comparison_results.rds.
source("R/00_config.R")
source("R/02_comparison_study.R")  # defines run_method_compare, bsr_to_bf, etc.
                                    # (its own driver block is skipped because sys.nframe() > 0)

OUT_SIM <- SIM_DIR
out_rds  <- file.path(OUT_SIM, "comparison_results.rds")
prog_txt <- file.path(OUT_SIM, "run_progress.txt")

# ---- grids (full design) ----
psi_vals  <- c(-0.01, -0.05, -0.10, -0.15, -0.20, -0.30, -0.40)   # 7 levels; v37 redesign replaces ψ=0 with ψ=−0.01 (RR=0.99) to remove the BF=1 singularity (ratio metric degeneracy at true null)
mu_b_vals <- c(-0.05, -0.10, -0.15, -0.20, -0.30, -0.40)      # 6 levels
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

# ---- resume: load existing results ----
results <- if (file.exists(out_rds)) {
  cat(sprintf("Resuming: loaded %d existing conditions from %s\n",
              length(readRDS(out_rds)), basename(out_rds)))
  readRDS(out_rds)
} else {
  list()
}

total <- length(psi_vals) * length(mu_b_vals) * nrow(configs)   # 7 x 6 x 8 = 336
done  <- length(results)
cat(sprintf("Plan: %d total conditions, %d already done, %d remaining\n",
            total, done, total - done))

t0 <- Sys.time()
for (cfg_i in seq_len(nrow(configs))) {
  cfg <- configs[cfg_i, ]
  for (psi in psi_vals) {
    for (mu_b in mu_b_vals) {
      combo_id <- sprintf("K%d_exV%s_psi%s_mu%s",
                          cfg$K, cfg$ex_violation, psi, mu_b)
      combo_idx <- which(combo_grid$combo_id == combo_id)
      key <- sprintf("cfg%d_psi%s_mu%s_sps%s", cfg_i, psi, mu_b, cfg$sigma_ps)
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
      # incremental save (atomic: write tmp then rename, so a mid-write kill
      # cannot corrupt the main RDS and break resume)
      saveRDS(results, paste0(out_rds, ".tmp"))
      file.rename(paste0(out_rds, ".tmp"), out_rds)
      writeLines(sprintf("%s  done=%d/%d  last=%s",
                         format(Sys.time(), "%H:%M:%S"), done, total, key),
                 prog_txt)
      if (done %% 10 == 0)
        cat(sprintf("[%s] %d/%d done (last %s)\n",
                    format(Sys.time(), "%H:%M:%S"), done, total, key))
    }
  }
}

# ---- finalize aggregates + diagnostics (same as demo_8_config tail) ----
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

cat(sprintf("\n=== ALL DONE: %d/%d conditions in %.1f min ===\n",
            done, total, as.numeric(difftime(Sys.time(), t0, units = "mins"))))
writeLines(sprintf("COMPLETE %d/%d at %s", done, total,
                   format(Sys.time(), "%H:%M:%S")), prog_txt)
