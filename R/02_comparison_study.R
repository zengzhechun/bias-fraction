# R/02_comparison_study.R
# Comparison Study: MCMC vs Monte Carlo + Per-Region Diagnostics + Configurable Design Matrix
# v35 - 2026-08-20
# v36 - 2026-08-21: PRIMARY analysis of the simulation is the Bland-Altman agreement study of the
#   continuous BF estimator (R/06_bland_altman.R, R/10_ba_full_viz.R). The three-zone classification
#   computed here is a SECONDARY analysis that supplies the clinical decision interface.
#
# This module implements three analytical extensions to the v35 simulation study:
#   Module A — run_method_compare(): MCMC (Gibbs) vs Monte Carlo (EmpiricalCalibration::fitNull)
#   Module B — compute_region_diagnostics(): per-zone sens/spec/PPV/NPV + 3x3 error-flow matrix
#   Module C — build_design_matrix(): configurable (psi, mu_B, sigma_B, sigma_ps, K, ex_violation) grid

suppressPackageStartupMessages({
  library(EmpiricalCalibration)
})

# source sibling modules (00_config.R, 01_bsr_core.R)
THIS_DIR <- tryCatch(dirname(sys.frame(1)$ofile),
                     error = function(e) {
                       args <- commandArgs(trailingOnly = FALSE)
                       m <- regmatches(args, regexpr("(?<=^--file=).+", args, perl = TRUE))
                       if (length(m)) dirname(m) else "."
                     })
source(file.path(THIS_DIR, "00_config.R"))
source(file.path(THIS_DIR, "01_bsr_core.R"))

# ============================================================
# Module A: MCMC Gibbs Sampler for the Empirical Null
# ============================================================
# Model: nc_i ~ N(mu_B, sigma_B^2 + se_i^2)
# Priors: mu_B ~ N(0, 1),  sigma_B^2 ~ InverseGamma(0.5, 0.05)
# Posterior conditionally conjugate; closed-form Gibbs updates.
mcmc_fit_null <- function(nc_log_rr, nc_se_log_rr,
                          n_iter = 1500, n_warmup = 500,
                          seed = 42,
                          mu_prior_mean = 0, mu_prior_var = 1,
                          sigma2_prior_shape = 0.5, sigma2_prior_scale = 0.05) {
  set.seed(seed)
  y <- as.numeric(nc_log_rr); s <- as.numeric(nc_se_log_rr); n <- length(y)
  mu <- mean(y); sigma2 <- max(var(y) - mean(s^2), 1e-6)
  mu_draws <- numeric(n_iter); sigma2_draws <- numeric(n_iter)
  for (i in seq_len(n_iter)) {
    # mu | sigma2, data  (normal posterior)
    v_total <- sigma2 + s^2
    prec_post <- 1 / mu_prior_var + sum(1 / v_total)
    mean_post <- (mu_prior_mean / mu_prior_var + sum(y / v_total)) / prec_post
    mu <- rnorm(1, mean_post, sqrt(1 / prec_post))
    # sigma2 | mu, data  (inverse-gamma posterior)
    shape_post <- sigma2_prior_shape + n / 2
    scale_post <- sigma2_prior_scale + 0.5 * sum((y - mu)^2 + s^2)
    sigma2 <- 1 / rgamma(1, shape = shape_post, rate = scale_post)
    mu_draws[i] <- mu; sigma2_draws[i] <- sigma2
  }
  keep <- (n_warmup + 1):n_iter
  list(
    mu_draws = mu_draws[keep], sigma2_draws = sigma2_draws[keep],
    mu_mean  = mean(mu_draws[keep]),
    sigma_mean = sqrt(mean(sigma2_draws[keep])),
    mu_ci = quantile(mu_draws[keep], c(0.025, 0.975)),
    sigma_ci = sqrt(quantile(sigma2_draws[keep], c(0.025, 0.975))),
    bf_posterior = NULL  # filled by run_method_compare()
  )
}

