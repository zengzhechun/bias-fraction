# R/21_youden_thresholds.R
# Youden-index-optimal operating points for the two ROC curves:
#   (a) BF_hat alone          -> threshold is a BF value
#   (b) BF_hat + CI half-width -> threshold is a logistic score; report the
#       decision boundary in (BF, half) space
suppressPackageStartupMessages({ library(jsonlite) })
source("R/00_config.R")
source("R/01_bsr_core.R")

res <- readRDS(file.path(SIM_DIR, "comparison_results_v37p1.rds"))
parse_key <- function(key) {
  psi  <- as.numeric(sub(".*_psi(-?[0-9.]+)_mu.*", "\\1", key))
  mu_b <- as.numeric(sub(".*_mu(-?[0-9.]+)_sps.*", "\\1", key))
  c(psi = psi, mu_b = mu_b)
}
parts <- vector("list", length(res))
for (i in seq_along(res)) {
  e <- res[[i]]; pm <- parse_key(names(res)[i]); d <- e$results
  parts[[i]] <- data.frame(bf_true = e$bf_true,
                           bf = d$bf_mcmc, lo = d$ci_lo_mcmc, hi = d$ci_hi_mcmc,
                           cal_p = d$cal_p, stringsAsFactors = FALSE)
}
S <- do.call(rbind, parts)
S$half   <- (S$hi - S$lo) / 2
S$bd_tru <- S$bf_true > BF_THRESH_BIAS
cat(sprintf("n = %s; prevalence of bias-dominated = %.3f\n",
            format(nrow(S), big.mark = ","), mean(S$bd_tru)))

# AUC helper. n1/n0 are cast to double: sum() on a logical returns an integer,
# and n1 * n0 overflows .Machine$integer.max once the grid reaches ~1e5 rows
# (960,000 reps here), which silently turns every AUC into NA.
auc_of <- function(score, pos) {
  r  <- rank(score)
  n1 <- as.numeric(sum(pos)); n0 <- as.numeric(sum(!pos))
  (sum(r[pos]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

youden <- function(score, pos) {
  o  <- order(score, decreasing = TRUE)   # score high = flagged as bias-dominated
  s  <- score[o]; p <- pos[o]
  tp <- cumsum(p); fp <- cumsum(!p)
  n1 <- sum(p); n0 <- sum(!p)
  sens <- tp / n1; fpr <- fp / n0
  J <- sens + (1 - fpr) - 1
  k <- which.max(J)
  list(th = s[k], sens = sens[k], spec = 1 - fpr[k], J = J[k])
}

# (a) BF alone
ya <- youden(S$bf, S$bd_tru)
cat(sprintf("\n[BF alone]  AUC %.4f\n  Youden-max: BF threshold = %.4f  ->  sens %.3f, spec %.3f, J = %.3f\n",
            auc_of(S$bf, S$bd_tru),
            ya$th, ya$sens, ya$spec, ya$J))

# (b) BF + CI half-width (logistic combination, same as paper's m_bfci)
m_bfci <- glm(bd_tru ~ bf + half, data = S, family = binomial())
lp  <- predict(m_bfci, type = "link")
yb  <- youden(lp, S$bd_tru)
auc2 <- auc_of(lp, S$bd_tru)
cf <- coef(m_bfci)
cat(sprintf("\n[BF + CI half-width]  AUC %.4f  (coef: b0=%.3f, b_bf=%.3f, b_half=%.3f)\n",
            auc2, cf[1], cf[2], cf[3]))
cat(sprintf("  Youden-max: score threshold = %.4f  ->  sens %.3f, spec %.3f, J = %.3f\n",
            yb$th, yb$sens, yb$spec, yb$J))
# decision boundary: b0 + b_bf*BF + b_half*half = th  ->  BF as fn of half
cat("  Decision boundary (BF at Youden point as a function of CI half-width):\n")
for (h in c(min(S$half), quantile(S$half, .25), median(S$half), quantile(S$half, .75), max(S$half))) {
  bf_at <- (yb$th - cf[1] - cf[3]*h) / cf[2]
  cat(sprintf("    half-width = %6.4f  ->  BF cutoff = %6.4f\n", h, bf_at))
}
# BF cutoff at the median half-width is the interpretable summary
med_half <- median(S$half)
bf_cut <- (yb$th - cf[1] - cf[3]*med_half) / cf[2]
cat(sprintf("\nSummary: BF-alone cutoff = %.3f; BF+CI model cutoff at median half-width (%.4f) = BF %.3f\n",
            ya$th, med_half, bf_cut))
