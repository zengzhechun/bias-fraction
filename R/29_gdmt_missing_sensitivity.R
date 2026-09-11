## ===========================================================================
##  v39 new analysis 2 - Missing-data sensitivity for case study question 2
##
##  Review finding #6: an indeterminate guideline-directed medical therapy
##  (GDMT) score at baseline. In the analytic cohort (Y_W0 == 0, n = 14,677,
##  the published denominator) this is 3,494 patients, 23.81%; across the full
##  screened file before the grace-period exclusion (n = 15,053) it is 3,665,
##  24.35%. Both figures are correct for their own denominator; the reported
##  one is 3,494 / 14,677.
##  In scripts/run_ltmle_gdmt.R line 77 those patients are hard-coded into the
##  control arm (`A_gdmt_W0[is.na(...)] <- 0`), i.e. "missing = not optimized".
##  That choice is a design decision, not a data fact, and it was neither
##  disclosed nor varied anywhere in v38. This script varies it.
##
##  Four handling schemes, all fitted with the identical TMLE specification
##  used in the manuscript (cross-sectional, single A node, 10 baseline
##  covariates, Y = 1-year all-cause mortality, SL.glm treatment model):
##
##    (A) indeterminate-as-suboptimal  NA -> 0        <- the published analysis
##    (B) complete case                drop NA rows
##    (C) indeterminate-as-optimized   NA -> 1        <- opposite extreme
##    (D) multiple imputation          m stochastic draws from a logistic model
##                                     of A on the baseline covariates, combined
##                                     by Rubin's rules
##
##  The bias attribution fraction for each scheme is computed with bsr_bootstrap(), the
##  SAME estimator that produced the published case-study BAF in
##  output/data/bsr_results_v35.rds (n_boot = 2000, seed = 42), and the verdict
##  is read from the SAME 12-bucket lookup that produced the published
##  verdicts. Nothing about the negative-control panel changes, so the only
##  quantity that moves across schemes is the target estimate itself.
##
##  Reproduction check: scheme (A) must return BAF 0.510, 95% CI 0.356-0.603,
##  which is the published question-2 row. The script asserts this.
##
##  Inputs : DATA/ltmle_wide_K2_gdmt.rds
##           DATA/bias_calibration_results.rds        (the 12 negative controls)
##           output/tables/v39_all_numbers.json        (the published lookup)
##  Outputs: output/tables/v39_gdmt_missing_sensitivity.csv
##           output/simulation/v39_gdmt_missing_sensitivity.rds
## ===========================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(jsonlite)
  library(ltmle)
  library(EmpiricalCalibration)
})

BASE     <- "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker"
DATA_DIR <- file.path(BASE, "DATA")
V39      <- file.path(BASE, "第39版")
TAB_DIR  <- file.path(V39, "output/tables")
SIM_DIR  <- file.path(V39, "output/simulation")

source(file.path(V39, "R/00_config.R"))
source(file.path(V39, "R/01_bsr_core.R"))   # bsr_bootstrap()

BF_BD <- 0.5; BF_ED <- 1/3
VERDICT_BREAKS <- c(0.15, 0.45, 0.65)
M_IMP  <- 10L
SEED   <- 39L
N_BOOT <- 2000L    # same as the published case-study run
BOOT_SEED <- 42L   # same as the published case-study run

verdict_of <- function(p) {
  ifelse(is.na(p), "insufficient evidence",
  ifelse(p <  VERDICT_BREAKS[1], "usable as effect evidence",
  ifelse(p <  VERDICT_BREAKS[2], "mixed, hypothesis-generating",
  ifelse(p <  VERDICT_BREAKS[3], "competitive, no verdict",
                                 "not usable as effect evidence"))))
}

## ---- empirical null and the published lookup -------------------------------
cr <- readRDS(file.path(DATA_DIR, "bias_calibration_results.rds"))
nc <- cr$negative_controls
nc_log_rr <- as.numeric(nc$logRr)
nc_se     <- as.numeric(nc$seLogRr)
nf <- fitNull(nc_log_rr, nc_se)
mu_b_hat <- unname(nf[1]); sigma_b <- unname(nf[2])
cat(sprintf("[null] K = %d negative controls; fitNull mu_B = %.4f, sigma_B = %.4f\n",
            length(nc_log_rr), mu_b_hat, sigma_b))

NUM  <- jsonlite::fromJSON(file.path(TAB_DIR, "v39_all_numbers.json"),
                           simplifyVector = FALSE)
lk <- NUM$part2$lookup
## The outer bin edges are -Inf and +Inf, which JSON encodes as null, so the
## edges are rebuilt from the per-bin upper limits rather than read directly.
upper    <- vapply(lk, function(x) if (is.null(x$bf_hi)) Inf else as.numeric(x$bf_hi),
                   numeric(1))