# Run one condition under both MC and MCMC, comparing BF estimates and classifications.
run_method_compare <- function(true_log_rr, bias_mu, bias_sigma,
                               n_nc, ex_violation,
                               n_rep = 200, seed = 42,
                               se_psi_obs = 0.06,
                               mcmc_iter = 800, mcmc_warmup = 200) {
  # se_psi_obs = observation SE of the target-effect estimate (psi_hat).
  # This is the sigma_ps factor: it drives the precision of obs_log_rr and
  # of the bootstrap CI, independent of the NC data-generating mechanism.
  set.seed(seed)
  n_ex <- round(n_nc * ex_violation)
  nc_bias <- c(rep(bias_mu, n_nc - n_ex), rep(bias_mu + 0.15, n_ex))
  bsr_true <- if (abs(true_log_rr) < 1e-10) Inf else abs(bias_mu) / abs(true_log_rr)
  bf_true  <- if (is.finite(bsr_true)) bsr_to_bf(bsr_true) else 1
  true_zone <- if (bsr_true > 1) "bias-dominated"
               else if (bf_true < 1/3) "effect-dominated"
               else "mixed"

  out <- data.frame(rep = seq_len(n_rep),
                    bf_mc = NA_real_, bf_mcmc = NA_real_,
                    zone_mc = NA_character_, zone_mcmc = NA_character_,
                    ci_lo_mc = NA_real_, ci_hi_mc = NA_real_,
                    ci_lo_mcmc = NA_real_, ci_hi_mcmc = NA_real_,
                    cal_p = NA_real_, naive_p = NA_real_)
  for (r in seq_len(n_rep)) {
    nc_log_rr <- rnorm(n_nc, mean = nc_bias, sd = bias_sigma)
    nc_se     <- runif(n_nc, 0.03, 0.12)
    obs_log_rr <- true_log_rr + bias_mu + rnorm(1, 0, se_psi_obs)

    # --- MC: point estimate via fitNull, CI via bootstrap ---
    nf <- EmpiricalCalibration::fitNull(nc_log_rr, nc_se)
    mu_b <- nf[1]
    lt   <- obs_log_rr - mu_b
    bsr_mc <- abs(mu_b) / max(abs(lt), 1e-8)
    bf_mc  <- bsr_to_bf(bsr_mc)
    boot   <- bsr_bootstrap(obs_log_rr, se_psi_obs, nc_log_rr, nc_se,
                            n_boot = 50, seed = seed + 1000 + r)
    out$bf_mc[r] <- bf_mc
    out$ci_lo_mc[r] <- boot$bf_ci_lo
    out$ci_hi_mc[r] <- boot$bf_ci_hi
    out$zone_mc[r] <- zone_from_bf(bf_mc, boot$bf_ci_lo, boot$bf_ci_hi)

    # --- MCMC: posterior median of BF over posterior of mu_B ---
    post <- mcmc_fit_null(nc_log_rr, nc_se, n_iter = mcmc_iter,
                          n_warmup = mcmc_warmup, seed = seed + r)
    mu_draws <- post$mu_draws
    lt_draws <- obs_log_rr - mu_draws
    bsr_draws <- abs(mu_draws) / pmax(abs(lt_draws), 1e-8)
    bf_draws  <- bsr_draws / (1 + bsr_draws)
    mcmc_lo <- quantile(bf_draws, 0.025)
    mcmc_hi <- quantile(bf_draws, 0.975)
    out$bf_mcmc[r] <- median(bf_draws)
    out$ci_lo_mcmc[r] <- mcmc_lo
    out$ci_hi_mcmc[r] <- mcmc_hi
    out$zone_mcmc[r] <- zone_from_bf(median(bf_draws), mcmc_lo, mcmc_hi)

    # --- OHDSI calibrated p-value (closed form) and naive (uncalibrated) p-value ---
    # Calibrated estimate = obs_log_rr - mu_b with SE = sqrt(se_psi_obs^2 + sigma_b^2);
    # its two-sided p-value is the OHDSI empirical-calibration p-value. nf[2] is sigma_b.
    se_cal  <- sqrt(se_psi_obs^2 + nf[2]^2)
    cal_est <- obs_log_rr - nf[1]
    out$cal_p[r]   <- 2 * (1 - pnorm(abs(cal_est) / se_cal))
    out$naive_p[r] <- 2 * (1 - pnorm(abs(obs_log_rr) / se_psi_obs))
  }
  list(config = list(true_log_rr = true_log_rr, bias_mu = bias_mu,
                     bias_sigma = bias_sigma, n_nc = n_nc,
                     ex_violation = ex_violation, se_psi_obs = se_psi_obs),
       bf_true = bf_true, true_zone = true_zone, results = out)
}

bsr_to_bf <- function(bsr) bsr / (1 + bsr)

zone_from_bf <- function(bf, lo = NA_real_, hi = NA_real_) {
  if (is.na(bf)) return("unclassifiable")
  if (!is.na(lo) && !is.na(hi)) {
    if (hi <= 0.5) return("effect-dominated")
    if (lo >= 0.5) return("bias-dominated")
    return("mixed")
  }
  if (bf > 0.5) return("bias-dominated")
  if (bf < 1/3) return("effect-dominated")
  return("mixed")
}

