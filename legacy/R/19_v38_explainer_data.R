# R/19_v38_explainer_data.R
# ---------------------------------------------------------------------------
# Chart-level data export for the v38 interactive explainer.
#
# R/18_v38_three_part_analysis.R produces the scalar single-source-of-truth
# (output/tables/v38_all_numbers.json). This script adds the *series* data the
# explainer needs to redraw every figure client-side in JavaScript, so that the
# explainer is a genuine single HTML file with no external image assets.
#
# Output: output/tables/v38_explainer_data.json
#   $ba_points   864 interior conditions (psi != -0.01): mean BF_true, mean difference, +-SD
#   $ba_full     96 boundary conditions (psi = -0.01), same fields
#   $diff_hist   histogram of (BF_hat - BF_true), interior
#   $roc         ROC curves (thinned) for calibrated p, BF, BF + CI width
#   $half_hist   histogram of the CI half-width, split by K (12, 25, 50)
#   $bf_by_true  BF_hat quantiles against BF_true (calibration of the estimator)
#   $cov_by_bin  CI coverage as a function of BF_true decile
# ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(jsonlite)
})

source("R/00_config.R")
source("R/01_bsr_core.R")

set.seed(20260827)
EX <- list()

cat("[0] loading simulation ...\n")
res <- readRDS(file.path(SIM_DIR, "comparison_results_v37p1.rds"))
stopifnot(length(res) == 960)

parse_key <- function(key) {
  psi  <- as.numeric(sub(".*_psi(-?[0-9.]+)_mu.*", "\\1", key))
  mu_b <- as.numeric(sub(".*_mu(-?[0-9.]+)_sps.*", "\\1", key))
  c(psi = psi, mu_b = mu_b)
}

parts <- vector("list", length(res))
for (i in seq_along(res)) {
  e   <- res[[i]]
  key <- names(res)[i]
  pm  <- parse_key(key)
  d   <- e$results
  parts[[i]] <- data.frame(
    cond      = key,
    psi       = pm[["psi"]],
    mu_b      = pm[["mu_b"]],
    sigma_ps  = e$sigma_ps,
    K         = if (grepl("K50", e$config_id)) 50L
                else if (grepl("K25", e$config_id)) 25L
                else 12L,
    exV       = if (grepl("exV0\\.3", e$config_id)) 0.3 else 0.0,
    bf_true   = e$bf_true,
    true_zone = e$true_zone,
    bf        = d$bf_mcmc,
    lo        = d$ci_lo_mcmc,
    hi        = d$ci_hi_mcmc,
    cal_p     = d$cal_p,
    naive_p   = d$naive_p,
    stringsAsFactors = FALSE
  )
}
S <- do.call(rbind, parts)
rm(parts); invisible(gc())

S$half     <- (S$hi - S$lo) / 2
S$diff     <- S$bf - S$bf_true
S$bd_tru   <- S$bf_true > BF_THRESH_BIAS
S$interior <- S$psi != -0.01
S$covered  <- S$lo <= S$bf_true & S$bf_true <= S$hi

# ---------------------------------------------------------------------------
# 1. Bland-Altman scatter, aggregated to the condition level
# ---------------------------------------------------------------------------
cat("[1] condition-level Bland-Altman points ...\n")

cond_ba <- function(df) {
  sp <- split(seq_len(nrow(df)), df$cond)
  out <- lapply(sp, function(ix) {
    z <- df[ix, ]
    data.frame(
      bf_true  = z$bf_true[1],
      psi      = z$psi[1],
      mu_b     = z$mu_b[1],
      K        = z$K[1],
      exV      = z$exV[1],
      sigma_ps = z$sigma_ps[1],
      mean_bf  = mean(z$bf),
      diff     = mean(z$diff),
      sd_diff  = sd(z$diff),
      stringsAsFactors = FALSE
    )
  })
  o <- do.call(rbind, out)
  o[order(o$bf_true), ]
}

ba_in  <- cond_ba(S[S$interior, ])
ba_out <- cond_ba(S[!S$interior, ])

rnd <- function(df, k = 4) {
  for (nm in names(df)) if (is.numeric(df[[nm]])) df[[nm]] <- round(df[[nm]], k)
  df
}
EX$ba_points <- rnd(ba_in)
EX$ba_full   <- rnd(ba_out)

# ---------------------------------------------------------------------------
# 2. Histogram of the difference (interior), for the BA marginal panel
# ---------------------------------------------------------------------------
cat("[2] difference histogram ...\n")
brk <- seq(-0.85, 0.85, by = 0.025)
h   <- hist(pmin(pmax(S$diff[S$interior], -0.849), 0.849), breaks = brk, plot = FALSE)
EX$diff_hist <- data.frame(
  mid   = round(h$mids, 4),
  count = as.integer(h$counts)
)

# ---------------------------------------------------------------------------
# 3. ROC curves (thinned to ~120 points each)
# ---------------------------------------------------------------------------
cat("[3] ROC curves ...\n")

