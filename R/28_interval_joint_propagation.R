## ===========================================================================
##  v39 new analysis 2 — Does holding the effect estimate fixed drive the
##                      undercoverage of the BAF credible interval?
##
##  Motivation (review finding): the published 95% credible interval for BAF
##  contained the true value in only 71.1% of simulated repetitions. Two
##  mechanisms were named in the manuscript: (i) the interval propagates
##  uncertainty in the empirical null while holding the effect estimate psi-hat
##  at its observed value, and (ii) only M = 300 posterior draws are retained.
##  Mechanism (ii) is a computation budget and can be fixed; mechanism (i) is a
##  construction choice whose cost had never been quantified.
##
##  This script quantifies it directly by building BOTH intervals from the same
##  posterior draws in the same repetitions:
##
##    current : BAF = |mu| / (|mu| + |psi_obs - mu|)          mu ~ posterior
##    joint   : BAF = |mu| / (|mu| + |psi_obs - mu + eps|)    eps ~ N(0, se_psi^2)
##
##  eps represents the sampling variability of the effect estimate, which the
##  current interval omits. The comparison is within-repetition, so the two
##  intervals see identical synthetic data.
##
##  Subgrid: K in {12, 50}, exchangeability violation = 0, both sigma_psi
##  levels, the full 10 x 8 effect/bias grid = 320 conditions x 200 repetitions
##  = 64,000 repetitions. K = 25 is omitted to keep the runtime near 12 minutes;
##  the two retained panel sizes bracket the published sensitivity range.
##
##  Input : output/simulation/comparison_results_v37p1.rds  (condition names
##          and design levels only; the data are regenerated here)
##  Output: output/tables/v39_interval_joint_propagation.csv
##          output/tables/v39_interval_joint_by_K.csv
##          output/simulation/v39_interval_joint_reps.rds
## ===========================================================================

suppressPackageStartupMessages({ library(data.table) })

BASE  <- "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/第39版"
OUT_T <- file.path(BASE, "output/tables")
OUT_S <- file.path(BASE, "output/simulation")

MCMC_ITER   <- 400L
MCMC_WARMUP <- 100L
N_REP       <- 200L
KEEP        <- c(12L, 50L)
SEED_BASE   <- 39000L

BF_BD <- 0.5
BF_ED <- 1/3

## ---- Gibbs sampler, copied verbatim from R/02_comparison_study.R ----------
mcmc_fit_null <- function(nc_log_rr, nc_se_log_rr,
                          n_iter = 1500, n_warmup = 500, seed = 42,
                          mu_prior_mean = 0, mu_prior_var = 1,
                          sigma2_prior_shape = 0.5, sigma2_prior_scale = 0.05) {
  set.seed(seed)
  y <- as.numeric(nc_log_rr); s <- as.numeric(nc_se_log_rr); n <- length(y)
  mu <- mean(y); sigma2 <- max(var(y) - mean(s^2), 1e-6)
  mu_draws <- numeric(n_iter); sigma2_draws <- numeric(n_iter)
  for (i in seq_len(n_iter)) {
    v_total   <- sigma2 + s^2
    prec_post <- 1 / mu_prior_var + sum(1 / v_total)
    mean_post <- (mu_prior_mean / mu_prior_var + sum(y / v_total)) / prec_post
    mu <- rnorm(1, mean_post, sqrt(1 / prec_post))
    shape_post <- sigma2_prior_shape + n / 2
    scale_post <- sigma2_prior_scale + 0.5 * sum((y - mu)^2 + s^2)
    sigma2 <- 1 / rgamma(1, shape = shape_post, rate = scale_post)
    mu_draws[i] <- mu; sigma2_draws[i] <- sigma2
  }
  keep <- (n_warmup + 1):n_iter
  list(mu_draws = mu_draws[keep], sigma2_draws = sigma2_draws[keep],
       mu_mean = mean(mu_draws[keep]),
       sigma_mean = sqrt(mean(sigma2_draws[keep])))
}

bsr_to_bf <- function(bsr) bsr / (1 + bsr)

