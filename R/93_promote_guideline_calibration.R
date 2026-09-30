# ============================================================================
# 93_promote_guideline_calibration.R
#
# 目的：把两个案例的「校准 P 值 + 校准 RR 及其 95% CI」一并换到
#       guideline 负对照口径，与 R/92 提升的 BAF 口径保持一致。
#
# 背景：DATA/bias_calibration_results.rds 里的 calibrated 条目是用
#       negative_controls_expanded.rds（K2 面板，A_W0 计入全部 β 受体阻滞剂，
#       暴露率 43.5%）拟合的经验原假设算出来的；而正文换口径后，BAF、校准 P、
#       校准 RR 都取自 guideline 面板（暴露率 12.1%）。若不重算，正文会出现
#       「校准 P 是新口径、校准 CI 是旧口径」的自相矛盾。
#
# 复刻对象：scripts/run_bias_calibration_Codex.R 的 calibrate_one()（逐行等价），
#           只把 null_fit 与校准项的输入换成指定面板。
#
# 自校验：
#   1. 用 K2 面板重算，必须逐位复现 DATA/bias_calibration_results.rds$calibrated
#      的 cal_p / cal_rr / cal_ci_lower / cal_ci_upper / bias_log_rr /
#      bias_fraction_pct；
#   2. 面板无关项（各估计的 logRr、seLogRr）两次运行必须相同。
#   任一项超差即 stop()。
#
# 输出（不覆盖已发表对象）：
#   output/data/bias_calibration_results_guideline.rds
# ============================================================================
suppressPackageStartupMessages({
  library(EmpiricalCalibration)
})

V40_DIR  <- "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/第40版"
DATA_DIR <- "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/DATA"
TAB_DIR  <- file.path(V40_DIR, "output", "tables")

## ---- 0. 已发表对象与两套负对照面板 ------------------------------------------
PUB <- readRDS(file.path(DATA_DIR, "bias_calibration_results.rds"))

nc_k2 <- PUB$negative_controls            # K2（全部 β 受体阻滞剂）
nc_gl <- readRDS(file.path(V40_DIR, "output", "data",
                           "negative_controls_expanded_guideline.rds"))$estimates

## 对齐顺序，确保是同一批 12 个结局
idx <- match(nc_k2$outcome, nc_gl$outcome)
stopifnot(!any(is.na(idx)), nrow(nc_k2) == length(idx))

panels <- list(
  published_k2    = list(logRr = nc_k2$logRr,   seLogRr = nc_k2$seLogRr),
  matched_to_main = list(logRr = nc_gl$logRr[idx], seLogRr = nc_gl$seLogRr[idx])
)

## ---- 1. 复刻 calibrate_one()（与 run_bias_calibration_Codex.R 逐行等价） -----
calibrate_one <- function(est, null_fit, nc_log_rr) {
  cal_p <- calibrateP(null = null_fit, logRr = est$logRr, seLogRr = est$seLogRr)

  mu_null    <- null_fit[1]
  sigma_null <- null_fit[2]
  cal_log_rr <- est$logRr - mu_null
  cal_se     <- sqrt(est$seLogRr^2 + sigma_null^2)
  cal_rr     <- exp(cal_log_rr)

  ## Conservative: use empirical SD of NC logRR instead of fitted null SD
  emp_sd     <- sd(nc_log_rr)
  cal_se_cons <- sqrt(est$seLogRr^2 + emp_sd^2)

  bias_log_rr    <- est$logRr - cal_log_rr
  bias_fraction  <- 100 * abs(bias_log_rr / est$logRr)

  list(
    cal_p             = cal_p,
    cal_rr            = cal_rr,
    cal_ci_lower      = exp(cal_log_rr - 1.96 * cal_se),
    cal_ci_upper      = exp(cal_log_rr + 1.96 * cal_se),
    cal_ci_lower_cons = exp(cal_log_rr - 1.96 * cal_se_cons),
    cal_ci_upper_cons = exp(cal_log_rr + 1.96 * cal_se_cons),
    bias_log_rr       = bias_log_rr,
    bias_rr           = exp(bias_log_rr),
    bias_fraction_pct = bias_fraction
  )
}

## 面板无关的估计端输入：照抄已发表 calibrated 条目里的 logRr / seLogRr
est_of <- function(r) list(logRr = r$logRr, seLogRr = r$seLogRr)

rebuild <- function(p) {
  null_fit <- fitNull(logRr = p$logRr, seLogRr = p$seLogRr)
  out <- list()
  for (nm in names(PUB$calibrated)) {
    r   <- PUB$calibrated[[nm]]
    cal <- calibrate_one(est_of(r), null_fit, p$logRr)
    out[[nm]] <- c(list(label = nm), est_of(r), cal)
  }
  list(null_fit = null_fit, calibrated = out)
}

## 校准项里除 label/logRr/seLogRr 之外还有 rr / rr_ci / p_value 等原样字段，
## 这些是面板无关量，直接沿用已发表条目。
carry <- function(newcal) {
  for (nm in names(newcal)) {
    keep <- setdiff(names(PUB$calibrated[[nm]]), names(newcal[[nm]]))
    for (k in keep) newcal[[nm]][[k]] <- PUB$calibrated[[nm]][[k]]
  }
  newcal
}

