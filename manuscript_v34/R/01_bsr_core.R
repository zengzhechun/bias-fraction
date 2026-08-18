# Credibility Metric Core Estimation Functions
# v34: Bias Fraction (BF) is the primary metric. BF = BER / (1 + BER) in [0,1].
#   BER = |mu_B| / |psi_tilde| is retained as the auxiliary ratio (same object as v33).
#   Code keeps bsr_* function/object names for backward compatibility.
# v34 fixes (per peer-review round 2):
#   1. bf_point() reports the bootstrap-median point estimate (log-scale median back-
#      transformed), so the point estimate and CI come from the same distribution.
#   2. bsr_fieller() adds a Fieller-theorem interval for the ratio mu_B / psi_tilde,
#      which degenerates honestly when the denominator is too noisy.
#   3. Zone classification uses BF thresholds: >0.5 bias-dominated, <1/3 effect-
#      dominated, otherwise mixed (identical partition to BER >1 / <0.5).

library(data.table)
library(EmpiricalCalibration)

# ---- BER <-> BF transforms ----
ber_to_bf <- function(ber) ber / (1 + ber)
bf_to_ber <- function(bf) bf / (1 - bf)

# ---- Core Estimator (BER + BF) ----
bsr_estimate <- function(log_rr_uncal, se_log_rr, nc_log_rr, nc_se_log_rr) {
  null_fit <- fitNull(nc_log_rr, nc_se_log_rr)
  mu_bias <- null_fit[1]
  sigma_bias <- null_fit[2]
  log_rr_true <- log_rr_uncal - mu_bias
  bsr <- abs(mu_bias) / abs(log_rr_true)
  bf <- ber_to_bf(bsr)
  list(
    mu_bias = mu_bias, sigma_bias = sigma_bias,
    log_rr_uncal = log_rr_uncal, log_rr_true = log_rr_true,
    rr_uncal = exp(log_rr_uncal), rr_true = exp(log_rr_true),
    rr_bias = exp(mu_bias),
    bsr = bsr, bf = bf,
    cal_p = calibrateP(null_fit, log_rr_uncal, se_log_rr),
    null_fit = null_fit
  )
}

# ---- Bootstrap CI (log scale; applies to BER and, via logit, to BF) ----
bsr_bootstrap <- function(log_rr_uncal, se_log_rr, nc_log_rr, nc_se_log_rr,
                          n_boot = 2000, seed = 42) {
  set.seed(seed)
  K <- length(nc_log_rr)
  boot_bsr <- numeric(n_boot)
  boot_mu <- numeric(n_boot)
  n_fail <- 0L

  log_bsr <- numeric(n_boot)
  for (b in seq_len(n_boot)) {
    idx <- sample(seq_len(K), K, replace = TRUE)
    nc_l <- nc_log_rr[idx]; nc_s <- nc_se_log_rr[idx]
    nf <- tryCatch(fitNull(nc_l, nc_s), error = function(e) NULL)
    if (is.null(nf)) {
      n_fail <- n_fail + 1L
      log_bsr[b] <- NA
      boot_bsr[b] <- NA
      boot_mu[b] <- NA
      next
    }
    mu_b <- nf[1]
    lt <- log_rr_uncal - mu_b
    if (abs(lt) < 1e-8) lt <- if (lt >= 0) 1e-8 else -1e-8
    boot_bsr[b] <- abs(mu_b) / abs(lt)
    boot_mu[b] <- mu_b
    # store on the log scale; floor avoids log(0) when mu_b = 0
    log_bsr[b] <- log(pmax(abs(mu_b) / abs(lt), 1e-4))
  }
  boot_bsr_valid <- boot_bsr[!is.na(boot_bsr)]
  if (length(boot_bsr_valid) < n_boot * 0.5) {
    warning(sprintf("Bootstrap success rate low: %d/%d iterations failed", n_fail, n_boot))
  }
  log_bsr_ok <- log_bsr[!is.na(log_bsr)]
  log_ci <- quantile(log_bsr_ok, c(0.025, 0.975), na.rm = TRUE)
  ci <- exp(log_ci)
  # v34: bootstrap-median point estimate (log-scale median back-transformed), so the
  # point estimate and CI come from one distribution; avoids the v33 pathology where
  # the raw-ratio point estimate fell outside its own bootstrap CI.
  ber_median <- exp(median(log_bsr_ok, na.rm = TRUE))
  list(ci_lo = ci[1], ci_hi = ci[2],
       ber_median = ber_median, bf_median = ber_to_bf(ber_median),
       bf_ci_lo = ber_to_bf(ci[1]), bf_ci_hi = ber_to_bf(ci[2]),
       boot_dist = boot_bsr, boot_bf_dist = ber_to_bf(boot_bsr),
       mu_draws = boot_mu,
       n_fail = n_fail, n_boot = n_boot,
       success_rate = 1 - n_fail / n_boot)
}