# ============================================================
# Module B: Per-Region Diagnostics
# ============================================================
compute_region_diagnostics <- function(true_zone, est_zone) {
  zones <- c("effect-dominated", "mixed", "bias-dominated")
  cm <- table(factor(true_zone, levels = zones),
              factor(est_zone,  levels = zones))
  out <- list(confusion = cm, per_zone = list())
  N <- sum(cm)
  for (z in zones) {
    TP <- cm[z, z]
    FN <- sum(cm[z, ]) - TP
    FP <- sum(cm[, z]) - TP
    TN <- N - TP - FN - FP
    sens <- if ((TP + FN) > 0) TP / (TP + FN) else NA_real_
    spec <- if ((TN + FP) > 0) TN / (TN + FP) else NA_real_
    ppv  <- if ((TP + FP) > 0) TP / (TP + FP) else NA_real_
    npv  <- if ((TN + FN) > 0) TN / (TN + FN) else NA_real_
    out$per_zone[[z]] <- list(
      sens = sens, spec = spec, ppv = ppv, npv = npv,
      n_true = TP + FN, n_pred = TP + FP,
      confusion = cm[z, ])
  }
  # Error flow: among misclassified in zone z, distribution of where they go
  ef <- matrix(0, nrow = length(zones), ncol = length(zones),
               dimnames = list(zones, zones))
  for (i in seq_along(zones)) {
    z <- zones[i]
    err_total <- sum(cm[z, ]) - cm[z, z]
    if (err_total > 0) {
      for (j in seq_along(zones)) {
        if (zones[j] != z) ef[i, j] <- cm[z, zones[j]] / err_total
      }
    }
  }
  out$error_flow <- ef
  invisible(out)
}

# ============================================================
# Module C: Configurable Design Matrix
# ============================================================
build_design_matrix <- function(true_log_rr   = c(-0.01, -0.05, -0.10, -0.15, -0.20, -0.30, -0.40),
                                bias_mu       = c(-0.05, -0.10, -0.15, -0.20, -0.30, -0.40),
                                bias_sigma    = c(0.05, 0.10),
                                sigma_ps_vals = c(0.06, 0.10),
                                K_vals        = c(12, 25),
                                ex_violation_vals = c(0.0, 0.3)) {
  g <- expand.grid(
    true_log_rr = true_log_rr,
    bias_mu     = bias_mu,
    bias_sigma  = bias_sigma,
    sigma_ps    = sigma_ps_vals,
    K           = K_vals,
    ex_violation = ex_violation_vals,
    stringsAsFactors = FALSE
  )
  g$cond_id <- sprintf("psi%s_mu%s_sig%s_sps%s_K%d_exV%s",
                       g$true_log_rr, g$bias_mu, g$bias_sigma,
                       g$sigma_ps, g$K, g$ex_violation)
  g
}