brk      <- c(-Inf, upper)                       # 13 edges -> 12 bins
LOOK_pbd <- vapply(lk, function(x) as.numeric(x$p_bd_conservative), numeric(1))
med_half <- as.numeric(NUM$part2$ci_width$median_half_width)
stopifnot(length(brk) == length(LOOK_pbd) + 1L)
cat(sprintf("[lookup] %d bins, median half-width %.4f, bin edges %.3f ... %.3f\n",
            length(LOOK_pbd), med_half, brk[1], brk[length(brk)]))

## BAF via the published estimator, then the published verdict path ------------
bf_from_estimate <- function(log_rr_obs, se_obs, tag, n = NA_integer_,
                             n_opted = NA_integer_) {
  bs <- bsr_bootstrap(log_rr_obs, se_obs, nc_log_rr, nc_se,
                      n_boot = N_BOOT, seed = BOOT_SEED)
  bf <- bs$bf_median; lo <- bs$bf_ci_lo; hi <- bs$bf_ci_hi
  half <- (hi - lo) / 2
  b <- max(which(brk[-length(brk)] <= bf))          # same bin rule as R/18
  cls <- if (half <= med_half) "narrow" else "wide"
  pbd <- LOOK_pbd[b]
  se_cal <- sqrt(se_obs^2 + sigma_b^2)
  cal_p  <- 2 * (1 - pnorm(abs(log_rr_obs - mu_b_hat) / se_cal))
  data.table(tag = tag, n = n, n_opted = n_opted,
             rr = exp(log_rr_obs),
             rr_lo = exp(log_rr_obs - 1.96 * se_obs),
             rr_hi = exp(log_rr_obs + 1.96 * se_obs),
             log_rr = log_rr_obs, se_log_rr = se_obs,
             rr_cal = exp(log_rr_obs - mu_b_hat),
             cal_p = cal_p,
             bf = bf, bf_lo = lo, bf_hi = hi, half_width = half,
             ci_class = cls, lookup_bin = b,
             p_bias_dominated = pbd,
             verdict = verdict_of(pbd),
             boot_n_fail = bs$n_fail)
}

## ---- cohort assembly ------------------------------------------------------
raw <- as.data.frame(readRDS(file.path(DATA_DIR, "ltmle_wide_K2_gdmt.rds")))
W0_vars <- c("L_qtc_W0", "L_hr_W0", "L_qrs_W0", "L_cr_W0", "L_egfr_W0",
             "L_k_W0", "L_af_W0", "L_lbbb_W0", "age", "gender")

prep <- function(d) {
  d <- d[d$Y_W0 == 0, ]
  d <- d[, c(W0_vars, "A_gdmt_W0", "Y_W1")]
  d$gender <- as.numeric(factor(d$gender, levels = c("M", "F")))
  for (col in W0_vars) {
    x <- d[[col]]
    x[is.infinite(x)] <- NA_real_; x[is.nan(x)] <- NA_real_
    if (sd(x, na.rm = TRUE) > 0.001) d[[col]] <- as.numeric(scale(x)) else
      d[[col]] <- x - mean(x, na.rm = TRUE)
    d[[col]][is.na(d[[col]])] <- 0
  }
  d$A_gdmt_W0 <- as.integer(d$A_gdmt_W0)
  d$Y_W1 <- as.integer(d$Y_W1)
  d
}

fit_once <- function(d, tag) {
  n_a <- nrow(d); n_opt <- sum(d$A_gdmt_W0 == 1)
  a1 <- matrix(1, n_a, 1, dimnames = list(NULL, "A_gdmt_W0"))
  a0 <- matrix(0, n_a, 1, dimnames = list(NULL, "A_gdmt_W0"))
  fit <- ltmle(data = d, Anodes = "A_gdmt_W0", Lnodes = W0_vars,
               Ynodes = "Y_W1", survivalOutcome = FALSE,
               abar = list(a1, a0), SL.library = "SL.glm")
  s <- summary(fit)
  rr <- s$effect.measures$RR$estimate
  ci <- s$effect.measures$RR$CI
  list(tag = tag, n = n_a, n_opted = n_opt,
       rr = rr, log_rr = log(rr), se = (log(ci[2]) - log(ci[1])) / (2 * 1.96))
}

base <- prep(raw)
nna  <- sum(is.na(base$A_gdmt_W0))
cat(sprintf("[cohort] %d patients after grace-period exclusion; %d (%.1f%%) indeterminate A\n",
            nrow(base), nna, 100 * nna / nrow(base)))

res <- list()

## (A) indeterminate-as-suboptimal  (the published analysis)
dA <- copy(base); dA$A_gdmt_W0[is.na(dA$A_gdmt_W0)] <- 0
res$A <- fit_once(dA, "indeterminate as suboptimal (published)")

