# Credibility Metric Simulation Study — No-bootstrap worker (v34, BF scale)
# Usage: Rscript run_sim_worker_v34.R <ex_violation> <n_nc>
# v34: BF is the primary metric. Classification partition is identical to v33
#   (BF thresholds 0.5 and 1/3 map one-to-one onto BER thresholds 1 and 0.5),
#   so zone accuracies match v33; this worker additionally stores per-repetition
#   BF values so that BF-scale relative bias and RMSE are computed exactly.
# Seed scheme unchanged from v33 (base 42 + grid-coordinate terms), reproducing
# the same random draws (common random numbers across ex_violation levels).
args <- commandArgs(trailingOnly = TRUE)
ex_violation <- as.numeric(args[1])
n_nc <- as.integer(args[2])
worker_id <- sprintf("exV%.1f_nNC%d", ex_violation, n_nc)

source("R/00_config.R")
source("R/01_bsr_core.R")
SIM_DIR <- file.path(OUT_DIR, "simulation")
dir.create(SIM_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(LOG_DIR, showWarnings = FALSE, recursive = TRUE)

log_file <- file.path(LOG_DIR, sprintf("sim_v34_%s.log", worker_id))
log_con <- file(log_file, open = "w")
cat(sprintf("=== Worker %s started: %s ===\n", worker_id, Sys.time()), file = log_con)

library(EmpiricalCalibration)

sim_grid <- expand.grid(
  true_log_rr  = c(0, -0.05, -0.10, -0.15, -0.20, -0.30, -0.40),
  bias_mu      = c(-0.05, -0.10, -0.15, -0.20, -0.30, -0.40),
  bias_sigma   = c(0.05, 0.10),
  stringsAsFactors = FALSE
)
sim_grid$bsr_true <- ifelse(abs(sim_grid$true_log_rr) < 1e-10, Inf,
  abs(sim_grid$bias_mu) / abs(sim_grid$true_log_rr))
sim_grid$bf_true  <- ber_to_bf(sim_grid$bsr_true)   # Inf -> 1
sim_grid$n_nc <- n_nc
sim_grid$ex_violation <- ex_violation
cat(sprintf("Grid for %s: %d conditions\n", worker_id, nrow(sim_grid)), file = log_con)

# NOTE on the exchangeability-violation proportion: round(n_nc * ex_violation)
# gives 4/12 = 33.3% for K=12 and 8/25 = 32.0% for K=25 at the 0.3 level.
# Documented in the Supplement as such.

run_one_condition <- function(true_log_rr, bias_mu, bias_sigma, n_nc,
                               ex_violation, n_rep = 200, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  bsr_true <- if (abs(true_log_rr) < 1e-10) Inf else abs(bias_mu) / abs(true_log_rr)
  bf_true  <- ber_to_bf(bsr_true)
  true_class <- if (bsr_true > 1) "bias-dominated"
                else if (bsr_true < 0.5) "effect-dominated"
                else "competitive"

  bsr_est <- numeric(n_rep)
  bf_est  <- numeric(n_rep)
  ohdsi_p <- numeric(n_rep)
  uncal_p <- numeric(n_rep)

  for (r in seq_len(n_rep)) {
    n_ex <- round(n_nc * ex_violation)
    nc_bias <- c(rep(bias_mu, n_nc - n_ex), rep(bias_mu + 0.15, n_ex))
    nc_log_rr <- rnorm(n_nc, mean = nc_bias, sd = bias_sigma)
    nc_se     <- runif(n_nc, 0.03, 0.12)

    se_log_rr  <- 0.06
    obs_log_rr <- true_log_rr + bias_mu + rnorm(1, 0, se_log_rr)

    tryCatch({
      nf <- fitNull(nc_log_rr, nc_se)
      mu_b <- nf[1]
      lt <- obs_log_rr - mu_b
      if (abs(lt) < 1e-8) lt <- if (lt >= 0) 1e-8 else -1e-8
      bsr_est[r] <- abs(mu_b) / abs(lt)
      bf_est[r]  <- ber_to_bf(bsr_est[r])
      ohdsi_p[r] <- calibrateP(nf, obs_log_rr, se_log_rr)
      uncal_p[r] <- 2 * pnorm(-abs(obs_log_rr / se_log_rr))
    }, error = function(e) {})
  }

  ok <- bsr_est > 0 & is.finite(bsr_est)
  classify_pt <- function(b) {
    if (is.na(b)) return(NA_character_)
    if (b > 1) "bias-dominated" else if (b < 0.5) "effect-dominated" else "competitive"
  }
  class_ok <- sapply(bsr_est[ok], function(b) classify_pt(b) == true_class)

  bf_true_finite <- if (is.finite(bsr_true)) bf_true else NA_real_

  data.frame(
    true_log_rr = true_log_rr, bias_mu = bias_mu, bias_sigma = bias_sigma,
    n_nc = n_nc, ex_violation = ex_violation,
    bsr_true = if (is.infinite(bsr_true)) Inf else bsr_true,
    bf_true  = bf_true,
    bsr_mean = mean(bsr_est[ok], na.rm = TRUE),
    bsr_median = median(bsr_est[ok], na.rm = TRUE),
    bsr_sd   = sd(bsr_est[ok], na.rm = TRUE),
    bsr_rmse = sqrt(mean((bsr_est[ok] - bsr_true)^2, na.rm = TRUE)),
    bsr_rel_bias = (mean(bsr_est[ok], na.rm = TRUE) - bsr_true) / bsr_true,
    bf_mean  = mean(bf_est[ok], na.rm = TRUE),
    bf_median = median(bf_est[ok], na.rm = TRUE),
    bf_sd    = sd(bf_est[ok], na.rm = TRUE),
    bf_rmse  = sqrt(mean((bf_est[ok] - bf_true_finite)^2, na.rm = TRUE)),
    bf_rel_bias = (mean(bf_est[ok], na.rm = TRUE) - bf_true_finite) / bf_true_finite,
    bsr_class_accuracy   = mean(class_ok, na.rm = TRUE),
    ohdsi_rejection_rate = mean(ohdsi_p[ok] < 0.05, na.rm = TRUE),
    uncal_rejection_rate  = mean(uncal_p[ok] < 0.05, na.rm = TRUE),
    n_success = sum(ok),
    stringsAsFactors = FALSE
  )
}

results_list <- vector("list", nrow(sim_grid))
base_seed <- 42L
for (i in seq_len(nrow(sim_grid))) {
  g <- sim_grid[i, ]
  cond_seed <- base_seed + i * 7L +
    as.integer(abs(g$true_log_rr) * 1000) +
    as.integer(abs(g$bias_mu) * 100) +
    as.integer(g$bias_sigma * 10)
  results_list[[i]] <- run_one_condition(
    true_log_rr = g$true_log_rr, bias_mu = g$bias_mu,
    bias_sigma = g$bias_sigma, n_nc = g$n_nc,
    ex_violation = g$ex_violation, n_rep = 200,
    seed = cond_seed
  )
  if (i %% 20 == 0) cat(sprintf("  %d/%d conditions done\n", i, nrow(sim_grid)), file = log_con)
}
sim_df <- do.call(rbind, results_list)

cat("\n===== Summary (v34, BF scale) =====\n", file = log_con)
finite_idx <- is.finite(sim_df$bsr_true)
cat(sprintf("BF RMSE (mean): %.4f\n", mean(sim_df$bf_rmse[finite_idx], na.rm = TRUE)), file = log_con)
cat(sprintf("BF RMSE (median): %.4f\n", median(sim_df$bf_rmse[finite_idx], na.rm = TRUE)), file = log_con)
cat(sprintf("BF relative bias (mean): %.1f%%\n",
  100 * mean(sim_df$bf_rel_bias[finite_idx], na.rm = TRUE)), file = log_con)
cat(sprintf("Classification accuracy: %.1f%%\n",
  100 * mean(sim_df$bsr_class_accuracy, na.rm = TRUE)), file = log_con)
cat(sprintf("OHDSI rejection at null: %.1f%%\n",
  100 * mean(sim_df$ohdsi_rejection_rate[sim_df$true_log_rr == 0], na.rm = TRUE)), file = log_con)

out_file <- file.path(SIM_DIR, sprintf("sim_results_v34_%s.rds", worker_id))
saveRDS(sim_df, out_file)
cat(sprintf("\nSaved: %s\n", out_file), file = log_con)
cat(sprintf("=== Worker %s DONE: %s ===\n", worker_id, Sys.time()), file = log_con)
close(log_con)