# ============================================================
# Demonstrate: 8 configs x representative (psi, mu_B) pairs
# ============================================================
demo_8_config <- function(n_rep = 100, seed = 42, output_dir = NULL,
                          sigma_ps_vals = c(0.06, 0.10),
                          K_vals = c(12, 25),
                          ex_violation_vals = c(0.0, 0.3),
                          psi_vals = c(-0.01, -0.05, -0.10, -0.15, -0.20, -0.30, -0.40),
                          mu_b_vals = c(-0.05, -0.10, -0.15, -0.20, -0.30, -0.40),
                          mcmc_iter = 400, mcmc_warmup = 100) {
  configs <- expand.grid(sigma_ps = sigma_ps_vals, K = K_vals,
                         ex_violation = ex_violation_vals,
                         stringsAsFactors = FALSE)
  configs$config_id <- sprintf("sps%s_K%d_exV%s",
                               configs$sigma_ps, configs$K, configs$ex_violation)
  configs$n_rep <- n_rep

  results <- list()
  t0 <- Sys.time()
  # Unique (K, ex_violation, psi, mu_B) combos — the 4-tuple held FIXED across
  # the two sigma_ps levels, so that sigma_ps varies ONLY the observation SE of
  # the target-effect estimate (a clean factor, no longer a seed phantom that
  # merely re-drew different NC data).
  combo_grid <- expand.grid(K = K_vals, ex_violation = ex_violation_vals,
                            psi = psi_vals, mu_b = mu_b_vals,
                            stringsAsFactors = FALSE)
  combo_grid$combo_id <- sprintf("K%d_exV%s_psi%s_mu%s",
                                 combo_grid$K, combo_grid$ex_violation,
                                 combo_grid$psi, combo_grid$mu_b)
  for (cfg_i in seq_len(nrow(configs))) {
    cfg <- configs[cfg_i, ]
    for (psi in psi_vals) {
      for (mu_b in mu_b_vals) {
        combo_id <- sprintf("K%d_exV%s_psi%s_mu%s",
                            cfg$K, cfg$ex_violation, psi, mu_b)
        combo_idx <- which(combo_grid$combo_id == combo_id)
        key <- sprintf("cfg%d_psi%s_mu%s_sps%s", cfg_i, psi, mu_b, cfg$sigma_ps)
        cat(sprintf("[%s] running %s ...\n",
                    format(Sys.time(), "%H:%M:%S"), key))
        t1 <- Sys.time()
        res <- run_method_compare(
          true_log_rr = psi, bias_mu = mu_b, bias_sigma = 0.05,
          n_nc = cfg$K, ex_violation = cfg$ex_violation,
          n_rep = n_rep, seed = seed + combo_idx * 100,
          se_psi_obs = cfg$sigma_ps,
          mcmc_iter = mcmc_iter, mcmc_warmup = mcmc_warmup)
        res$elapsed_sec <- as.numeric(difftime(Sys.time(), t1, units = "secs"))
        res$config_id <- cfg$config_id
        res$sigma_ps <- cfg$sigma_ps
        res$se_psi_obs <- cfg$sigma_ps
        results[[key]] <- res
      }
    }
  }
  total_sec <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

  # Aggregate
  agg <- do.call(rbind, lapply(names(results), function(k) {
    r <- results[[k]]
    cm <- r$results
    data.frame(
      config_id = r$config_id, sigma_ps = r$sigma_ps,
      K = r$config$n_nc,
      ex_violation = r$config$ex_violation,
      psi = r$config$true_log_rr, mu_b = r$config$bias_mu,
      bf_true = r$bf_true, true_zone = r$true_zone,
      acc_mc    = mean(cm$zone_mc    == r$true_zone),
      acc_mcmc  = mean(cm$zone_mcmc  == r$true_zone),
      agree     = mean(cm$zone_mc    == cm$zone_mcmc),
      bias_mc   = mean(cm$bf_mc     - r$bf_true),
      bias_mcmc = mean(cm$bf_mcmc   - r$bf_true),
      rmse_mc   = sqrt(mean((cm$bf_mc   - r$bf_true)^2)),
      rmse_mcmc = sqrt(mean((cm$bf_mcmc - r$bf_true)^2)),
      elapsed_sec = r$elapsed_sec
    )
  }))

  # Save
  if (!is.null(output_dir)) {
    dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
    saveRDS(results, file.path(output_dir, "comparison_results.rds"))
    saveRDS(agg,     file.path(output_dir, "comparison_agg.rds"))
    # JSON for HTML embedding
    jsonlite::write_json(
      agg, file.path(output_dir, "comparison_agg.json"),
      dataframe = "columns", auto_unbox = TRUE, digits = 6,
      pretty = TRUE)
    # Per-region diagnostics — TRUE zone carried per condition (fixes the prior
    # bug where every row was treated as a single replicated true_zone, which
    # zeroed the effect/bias-dominated n_true counts).
    all_mc   <- do.call(rbind, lapply(names(results), function(k) {
      r <- results[[k]]
      cbind(r$results[, c("rep", "bf_mc", "zone_mc")],
            true_zone = r$true_zone, config_id = r$config_id,
            sigma_ps = r$sigma_ps)
    }))
    all_mcmc <- do.call(rbind, lapply(names(results), function(k) {
      r <- results[[k]]
      cbind(r$results[, c("rep", "bf_mcmc", "zone_mcmc")],
            true_zone = r$true_zone, config_id = r$config_id,
            sigma_ps = r$sigma_ps)
    }))
    diag_mc   <- compute_region_diagnostics(all_mc$true_zone,   all_mc$zone_mc)
    diag_mcmc <- compute_region_diagnostics(all_mcmc$true_zone, all_mcmc$zone_mcmc)
    saveRDS(diag_mc,   file.path(output_dir, "diag_mc.rds"))
    saveRDS(diag_mcmc, file.path(output_dir, "diag_mcmc.rds"))
  }

  list(results = results, agg = agg, total_sec = total_sec,
       configs = configs)
}

if (!interactive() && sys.nframe() == 0) {
  # Full design: 8 configurations (sigma_ps x K x ex_violation) x 42 (psi, mu_B)
  # pairs x 1000 repetitions = 336 conditions x 1000 reps = 336,000 classifications.
  # sigma_ps (0.06 vs 0.10) now varies ONLY the observation SE of the target
  # effect (clean factor); the two levels of a (K, exV, psi, mu_B) combo share
  # the same NC/obs RNG seed.
  out <- demo_8_config(n_rep = 1000, seed = 42,
                       output_dir = file.path(OUT_DIR, "simulation"),
                       mcmc_iter = 400, mcmc_warmup = 100)
  cat(sprintf("\n=== done in %.1f sec ===\n", out$total_sec))
  print(head(out$agg, 5))
}