# Small-K empirical null simulation: plugin vs variance-inflated vs t-predictive
# Ground truth set to the real BB study: mu_B = -0.190, sigma_B = 0.068,
# within-control SEs sampled from the 12 real MIMIC-IV NC SEs.
suppressMessages(library(EmpiricalCalibration))
set.seed(20260819)

nc <- readRDS("/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/DATA/bias_calibration_results.rds")$negative_controls
sePool <- nc$seLogRr
muT    <- -0.1905
sigT   <- 0.0680
seTar  <- 0.0561   # BB 1-Year Mortality target SE (table01)
obsRR  <- -0.1842  # BB uncalibrated ln(RR)

Ks <- c(5, 8, 12, 20, 45, 100)
R  <- 2000
out <- NULL

fit1 <- function(gk, sk) {
  nn <- suppressWarnings(EmpiricalCalibration::fitNull(gk, sk))
  mu <- nn[1]; sg <- nn[2]
  if (!is.finite(mu)) mu <- mean(gk)
  if (!is.finite(sg) || sg < 0) sg <- 0
  c(mu, sg)
}

for (K in Ks) {
  sigH <- rep(NA, R); muErr <- rep(NA, R)
  rejP <- rejI <- rejT <- rejO <- rep(NA, R); bd <- rep(FALSE, R)
  for (i in seq_len(R)) {
    sk <- sample(sePool, K, replace = TRUE)
    gk <- rnorm(K, muT, sqrt(sk^2 + sigT^2))
    fh <- fit1(gk, sk); mu <- fh[1]; sg <- fh[2]
    gt <- rnorm(1, muT, sqrt(seTar^2 + sigT^2))  # null target, bias from same dist
    v0 <- seTar^2 + sg^2
    z0 <- abs(gt - mu) / sqrt(v0)
    rejP[i] <- 2 * (1 - pnorm(z0)) < 0.05
    vmu <- 1 / sum(1 / (sk^2 + sg^2))            # ML Var(mu_hat) given sg
    zI  <- abs(gt - mu) / sqrt(v0 + vmu)
    rejI[i] <- 2 * (1 - pnorm(zI)) < 0.05
    rejT[i] <- 2 * (1 - pt(zI, df = K - 2)) < 0.05
    rejO[i] <- 2 * (1 - pnorm(abs(gt - muT) / sqrt(seTar^2 + sigT^2))) < 0.05
    sigH[i] <- sg; muErr[i] <- abs(mu - muT); bd[i] <- (sg < 1e-4)
  }
  out <- rbind(out, data.frame(
    K = K,
    typeI_plugin = round(mean(rejP), 3),
    typeI_inflated = round(mean(rejI), 3),
    typeI_tKm2 = round(mean(rejT), 3),
    typeI_oracle = round(mean(rejO), 3),
    sigma_rmse = round(sqrt(mean((sigH - sigT)^2)), 4),
    sigma_q25 = round(quantile(sigH, .25), 4),
    sigma_med = round(median(sigH), 4),
    sigma_q75 = round(quantile(sigH, .75), 4),
    p_sigma_under_half = round(mean(sigH < sigT / 2), 3),
    p_sigma_over_2x = round(mean(sigH > 2 * sigT), 3),
    mean_abs_mu_err = round(mean(muErr), 4),
    boundary_rate = round(mean(bd), 3)
  ))
  cat("K =", K, "done\n")
}
print(out, row.names = FALSE)
write.csv(out, "/tmp/ec_smallK_sim.csv", row.names = FALSE)

# ---- real-data stability: bootstrap p_cal of the observed BB estimate ----
B <- 2000; pb <- rep(NA, B)
for (b in seq_len(B)) {
  idx <- sample.int(12, replace = TRUE)
  fh <- fit1(nc$logRr[idx], sePool[idx])
  z  <- abs(obsRR - fh[1]) / sqrt(seTar^2 + fh[2]^2)
  pb[b] <- 2 * (1 - pnorm(z))
}
cat("\n[Real BB p_cal bootstrap, K=12 resample]\n")
cat("median:", round(median(pb), 3),
    " q2.5:", round(quantile(pb, .025), 3),
    " q97.5:", round(quantile(pb, .975), 3),
    " P(p<0.05):", round(mean(pb < 0.05), 3),
    " P(p<0.20):", round(mean(pb < 0.20), 3), "\n")

# ---- real-data t-corrected p (plug-in fit + vmu inflation, df=K-2) ----
fh <- fit1(nc$logRr, sePool); mu <- fh[1]; sg <- fh[2]
vmu <- 1 / sum(1 / (sePool^2 + sg^2))
z0 <- abs(obsRR - mu) / sqrt(seTar^2 + sg^2)
zI <- abs(obsRR - mu) / sqrt(seTar^2 + sg^2 + vmu)
cat("\n[Real BB: plugin p =", sprintf("%.4f", 2 * (1 - pnorm(z0))),
    "| inflated p =", sprintf("%.4f", 2 * (1 - pnorm(zI))),
    "| t(K-2=10) p =", sprintf("%.4f", 2 * (1 - pt(zI, 10))), "]\n")
cat("[vmu =", sprintf("%.6f", vmu), " sd(mu_hat) =", sprintf("%.4f", sqrt(vmu)), "]\n")