## ---- condition grid --------------------------------------------------------
res <- readRDS(file.path(BASE, "output/simulation/comparison_results_v37p1.rds"))
cfg <- rbindlist(lapply(seq_along(res), function(i) {
  e <- res[[i]]
  data.table(
    cond        = names(res)[i],
    true_log_rr = e$config$true_log_rr,
    bias_mu     = e$config$bias_mu,
    bias_sigma  = e$config$bias_sigma,
    n_nc        = as.integer(e$config$n_nc),
    ex_violation= e$config$ex_violation,
    se_psi_obs  = e$config$se_psi_obs,
    bf_true     = e$bf_true,
    true_zone   = e$true_zone
  )
}))
cfg <- cfg[n_nc %in% KEEP & ex_violation == 0]
setorder(cfg, n_nc, se_psi_obs, true_log_rr, bias_mu)
cfg[, combo_idx := .I]
cat(sprintf("[grid] %d conditions x %d reps = %s repetitions\n",
            nrow(cfg), N_REP, format(nrow(cfg) * N_REP, big.mark = ",")))

## ---- one condition ---------------------------------------------------------
run_condition <- function(cond_name, true_log_rr, bias_mu, bias_sigma, n_nc,
                          se_psi_obs, n_rep, seed) {
  set.seed(seed)
  nc_bias <- rep(bias_mu, n_nc)                 # ex_violation = 0
  out <- data.table(
    rep = seq_len(n_rep),
    bf_cur = NA_real_, lo_cur = NA_real_, hi_cur = NA_real_,
    bf_jnt = NA_real_, lo_jnt = NA_real_, hi_jnt = NA_real_, width_mu = NA_real_
  )
  for (r in seq_len(n_rep)) {
    nc_log_rr  <- rnorm(n_nc, mean = nc_bias, sd = bias_sigma)
    nc_se      <- runif(n_nc, 0.03, 0.12)
    obs_log_rr <- true_log_rr + bias_mu + rnorm(1, 0, se_psi_obs)

    post     <- mcmc_fit_null(nc_log_rr, nc_se, n_iter = MCMC_ITER,
                              n_warmup = MCMC_WARMUP, seed = seed + r)
    mu_draws <- post$mu_draws

    ## current construction: psi_obs fixed, only mu varies
    lt_cur  <- obs_log_rr - mu_draws
    bf_cur  <- bsr_to_bf(abs(mu_draws) / pmax(abs(lt_cur), 1e-8))
    ## joint construction: add the sampling variability of the effect estimate
    eps     <- rnorm(length(mu_draws), 0, se_psi_obs)
    lt_jnt  <- obs_log_rr - mu_draws + eps
    bf_jnt  <- bsr_to_bf(abs(mu_draws) / pmax(abs(lt_jnt), 1e-8))

    q <- function(v, p) as.numeric(quantile(v, p))
    ## Quantiles are computed OUTSIDE the data.table `[` call. Inside it,
    ## column names shadow same-named local variables, so computing in place
    ## would silently quantile the still-empty NA columns instead.
    vals <- list(
      bf_cur   = q(bf_cur, 0.5),
      lo_cur   = q(bf_cur, 0.025),
      hi_cur   = q(bf_cur, 0.975),
      bf_jnt   = q(bf_jnt, 0.5),
      lo_jnt   = q(bf_jnt, 0.025),
      hi_jnt   = q(bf_jnt, 0.975),
      width_mu = q(bf_cur, 0.975) - q(bf_cur, 0.025)
    )
    stopifnot(all(vapply(vals, function(x) length(x) == 1L && is.finite(x), logical(1))))
    out[r, (names(vals)) := vals]
  }
  out[, `:=`(cond = cond_name, true_log_rr = true_log_rr, bias_mu = bias_mu,
             n_nc = n_nc, se_psi_obs = se_psi_obs,
             bf_true = NA_real_)]
  out
}

## ---- run -------------------------------------------------------------------
cat("[run] Gibbs sampler, 2 intervals per repetition ...\n")
t0 <- Sys.time()
REP <- vector("list", nrow(cfg))
for (i in seq_len(nrow(cfg))) {
  cc <- cfg[i]
  REP[[i]] <- run_condition(cc$cond, cc$true_log_rr, cc$bias_mu, cc$bias_sigma,
                            cc$n_nc, cc$se_psi_obs, N_REP,
                            seed = SEED_BASE + cc$combo_idx * 1000L)
  REP[[i]][, bf_true := cc$bf_true]
  if (i %% 40 == 0) {
    el <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
    cat(sprintf("    %3d / %d conditions   %.1f min elapsed\n", i, nrow(cfg), el))
  }
}
R <- rbindlist(REP)
R[, `:=`(half_cur = (hi_cur - lo_cur)/2, half_jnt = (hi_jnt - lo_jnt)/2)]
R[, `:=`(bd_tru = bf_true > BF_BD, ed_tru = bf_true < BF_ED)]
cat(sprintf("[run] finished in %.1f min\n",
            as.numeric(difftime(Sys.time(), t0, units = "mins"))))

