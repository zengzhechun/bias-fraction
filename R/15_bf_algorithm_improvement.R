# R/15_bf_algorithm_improvement.R
# Demonstrate ALGORITHMIC improvements to the BF estimator (NOT post-processing).
# The original v37 estimator uses bf_mcmc = median( posterior BF draws ).
# We compare against two in-algorithm alternatives that change how BF is computed
# from the SAME posterior draws:
#   - bf_mean   : posterior MEAN of the ratio  |mu|/(|mu|+|psi|)  (the standard Bayesian BF)
#   - bf_logodds: plogis( mean( logit(posterior BF draws) ) )  (mean in unbounded log-odds space)
# Plus a delta-method bias-corrected plug-in (bf_bc) for reference.
# Run on a representative subset (all 336 conditions x n_rep reps) to access draws cheaply.

suppressPackageStartupMessages({
  library(dplyr); library(ggplot2); library(patchwork)
  library(EmpiricalCalibration)
})
source("R/00_config.R")
source("R/01_bsr_core.R")
source("R/02_comparison_study.R")   # exports mcmc_fit_null, bsr_to_bf, build_design_matrix

OUT_DIR <- file.path(FIG_DIR, "continuous_bf")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# ---- per-rep estimator computation (mirrors R/02 but exposes every summary) ----
run_one_rep_est <- function(true_log_rr, bias_mu, bias_sigma, n_nc, ex_violation,
                            se_psi_obs, r, seed, mcmc_iter = 400, mcmc_warmup = 100) {
  set.seed(seed + r)
  n_ex <- round(n_nc * ex_violation)
  nc_bias <- c(rep(bias_mu, n_nc - n_ex), rep(bias_mu + 0.15, n_ex))
  nc_log_rr <- rnorm(n_nc, mean = nc_bias, sd = bias_sigma)
  nc_se     <- runif(n_nc, 0.03, 0.12)
  obs_log_rr <- true_log_rr + bias_mu + rnorm(1, 0, se_psi_obs)
  # MC plug-in
  nf <- EmpiricalCalibration::fitNull(nc_log_rr, nc_se)
  mu_b <- nf[1]; lt <- obs_log_rr - mu_b
  bf_mc <- bsr_to_bf(abs(mu_b) / max(abs(lt), 1e-8))
  se_mu <- nf[2]
  # MCMC posterior draws of BF
  post <- mcmc_fit_null(nc_log_rr, nc_se, n_iter = mcmc_iter, n_warmup = mcmc_warmup, seed = seed + r)
  mu_draws <- post$mu_draws
  lt_draws <- obs_log_rr - mu_draws
  bsr_draws <- abs(mu_draws) / pmax(abs(lt_draws), 1e-8)
  bf_draws <- bsr_draws / (1 + bsr_draws)
  bf_med <- median(bf_draws)                                  # current v37
  bf_mean <- mean(bf_draws)                                   # algorithm fix 1: posterior mean of ratio
  bf_draws_c <- pmin(pmax(bf_draws, 1e-6), 1 - 1e-6)
  bf_logodds <- plogis(mean(qlogis(bf_draws_c)))              # algorithm fix 2: mean in log-odds space
  # --- flat-prior variant: the bias source is mu_B shrinkage (prior N(0,1) pulls
  #     mu_B toward 0, inflating psi_hat = obs - mu_B and deflating BF).
  #     Use a near-flat prior on mu_B to remove the shrinkage. ---
  post_flat <- mcmc_fit_null(nc_log_rr, nc_se, n_iter = mcmc_iter, n_warmup = mcmc_warmup,
                             seed = seed + r + 1, mu_prior_var = 100)
  mu_flat <- post_flat$mu_draws
  lt_flat <- obs_log_rr - mu_flat
  bsr_flat <- abs(mu_flat) / pmax(abs(lt_flat), 1e-8)
  bf_flat_draws <- bsr_flat / (1 + bsr_flat)
  bf_med_flat <- median(bf_flat_draws)
  bf_mean_flat <- mean(bf_flat_draws)
  # --- folded-normal correction on |mu_B| and |psi|: E[|X|] > |mu| for X~N(mu,sigma^2),
  #     excess ~ sigma*sqrt(2/pi)*exp(-mu^2/(2 sigma^2)). This shrinks the
  #     denominator |psi_hat| (and numerator) toward truth, the actual bias source. ---
  sg <- sqrt(2/pi)
  mu_corr  <- pmax(0, abs(mu_b)    - se_mu      * sg * exp(-mu_b^2/(2*se_mu^2)))
  psi_corr <- pmax(0, abs(lt)      - se_psi_obs * sg * exp(-lt^2/(2*se_psi_obs^2)))
  bf_fold <- mu_corr / (mu_corr + psi_corr)
  data.frame(rep = r, bf_mc = bf_mc, bf_med = bf_med, bf_mean = bf_mean,
             bf_logodds = bf_logodds, bf_med_flat = bf_med_flat, bf_mean_flat = bf_mean_flat,
             bf_fold = bf_fold,
             mu_b = mu_b, se_mu = se_mu, psi_hat = lt)
}

# ---- sweep the full 336-condition design grid (subset reps for speed) ----
design <- build_design_matrix(bias_sigma = c(0.05))  # match v37 sim: sigma_B fixed at 0.05 -> 336 conditions
n_rep <- 20
cat(sprintf("Running %d conditions x %d reps = %d analyses...\n",
            nrow(design), n_rep, nrow(design) * n_rep))