roc_pts <- function(score, pos, n_out = 120) {
  ok <- is.finite(score) & !is.na(pos)
  score <- score[ok]; pos <- pos[ok]
  o <- order(score, decreasing = TRUE)
  pos <- pos[o]
  tp <- cumsum(pos); fp <- cumsum(!pos)
  P <- sum(pos); N <- sum(!pos)
  tpr <- tp / P; fpr <- fp / N
  auc <- sum(diff(c(0, fpr)) * (c(0, tpr[-length(tpr)]) + tpr) / 2)
  idx <- unique(round(seq(1, length(tpr), length.out = n_out)))
  list(
    fpr = round(c(0, fpr[idx]), 4),
    tpr = round(c(0, tpr[idx]), 4),
    auc = round(auc, 4)
  )
}

# ROC curves are computed on the full 960,000 simulated repetitions.
# An earlier draft subsampled 200,000 here for speed; the full set
# runs in a few seconds and reviewers will (rightly) ask why a subset
# was used when the whole design fits.
# orientation: higher score = more likely truly bias-dominated
fit_ci <- glm(bd_tru ~ bf + half, data = S, family = binomial())
EX$roc <- list(
  cal_p   = roc_pts(S$cal_p, S$bd_tru),
  bf      = roc_pts(S$bf,    S$bd_tru),
  bf_ci   = roc_pts(as.numeric(predict(fit_ci)), S$bd_tru),
  n       = nrow(S)
)

# ---------------------------------------------------------------------------
# 4. CI half-width distribution, by number of negative controls
# ---------------------------------------------------------------------------
cat("[4] CI half-width distribution ...\n")
brk2 <- seq(0, 0.55, by = 0.0125)
hh <- lapply(c(12, 25, 50), function(k) {
  x <- pmin(S$half[S$K == k], 0.5499)
  hs <- hist(x, breaks = brk2, plot = FALSE)
  data.frame(mid = round(hs$mids, 4), count = as.integer(hs$counts))
})
EX$half_hist <- list(
  K12    = hh[[1]],
  K25    = hh[[2]],
  K50    = hh[[3]],
  median = round(median(S$half), 4),
  q1     = round(quantile(S$half, 0.25), 4)[[1]],
  q3     = round(quantile(S$half, 0.75), 4)[[1]]
)

# ---------------------------------------------------------------------------
# 5. BF_hat distribution against BF_true (estimator calibration ribbon)
# ---------------------------------------------------------------------------
cat("[5] BF_hat quantiles by BF_true ...\n")
S$bf_true_r <- round(S$bf_true, 4)
tv <- sort(unique(S$bf_true_r))
qtab <- lapply(tv, function(t) {
  z <- S$bf[S$bf_true_r == t]
  q <- as.numeric(quantile(z, c(0.05, 0.25, 0.5, 0.75, 0.95)))
  data.frame(bf_true = t, n = length(z),
             p05 = round(q[1], 4), p25 = round(q[2], 4), p50 = round(q[3], 4),
             p75 = round(q[4], 4), p95 = round(q[5], 4))
})
EX$bf_by_true <- do.call(rbind, qtab)

# ---------------------------------------------------------------------------
# 6. Coverage of the 95% CI by BF_true decile and by CI-width class
# ---------------------------------------------------------------------------
cat("[6] coverage by BF_true ...\n")
med_half <- median(S$half)
S$wide   <- S$half > med_half
cut10 <- cut(S$bf_true, breaks = quantile(S$bf_true, seq(0, 1, 0.1)),
             include.lowest = TRUE, labels = FALSE)
cv <- lapply(sort(unique(cut10)), function(g) {
  ix <- cut10 == g
  data.frame(
    decile     = g,
    bf_true_lo = round(min(S$bf_true[ix]), 4),
    bf_true_hi = round(max(S$bf_true[ix]), 4),
    centre     = round(mean(S$bf_true[ix]), 4),
    cov_all    = round(mean(S$covered[ix]), 4),
    cov_narrow = round(mean(S$covered[ix & !S$wide]), 4),
    cov_wide   = round(mean(S$covered[ix &  S$wide]), 4)
  )
})
EX$cov_by_bin <- do.call(rbind, cv)
EX$coverage <- list(
  overall = round(mean(S$covered), 4),
  narrow  = round(mean(S$covered[!S$wide]), 4),
  wide    = round(mean(S$covered[S$wide]), 4),
  med_half = round(med_half, 4)
)

# ---------------------------------------------------------------------------
# 7. Layer-1 pass rate surface over (psi, mu_b), for the interface panel
# ---------------------------------------------------------------------------
cat("[7] layer-1 surface ...\n")
gr <- expand.grid(psi = sort(unique(S$psi)), mu_b = sort(unique(S$mu_b)))
gr$pass <- NA_real_; gr$bd <- NA_real_; gr$bf_true <- NA_real_
for (i in seq_len(nrow(gr))) {
  ix <- S$psi == gr$psi[i] & S$mu_b == gr$mu_b[i]
  gr$pass[i]    <- round(mean(S$cal_p[ix] < 0.05), 4)
  gr$bd[i]      <- round(mean(S$bd_tru[ix]), 4)
  gr$bf_true[i] <- round(mean(S$bf_true[ix]), 4)
}
EX$layer1_surface <- gr

# ---------------------------------------------------------------------------
write_json(EX, file.path(TAB_DIR, "v38_explainer_data.json"),
           auto_unbox = TRUE, digits = 6, na = "null")
cat(sprintf("[done] wrote %s (%.0f KB)\n",
            file.path(TAB_DIR, "v38_explainer_data.json"),
            file.size(file.path(TAB_DIR, "v38_explainer_data.json")) / 1024))