## ---- summary ---------------------------------------------------------------
summ_one <- function(d) {
  data.table(
    n                      = nrow(d),
    coverage_current       = 100 * mean(d$lo_cur <= d$bf_true & d$bf_true <= d$hi_cur),
    coverage_joint         = 100 * mean(d$lo_jnt <= d$bf_true & d$bf_true <= d$hi_jnt),
    median_halfwidth_current = median(d$half_cur),
    median_halfwidth_joint   = median(d$half_jnt),
    median_width_gain        = median(d$half_jnt - d$half_cur),
    ## R3-style rule: whole interval clear of the bias-dominated zone
    R3_yield_current       = 100 * mean(d$hi_cur <= BF_BD),
    R3_yield_joint         = 100 * mean(d$hi_jnt <= BF_BD),
    R3_misuse_current      = 100 * mean(d$bd_tru[d$hi_cur <= BF_BD]),
    R3_misuse_joint        = 100 * mean(d$bd_tru[d$hi_jnt <= BF_BD]),
    pct_reps_rule_switched = 100 * mean((d$hi_cur <= BF_BD) != (d$hi_jnt <= BF_BD))
  )
}
OVERALL <- cbind(scope = "all retained conditions (K = 12 and 50, exV = 0)", summ_one(R))
BY_K <- rbindlist(lapply(sort(unique(R$n_nc)), function(k)
  cbind(scope = sprintf("K = %d", k), summ_one(R[n_nc == k]))))
BY_SPS <- rbindlist(lapply(sort(unique(R$se_psi_obs)), function(s)
  cbind(scope = sprintf("sigma_psi = %.2f", s), summ_one(R[se_psi_obs == s]))))
SUM <- rbind(OVERALL, BY_K, BY_SPS)

fwrite(SUM, file.path(OUT_T, "v39_interval_joint_propagation.csv"))
print(SUM[, .(scope,
              cov_cur = round(coverage_current, 1), cov_jnt = round(coverage_joint, 1),
              half_cur = round(median_halfwidth_current, 3), half_jnt = round(median_halfwidth_joint, 3),
              R3_cur = round(R3_yield_current, 1), R3_jnt = round(R3_yield_joint, 1),
              switch = round(pct_reps_rule_switched, 1))])

## per-condition coverage, so the supplement can show it is not driven by a
## handful of grid cells
COND <- R[, .(n = .N,
              bf_true = bf_true[1], true_log_rr = true_log_rr[1],
              bias_mu = bias_mu[1], n_nc = n_nc[1], se_psi_obs = se_psi_obs[1],
              coverage_current = 100 * mean(lo_cur <= bf_true & bf_true <= hi_cur),
              coverage_joint   = 100 * mean(lo_jnt <= bf_true & bf_true <= hi_jnt),
              half_cur = median(half_cur), half_jnt = median(half_jnt)),
          by = cond]
fwrite(COND, file.path(OUT_T, "v39_interval_joint_by_K.csv"))
cat(sprintf("[by condition] median coverage current %.1f%%, joint %.1f%%; conditions at 0%%: %d vs %d\n",
            median(COND$coverage_current), median(COND$coverage_joint),
            sum(COND$coverage_current == 0), sum(COND$coverage_joint == 0)))

saveRDS(list(reps = R, summary = SUM, by_condition = COND,
             design = list(n_conditions = nrow(cfg), n_rep = N_REP,
                           K = KEEP, sigma_psi = sort(unique(R$se_psi_obs)),
                           mcmc_iter = MCMC_ITER, mcmc_warmup = MCMC_WARMUP,
                           seed_base = SEED_BASE, date = as.character(Sys.Date()))),
        file.path(OUT_S, "v39_interval_joint_reps.rds"))

cat("\n=== DONE (joint propagation) ===\n")