# ---- Fieller interval for rho = mu_B / psi_tilde (psi_tilde = psi_obs - mu_B) ----
# Variances: Var(mu_B) = v11 (from the empirical null fit), Var(psi_obs) = se_obs^2.
# Cov(mu_B, psi_tilde) = -v11 (psi_obs independent of the negative controls).
# The (1-alpha) Fieller set is {rho : (m1 - rho*m2)^2 <= z^2 (v11 - 2*rho*v12 + rho^2*v22)}.
# region: "interior" (bounded [lo,hi], A>0), "exterior" ((-Inf,lo] U [hi,Inf), A<0),
# "empty" (A>0, disc<0), or "whole" (A<0, disc<0).
bsr_fieller <- function(mu_b, v11, log_rr_uncal, se_log_rr, alpha = 0.05) {
  m1 <- mu_b
  m2 <- log_rr_uncal - mu_b
  v22 <- se_log_rr^2 + v11
  v12 <- -v11
  z <- qnorm(1 - alpha / 2)
  A <- m2^2 - z^2 * v22
  B <- -2 * (m1 * m2 - z^2 * v12)
  C <- m1^2 - z^2 * v11
  disc <- B^2 - 4 * A * C
  if (disc < 0) {
    if (A > 0) return(list(lo = NA_real_, hi = NA_real_, region = "empty"))
    return(list(lo = NA_real_, hi = NA_real_, region = "whole"))
  }
  roots <- sort((-B + c(-1, 1) * sqrt(disc)) / (2 * A))
  region <- if (A > 0) "interior" else "exterior"
  list(lo = roots[1], hi = roots[2], region = region)
}

# ---- Classification (BF thresholds; same partition as BER thresholds) ----
bsr_classify <- function(bsr, ci_lo = NA_real_, ci_hi = NA_real_) {
  bf <- ber_to_bf(bsr)
  if (is.na(bsr)) return("unclassifiable")
  if (is.na(ci_lo) || is.na(ci_hi)) {
    if (bf > BF_THRESH_BIAS) return("bias-dominated")
    if (bf < BF_THRESH_EFFECT) return("effect-dominated")
    return("mixed")
  }
  bf_lo <- ber_to_bf(ci_lo); bf_hi <- ber_to_bf(ci_hi)
  if (bf_lo > BF_THRESH_BIAS) return("bias-dominated")
  if (bf_hi < BF_THRESH_EFFECT) return("effect-dominated")
  return("mixed")
}

# ---- LOO Sensitivity ----
bsr_loo <- function(log_rr_uncal, se_log_rr, nc_log_rr, nc_se_log_rr) {
  K <- length(nc_log_rr)
  results <- data.frame(
    excluded_nc = character(K), bsr = numeric(K), bf = numeric(K),
    ci_lo = numeric(K), ci_hi = numeric(K), bf_ci_lo = numeric(K),
    bf_ci_hi = numeric(K),
    class = character(K), stringsAsFactors = FALSE
  )
  for (i in seq_len(K)) {
    nc_l <- nc_log_rr[-i]; nc_s <- nc_se_log_rr[-i]
    res <- bsr_estimate(log_rr_uncal, se_log_rr, nc_l, nc_s)
    boot <- bsr_bootstrap(log_rr_uncal, se_log_rr, nc_l, nc_s, n_boot = 500)
    results$excluded_nc[i] <- names(nc_log_rr)[i]
    results$bsr[i] <- res$bsr
    results$bf[i] <- res$bf
    results$ci_lo[i] <- boot$ci_lo
    results$ci_hi[i] <- boot$ci_hi
    results$bf_ci_lo[i] <- boot$bf_ci_lo
    results$bf_ci_hi[i] <- boot$bf_ci_hi
    results$class[i] <- bsr_classify(res$bsr, boot$ci_lo, boot$ci_hi)
  }
  results
}

# ---- Diagnostic Functions ----
bsr_diagnostics <- function(nc_log_rr, nc_se_log_rr) {
  null_fit <- fitNull(nc_log_rr, nc_se_log_rr)
  residuals <- nc_log_rr - null_fit[1]
  marginal_sd <- sqrt(nc_se_log_rr^2 + null_fit[2]^2)
  std_residuals <- residuals / marginal_sd

  shapiro_p <- tryCatch(shapiro.test(std_residuals)$p.value, error = function(e) NA)
  std_residual_abs <- abs(std_residuals)
  q_norm <- qnorm(ppoints(length(residuals)))

  list(
    mu = null_fit[1], sigma = null_fit[2],
    residuals = residuals, std_residuals = std_residuals,
    shapiro_p = shapiro_p,
    std_residual_abs = std_residual_abs,
    qq_x = q_norm, qq_y = sort(std_residuals)
  )
}

cat("BSR core functions loaded (v34: BF primary, BER auxiliary, Fieller added).\n")