rows <- list()
for (idx in seq_len(nrow(design))) {
  cfg <- design[idx, ]
  dd <- do.call(rbind, lapply(seq_len(n_rep), function(r)
    run_one_rep_est(cfg$true_log_rr, cfg$bias_mu, 0.05, cfg$K, cfg$ex_violation,
                    cfg$sigma_ps, r, seed = 42 + idx * 7)))
  # condition-level means
  a_hat <- abs(mean(dd$mu_b)); b_hat <- abs(mean(dd$psi_hat))
  sig_mu <- sd(dd$mu_b);       sig_psi <- mean(dd$se_mu)
  # delta-method bias of the plug-in ratio (no covariance term)
  bias_delta <- (a_hat * sig_psi^2 - b_hat * sig_mu^2) / (a_hat + b_hat)^3
  bf_bc <- pmin(pmax(mean(dd$bf_mc) - bias_delta, 0), 1)
  bsr_true <- if (abs(cfg$true_log_rr) < 1e-10) Inf else abs(cfg$bias_mu) / abs(cfg$true_log_rr)
  bf_true <- if (is.finite(bsr_true)) bsr_to_bf(bsr_true) else 1
  rows[[idx]] <- data.frame(
    config_id = cfg$cond_id, psi = cfg$true_log_rr, mu_b = cfg$bias_mu,
    sigma_ps = cfg$sigma_ps, K = cfg$K, ex_violation = cfg$ex_violation,
    bf_true = bf_true,
    bf_mc = mean(dd$bf_mc), bf_med = mean(dd$bf_med),
    bf_mean = mean(dd$bf_mean), bf_logodds = mean(dd$bf_logodds),
    bf_med_flat = mean(dd$bf_med_flat), bf_mean_flat = mean(dd$bf_mean_flat),
    bf_fold = mean(dd$bf_fold), bf_bc = bf_bc)
}
tab <- do.call(rbind, rows)
cat(sprintf("Done. %d conditions.\n", nrow(tab)))

# ---- calibration (logit space) per estimator ----
fit_cal <- function(est, dat) {
  d <- dat %>% filter(is.finite(bf_true), bf_true > 0, bf_true < 1)
  d <- d[d[[est]] > 0 & d[[est]] < 1, ]
  m <- lm(as.formula(paste("qlogis(bf_true) ~ qlogis(", est, ")")), data = d)
  data.frame(estimator = est,
             a_intercept = coef(m)[1], b_slope = coef(m)[2],
             mae = mean(abs(d[[est]] - d$bf_true)),
             rmse = sqrt(mean((d[[est]] - d$bf_true)^2)))
}
ests <- c("bf_mc", "bf_med", "bf_mean", "bf_logodds", "bf_med_flat", "bf_mean_flat", "bf_fold", "bf_bc")
cal <- do.call(rbind, lapply(ests, function(e) fit_cal(e, tab)))
cal$mean_abs_bias <- sapply(ests, function(e) {
  d <- tab %>% filter(is.finite(bf_true), bf_true > 0, bf_true < 1)
  mean(abs(d[[e]] - d$bf_true))
})
print(cal)
write.csv(cal, file.path(OUT_DIR, "bf_algorithm_improvement_calibration.csv"), row.names = FALSE)

# ---- comparison figure (4 panels) ----
make_panel <- function(est, title, dat) {
  d <- dat %>% filter(is.finite(bf_true), bf_true > 0, bf_true < 1)
  d <- d[d[[est]] > 0 & d[[est]] < 1, ]
  m <- lm(as.formula(paste("qlogis(bf_true) ~ qlogis(", est, ")")), data = d)
  a <- coef(m)[1]; b <- coef(m)[2]
  ggplot(d, aes_string(x = est, y = "bf_true")) +
    geom_abline(slope = 1, intercept = 0, color = "#888888", linetype = "dashed") +
    geom_point(size = 1.4, alpha = 0.5, color = "#3a6ea5") +
    geom_smooth(method = "lm", se = FALSE, color = "#B83227", linewidth = 0.9) +
    coord_fixed(ratio = 1, xlim = c(0, 1), ylim = c(0, 1)) +
    labs(title = title, x = paste0(est, "  (estimated BF)"), y = "True BF") +
    annotate("label", x = 0.04, y = 0.96, hjust = 0, vjust = 1, size = 3.6,
             label = sprintf("intercept a = %.3f\nslope b = %.3f", a, b),
             fill = "white", color = "#B83227") +
    theme_minimal(base_size = 11) + theme(panel.grid.minor = element_blank())
}
p1 <- make_panel("bf_mc",     "A. MC plug-in BF  (current baseline)", tab)
p2 <- make_panel("bf_med",    "B. MCMC median BF  (current v37)", tab)
p3 <- make_panel("bf_mean",   "C. MCMC MEAN BF  [fix 1]", tab)
p4 <- make_panel("bf_logodds","D. MCMC mean-in-log-odds BF  [fix 2]", tab)
p5 <- make_panel("bf_med_flat",  "E. MCMC median BF, FLAT mu_B prior  [fix 3: removes shrinkage]", tab)
p6 <- make_panel("bf_mean_flat", "F. MCMC MEAN BF, FLAT mu_B prior  [fix 3: removes shrinkage]", tab)
figI <- (p1 + p2) / (p3 + p4) / (p5 + p6) + plot_layout(heights = c(1, 1, 1))
ggsave(file.path(OUT_DIR, "figI_bf_algorithm_improvement.png"),
       figI, width = 10, height = 12, dpi = 150, bg = "white")
cat("\nSaved: output/figures/continuous_bf/figI_bf_algorithm_improvement.png\n")
cat("Saved: output/figures/continuous_bf/bf_algorithm_improvement_calibration.csv\n")