## ---- 2. 自校验 1：K2 面板逐位复现已发表 calibrated --------------------------
cat("[自校验1] K2 面板重算 vs DATA/bias_calibration_results.rds\n")
k2 <- rebuild(panels$published_k2)
worst <- 0
for (nm in names(PUB$calibrated)) {
  a <- PUB$calibrated[[nm]]; b <- k2$calibrated[[nm]]
  f <- c("cal_p", "cal_rr", "cal_ci_lower", "cal_ci_upper",
         "cal_ci_lower_cons", "cal_ci_upper_cons",
         "bias_log_rr", "bias_rr", "bias_fraction_pct")
  d <- vapply(f, function(k) abs(as.numeric(a[[k]]) - as.numeric(b[[k]])), numeric(1))
  names(d) <- f
  print(round(d, 12))
  worst <- max(worst, d)
}
if (worst > 1e-10) stop(sprintf("自校验1 失败：最大偏差 %.3e", worst))
## null_fit 也必须一并复现
chk_null <- abs(k2$null_fit - PUB$null_fit)
print(round(chk_null, 12))
if (max(chk_null) > 1e-10) stop("自校验1 失败：null_fit 未复现")
cat("自校验1 通过（含 null_fit）。\n\n")

## ---- 3. 生成新正式口径 --------------------------------------------------------
cat("[正式口径] matched_to_main（guideline 面板）\n")
gl  <- rebuild(panels$matched_to_main)
NEW <- PUB
NEW$negative_controls <- nc_gl[idx, ]
## v40 修正：nc_gl 的 rr / rr_ci_* / p_value 三组列原本停留在 K2 面板（R/92 早期版本
## 只覆盖 logRr/seLogRr），会让 eTable 6 的「Uncalibrated RR」列与新 logRr 不符。
## 这里按 LTMLE 的 log 尺度正态构造重算；K2 面板已验证该构造逐位成立
## （见脚本末尾的自校验 3）。
refit_nc_cols <- function(nc) {
  ## 乘数必须是 qnorm(0.975) = 1.959964，不是 1.96：已发表列的 z 值精确等于
  ## qnorm(0.975)（用 1.96 会差 ~5e-6，被下面的自校验 3 拦下）。
  z <- qnorm(0.975)
  nc$rr          <- exp(nc$logRr)
  nc$rr_ci_lower <- exp(nc$logRr - z * nc$seLogRr)
  nc$rr_ci_upper <- exp(nc$logRr + z * nc$seLogRr)
  nc$p_value     <- 2 * (1 - pnorm(abs(nc$logRr / nc$seLogRr)))
  nc
}
NEW$negative_controls <- refit_nc_cols(NEW$negative_controls)
## 自校验 3：同一构造作用在 K2 面板上必须逐位复现已发表列
.k2chk <- refit_nc_cols(nc_k2)
.d3 <- c(rr = max(abs(.k2chk$rr - nc_k2$rr)),
         lo = max(abs(.k2chk$rr_ci_lower - nc_k2$rr_ci_lower)),
         hi = max(abs(.k2chk$rr_ci_upper - nc_k2$rr_ci_upper)),
         p  = max(abs(.k2chk$p_value - nc_k2$p_value)))
print(round(.d3, 12))
if (max(.d3) > 1e-8) stop("自校验3 失败：负对照列重算构造与已发表列不符")
cat("自校验3 通过：负对照 rr / CI / p 的重算构造在 K2 面板逐位成立。\n\n")
NEW$calibrated        <- carry(gl$calibrated)
NEW$null_fit_guideline <- gl$null_fit
NEW$provenance <- list(
  promoted_from = "DATA/bias_calibration_results.rds",
  panel         = "negative_controls_expanded_guideline.rds",
  note          = "calibrated P / RR / CI recomputed with the guideline-matched empirical null",
  date          = as.character(Sys.Date())
)

## ---- 4. 自校验 2：面板无关项未变 ---------------------------------------------
for (nm in names(PUB$calibrated)) {
  stopifnot(abs(PUB$calibrated[[nm]]$logRr   - NEW$calibrated[[nm]]$logRr)   < 1e-12,
            abs(PUB$calibrated[[nm]]$seLogRr - NEW$calibrated[[nm]]$seLogRr) < 1e-12)
}
cat("自校验2 通过：估计端 logRr / seLogRr 未被误改。\n\n")

## ---- 5. 对照表 -----------------------------------------------------------------
cat(sprintf("%-38s %10s %10s %10s %10s\n", "Analysis", "CalRR", "CalLo", "CalHi", "CalP"))
for (nm in names(NEW$calibrated)) {
  a <- PUB$calibrated[[nm]]; b <- NEW$calibrated[[nm]]
  cat(sprintf("%-38s %s\n", nm, "（旧 -> 新）"))
  cat(sprintf("  %-36s %10.4f %10.4f %10.4f %10.4f\n", "published_k2", a$cal_rr, a$cal_ci_lower, a$cal_ci_upper, a$cal_p))
  cat(sprintf("  %-36s %10.4f %10.4f %10.4f %10.4f\n", "matched_to_main", b$cal_rr, b$cal_ci_lower, b$cal_ci_upper, b$cal_p))
}

saveRDS(NEW, file.path(V40_DIR, "output", "data",
                       "bias_calibration_results_guideline.rds"))
cat("\n已写出: output/data/bias_calibration_results_guideline.rds\n")