## (B) complete case
dB <- base[!is.na(base$A_gdmt_W0), ]
res$B <- fit_once(dB, "complete case (indeterminate dropped)")

## (C) indeterminate-as-optimized (opposite extreme)
dC <- copy(base); dC$A_gdmt_W0[is.na(dC$A_gdmt_W0)] <- 1
res$C <- fit_once(dC, "indeterminate as optimized (opposite extreme)")

## (D) multiple imputation: logistic model of A on baseline covariates
set.seed(SEED)
mis    <- is.na(base$A_gdmt_W0)
glm_df <- base[!is.na(base$A_gdmt_W0), ]
form   <- as.formula(paste("A_gdmt_W0 ~", paste(W0_vars, collapse = " + ")))
gl     <- glm(form, data = glm_df, family = binomial())

Xmis  <- base[mis, W0_vars, drop = FALSE]
p_imp <- predict(gl, newdata = Xmis, type = "response")
cat(sprintf("[MI] imputation model on %d complete rows; predicted p(optimal) among the indeterminate: median %.3f (range %.3f-%.3f)\n",
            nrow(glm_df), median(p_imp), min(p_imp), max(p_imp)))

mi_fits <- vector("list", M_IMP)
for (m in seq_len(M_IMP)) {
  dD <- copy(base)
  dD$A_gdmt_W0[mis] <- rbinom(sum(mis), 1, p_imp)
  mi_fits[[m]] <- fit_once(dD, sprintf("multiple imputation (draw %d)", m))
  cat(sprintf("      imputation %d/%d done\r", m, M_IMP))
}
cat("\n")

log_rr_m <- sapply(mi_fits, `[[`, "log_rr")
se_m     <- sapply(mi_fits, `[[`, "se")
Qbar  <- mean(log_rr_m)
Ubar  <- mean(se_m^2)
Bvar  <- if (M_IMP > 1) var(log_rr_m) else 0
se_MI <- sqrt(Ubar + (1 + 1 / M_IMP) * Bvar)
res$D <- list(tag = sprintf("multiple imputation (m = %d, Rubin)", M_IMP),
              n = nrow(base), n_opted = NA_integer_,
              rr = exp(Qbar), log_rr = Qbar, se = se_MI)

## ---- bias attribution fraction under each scheme --------------------------------------
ALT <- rbindlist(lapply(res[c("A", "B", "C", "D")], function(x)
  bf_from_estimate(x$log_rr, x$se, x$tag, n = x$n,
                   n_opted = if (length(x$n_opted) == 0) NA_integer_ else x$n_opted)))
setcolorder(ALT, c("tag", "n", "n_opted", "rr", "rr_lo", "rr_hi", "log_rr",
                   "se_log_rr", "rr_cal", "cal_p", "bf", "bf_lo", "bf_hi",
                   "half_width", "ci_class", "lookup_bin", "p_bias_dominated",
                   "verdict", "boot_n_fail"))

## ---- reproduction check against the published question-2 row ---------------
pub <- NUM$part3$cases[[2]]
stopifnot(abs(ALT$bf[1]    - as.numeric(pub$bf))    < 0.01)
stopifnot(abs(ALT$bf_lo[1] - as.numeric(pub$bf_lo)) < 0.02)
stopifnot(abs(ALT$bf_hi[1] - as.numeric(pub$bf_hi)) < 0.02)
cat(sprintf("[check] published BAF %.4f (%.4f-%.4f) vs reproduced %.4f (%.4f-%.4f)  OK\n",
            as.numeric(pub$bf), as.numeric(pub$bf_lo), as.numeric(pub$bf_hi),
            ALT$bf[1], ALT$bf_lo[1], ALT$bf_hi[1]))

fwrite(ALT, file.path(TAB_DIR, "v39_gdmt_missing_sensitivity.csv"))
saveRDS(list(table = ALT, fits = res, mi = mi_fits,
             p_imp_summary = list(median = median(p_imp), min = min(p_imp),
                                  max = max(p_imp)),
             n_indeterminate = nna, null_fit = c(mu = mu_b_hat, sigma = sigma_b),
             session = list(seed = SEED, m = M_IMP, n_boot = N_BOOT,
                            boot_seed = BOOT_SEED, date = as.character(Sys.Date()))),
        file.path(SIM_DIR, "v39_gdmt_missing_sensitivity.rds"))

cat("\n[result] question 2 under four missing-data conventions\n")
print(ALT[, .(tag, n, rr = round(rr, 3), log_rr = round(log_rr, 4),
              se = round(se_log_rr, 4), cal_p = round(cal_p, 4),
              bf = round(bf, 3), ci = sprintf("%.3f-%.3f", bf_lo, bf_hi),
              verdict)])

cat("\n=== DONE (GDMT missing-data sensitivity) ===\n")
