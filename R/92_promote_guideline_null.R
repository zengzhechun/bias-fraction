# ============================================================================
# 92_promote_guideline_null.R
#
# 目的：把「经验原假设用与主分析相同的暴露定义」提升为正式口径。
#
# 背景：已发表口径里，12 个负对照拟合在 DATA/ltmle_wide_K2.rds 上（A_W0 计入
#       全部 β 受体阻滞剂，43.5% 达 50% 目标剂量），而两个目标估计拟合在
#       DATA/ltmle_wide_K2_guideline.rds 上（A_W0 只计 carvedilol /
#       metoprolol succinate / bisoprolol，12.1% 达阈值）。OHDSI 经验校准
#       要求负对照与目标估计走同一处理对比，两侧口径不一致是设计缺陷。
#
#       本脚本沿用 manuscript_v35/analysis/run_bsr_analysis_v35.R 的原始配方
#       （逐行等价，只替换负对照面板），产出 guideline 面板下的完整结果对象。
#       案例端输入（grace / cal / sl / gp_sens）与面板无关，全部原样沿用。
#
# 自校验（三重）：
#   1. 诊断文件 arm_k2 的 12 个 logRr/seLogRr 必须与 DATA 里已发表负对照对象
#      逐位相同；
#   2. 用 arm_k2 跑同一配方，必须逐位复现已发表 bsr_results_v35.rds 的全部字段
#      （bb/gdmt 的 bsr、boot、class，以及 sl、loo、diagnostics、
#      grace_period_sensitivity）；
#   3. 面板无关项（sl 的 rr、gp 的 uncal_rr）两次运行必须相同。
#   任一项超差即 stop()。
#
# 输出（不覆盖已发表对象）：
#   output/data/bsr_results_v35_guideline.rds
#   output/data/negative_controls_expanded_guideline.rds
#   output/tables/v40_guideline_null_promotion.csv   （口径对照表）
#
# 注意：已发表的 grace_period_sensitivity 是 4 行（gp = 3/5/7/10），而当前
#       output/data/grace_period_sensitivity.rds 有 5 个键（多出 gp = 14）。
#       为让本次改动可归因于「换面板」这一件事，此处按已发表对象的
#       grace_period 取值取子集，不用 gp = 14。
# ============================================================================
suppressPackageStartupMessages({
  library(jsonlite)
  library(data.table)
  library(EmpiricalCalibration)
})

V40_DIR <- "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/第40版"
DATA_DIR <- "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/DATA"
setwd(V40_DIR)
source("R/00_config.R")
source("R/01_bsr_core.R")

TAB_DIR <- file.path(V40_DIR, "output", "tables")
OUT_DIR <- file.path(V40_DIR, "output")

# ---- 1. 已发表的负对照对象（提供 outcome 代码与标签的对照） ------------------
NC_OBJ <- readRDS(file.path(DATA_DIR, "negative_controls_expanded.rds"))
lab2out <- setNames(NC_OBJ$estimates$outcome, NC_OBJ$estimates$label)

# ---- 2. 诊断文件里的两套负对照面板 ------------------------------------------
diag <- jsonlite::fromJSON(file.path(TAB_DIR, "diag_nc_exposure_consistency.json"),
                           simplifyVector = FALSE)
panel <- function(arm) {
  est <- arm$estimates
  d <- data.frame(
    label   = vapply(est, function(x) x$label,   character(1)),
    logRr   = vapply(est, function(x) as.numeric(x$logRr),   numeric(1)),
    seLogRr = vapply(est, function(x) as.numeric(x$seLogRr), numeric(1)),
    stringsAsFactors = FALSE
  )
  d$outcome <- unname(lab2out[d$label])
  if (any(is.na(d$outcome))) {
    stop("有诊断标签在已发表负对照对象里找不到对应 outcome 代码：",
         paste(d$label[is.na(d$outcome)], collapse = " / "))
  }
  d
}
NC <- list(
  published_k2    = panel(diag$arm_k2),     # 已发表口径
  matched_to_main = panel(diag$arm_guide)   # 与主分析同暴露定义 —— 新正式口径
)
stopifnot(nrow(NC$published_k2) == 12L, nrow(NC$matched_to_main) == 12L)

# ---- 2b. 自校验 1：诊断的 K2 臂 == DATA 里已发表的负对照对象 ----------------
k2obj <- NC_OBJ$estimates[match(NC$published_k2$outcome, NC_OBJ$estimates$outcome), ]
d_log <- max(abs(k2obj$logRr   - NC$published_k2$logRr))
d_se  <- max(abs(k2obj$seLogRr - NC$published_k2$seLogRr))
cat(sprintf("[自校验1] 诊断 arm_k2 vs DATA 负对照对象：max|ΔlogRr| = %.3e，max|Δse| = %.3e\n",
            d_log, d_se))
if (max(d_log, d_se) > 1e-8) stop("自校验1 失败：诊断文件的 K2 臂与已发表负对照面板不一致")

# ---- 3. 与面板无关的案例端输入（照抄 run_bsr_analysis_v35.R） ---------------
grace   <- readRDS(file.path(DATA_DIR, "grace_period_guideline_results.rds"))
cal_res <- readRDS(file.path(DATA_DIR, "bias_calibration_results.rds"))
sl_cfg  <- readRDS(file.path(DATA_DIR, "sl_three_config.rds"))
gp_sens <- readRDS(file.path(OUT_DIR, "data", "grace_period_sensitivity.rds"))
PUB     <- readRDS(file.path(OUT_DIR, "data", "bsr_results_v35.rds"))

ex         <- grace$grace_period_exclusion
bb_log_rr  <- log(ex$rr)
bb_se      <- (log(ex$rr_ci[2]) - log(ex$rr_ci[1])) / (2 * 1.96)

gdm          <- cal_res$calibrated[["GDMT >=2/3 Classes (1-Year)"]]
gdmt_log_rr  <- log(gdm$rr)
gdmt_se      <- gdm$seLogRr

gp_days <- as.character(PUB$grace_period_sensitivity$grace_period)
stopifnot(all(gp_days %in% names(gp_sens)))
cat(sprintf("宽限期取子集：%s（文件另有 %s，本次不用，以保持改动可归因于换面板）\n",
            paste(gp_days, collapse = "/"),
            paste(setdiff(names(gp_sens), gp_days), collapse = "/")))

# ---- 4. 原始配方（逐行等价，面板作为参数） ----------------------------------
build_results <- function(nc) {
  nc_log_rr <- nc$logRr; names(nc_log_rr) <- nc$outcome
  nc_se     <- nc$seLogRr; names(nc_se)    <- nc$outcome

  bb_bsr  <- bsr_estimate(bb_log_rr, bb_se, nc_log_rr, nc_se)
  bb_boot <- bsr_bootstrap(bb_log_rr, bb_se, nc_log_rr, nc_se)
  bb_class <- bsr_classify(bb_bsr$bsr, bb_boot$ci_lo, bb_boot$ci_hi)
  bb_fieller <- tryCatch(
    bsr_fieller(bb_bsr$mu_bias, var(bb_boot$mu_draws, na.rm = TRUE), bb_log_rr, bb_se),
    error = function(e) NULL)

  gdmt_bsr  <- bsr_estimate(gdmt_log_rr, gdmt_se, nc_log_rr, nc_se)
  gdmt_boot <- bsr_bootstrap(gdmt_log_rr, gdmt_se, nc_log_rr, nc_se)
  gdmt_class <- bsr_classify(gdmt_bsr$bsr, gdmt_boot$ci_lo, gdmt_boot$ci_hi)
  gdmt_fieller <- tryCatch(
    bsr_fieller(gdmt_bsr$mu_bias, var(gdmt_boot$mu_draws, na.rm = TRUE), gdmt_log_rr, gdmt_se),
    error = function(e) NULL)

  bb_loo <- bsr_loo(bb_log_rr, bb_se, nc_log_rr, nc_se)

  sl_configs <- c("SL.glm", "SL.glm+SL.gam", "SL.glm+SL.gam+SL.xgboost")
  sl_rr    <- c(sl_cfg$glm_only$rr,        sl_cfg$glm_gam$rr,        sl_cfg$full$rr)
  sl_ci_lo <- c(sl_cfg$glm_only$rr_ci_lo,  sl_cfg$glm_gam$rr_ci_lo,  sl_cfg$full$rr_ci_lo)
  sl_ci_hi <- c(sl_cfg$glm_only$rr_ci_hi,  sl_cfg$glm_gam$rr_ci_hi,  sl_cfg$full$rr_ci_hi)
  sl_bsr_vals <- numeric(3); sl_bf_vals <- numeric(3)
  sl_bf_ci <- matrix(NA_real_, nrow = 3, ncol = 2)
  for (i in seq_along(sl_configs)) {
    sl_log_rr <- log(sl_rr[i])
    sl_se <- (log(sl_ci_hi[i]) - log(sl_ci_lo[i])) / (2 * 1.96)
    res  <- bsr_estimate(sl_log_rr, sl_se, nc_log_rr, nc_se)
    boot <- bsr_bootstrap(sl_log_rr, sl_se, nc_log_rr, nc_se)
    sl_bsr_vals[i] <- res$bsr
    sl_bf_vals[i]  <- boot$bf_median
    sl_bf_ci[i, ]  <- c(boot$bf_ci_lo, boot$bf_ci_hi)
  }

  diag_out <- bsr_diagnostics(nc_log_rr, nc_se)

  gp_results <- data.frame(
    grace_period = integer(), n_cohort = integer(),
    uncal_rr = numeric(), cal_rr = numeric(),
    bsr = numeric(), bf = numeric(), class = character(),
    stringsAsFactors = FALSE)
  for (gp_day in gp_days) {
    rr_uncal <- gp_sens[[gp_day]]$rr
    res <- bsr_estimate(log(rr_uncal), bb_se, nc_log_rr, nc_se)
    gp_results <- rbind(gp_results, data.frame(
      grace_period = as.integer(gp_day),
      n_cohort = gp_sens[[gp_day]]$n_survivors,
      uncal_rr = round(rr_uncal, 4),
      cal_rr   = round(res$rr_true, 4),
      bsr      = round(res$bsr, 2),
      bf       = round(res$bf, 4),
      class    = bsr_classify(res$bsr, NA, NA),
      stringsAsFactors = FALSE))
  }

  list(
    bb   = list(bsr = bb_bsr,   boot = bb_boot,   class = bb_class,   fieller = bb_fieller),
    gdmt = list(bsr = gdmt_bsr, boot = gdmt_boot, class = gdmt_class, fieller = gdmt_fieller),
    loo  = bb_loo,
    sl   = data.frame(config = sl_configs, rr = sl_rr,
                      rr_ci_lo = sl_ci_lo, rr_ci_hi = sl_ci_hi,
                      bsr = sl_bsr_vals, bf = sl_bf_vals,
                      bf_ci_lo = sl_bf_ci[, 1], bf_ci_hi = sl_bf_ci[, 2],
                      stringsAsFactors = FALSE),
    diagnostics = diag_out,
    grace_period_sensitivity = gp_results,
    timestamp = Sys.time()
  )
}

# ---- 5. 自校验 2：K2 面板必须逐位复现已发表对象 ------------------------------
TOL <- 1e-8
k2  <- build_results(NC$published_k2)
cat("\n[自校验2] published_k2 vs output/data/bsr_results_v35.rds\n")
worst <- 0
for (cn in c("bb", "gdmt")) {
  chk <- c(
    mu_bias     = k2[[cn]]$bsr$mu_bias     - PUB[[cn]]$bsr$mu_bias,
    sigma_bias  = k2[[cn]]$bsr$sigma_bias  - PUB[[cn]]$bsr$sigma_bias,
    log_rr_true = k2[[cn]]$bsr$log_rr_true - PUB[[cn]]$bsr$log_rr_true,
    cal_p       = k2[[cn]]$bsr$cal_p       - PUB[[cn]]$bsr$cal_p,
    bf_plugin   = k2[[cn]]$bsr$bf          - PUB[[cn]]$bsr$bf,
    bf_median   = k2[[cn]]$boot$bf_median  - PUB[[cn]]$boot$bf_median,
    bf_ci_lo    = k2[[cn]]$boot$bf_ci_lo   - PUB[[cn]]$boot$bf_ci_lo,
    bf_ci_hi    = k2[[cn]]$boot$bf_ci_hi   - PUB[[cn]]$boot$bf_ci_hi,
    class_diff  = as.numeric(k2[[cn]]$class != PUB[[cn]]$class))
  print(round(chk, 12))
  worst <- max(worst, abs(chk))
  if (any(abs(chk) > TOL)) stop(sprintf("自校验2 失败：%s 最大偏差 %.3e", cn, max(abs(chk))))
}
chk_sl <- c(bf = max(abs(k2$sl$bf - PUB$sl$bf)),
            bf_ci_lo = max(abs(k2$sl$bf_ci_lo - PUB$sl$bf_ci_lo)),
            bf_ci_hi = max(abs(k2$sl$bf_ci_hi - PUB$sl$bf_ci_hi)),
            bsr = max(abs(k2$sl$bsr - PUB$sl$bsr)))
chk_loo <- c(bf = max(abs(k2$loo$bf - PUB$loo$bf)),
             bsr = max(abs(k2$loo$bsr - PUB$loo$bsr)))
chk_gp  <- c(cal_rr = max(abs(k2$grace_period_sensitivity$cal_rr - PUB$grace_period_sensitivity$cal_rr)),
             bf     = max(abs(k2$grace_period_sensitivity$bf     - PUB$grace_period_sensitivity$bf)))
chk_diag <- c(mu = abs(k2$diagnostics$mu - PUB$diagnostics$mu),
              sigma = abs(k2$diagnostics$sigma - PUB$diagnostics$sigma),
              shapiro_p = abs(k2$diagnostics$shapiro_p - PUB$diagnostics$shapiro_p))
cat(sprintf("sl   最大偏差: %s\n", paste(sprintf("%s=%.3e", names(chk_sl), chk_sl), collapse="  ")))
cat(sprintf("loo  最大偏差: %s\n", paste(sprintf("%s=%.3e", names(chk_loo), chk_loo), collapse="  ")))
cat(sprintf("gp   最大偏差: %s\n", paste(sprintf("%s=%.3e", names(chk_gp), chk_gp), collapse="  ")))
cat(sprintf("diag 最大偏差: %s\n", paste(sprintf("%s=%.3e", names(chk_diag), chk_diag), collapse="  ")))
worst <- max(worst, chk_sl, chk_loo, chk_gp, chk_diag)
if (worst > TOL) stop("自校验2 失败：面板无关项未复现")
cat("自校验2 通过：K2 面板全字段逐位复现已发表对象。\n")

# ---- 6. 生成新正式口径 --------------------------------------------------------
cat("\n[正式口径] matched_to_main（guideline 队列，暴露率 12.1%）\n")
new <- build_results(NC$matched_to_main)

# ---- 6b. 自校验 3：两次运行的面板无关项必须相同 ------------------------------
stopifnot(max(abs(new$sl$rr - PUB$sl$rr)) < TOL,
          max(abs(new$grace_period_sensitivity$uncal_rr -
                  PUB$grace_period_sensitivity$uncal_rr)) < TOL)
cat("自校验3 通过：SL 的 rr 与宽限期的 uncal_rr 两次运行一致（面板无关项未被误改）。\n")

# ---- 7. 口径对照表 -----------------------------------------------------------
row <- function(tag, o) data.frame(
  case = tag,
  mu_bias = o$bsr$mu_bias, sigma_bias = o$bsr$sigma_bias,
  rr_uncal = o$bsr$rr_uncal, rr_cal = o$bsr$rr_true,
  log_rr_cal = o$bsr$log_rr_true, cal_p = o$bsr$cal_p,
  layer1_pass = o$bsr$cal_p < 0.05, bf_plugin = o$bsr$bf,
  baf = o$boot$bf_median, baf_lo = o$boot$bf_ci_lo, baf_hi = o$boot$bf_ci_hi,
  half_width = (o$boot$bf_ci_hi - o$boot$bf_ci_lo) / 2, zone_class = o$class,
  stringsAsFactors = FALSE)
CMP <- rbind(cbind(panel = "published_k2",    row("bb",   PUB$bb)),
             cbind(panel = "matched_to_main", row("bb",   new$bb)),
             cbind(panel = "published_k2",    row("gdmt", PUB$gdmt)),
             cbind(panel = "matched_to_main", row("gdmt", new$gdmt)))
cat("\n")
print(CMP, row.names = FALSE, digits = 4)
write.csv(CMP, file.path(TAB_DIR, "v40_guideline_null_promotion.csv"), row.names = FALSE)

cat(sprintf("\nBB  LOO BAF 范围: %.3f - %.3f（原 %.3f - %.3f）\n",
            min(new$loo$bf), max(new$loo$bf), min(PUB$loo$bf), max(PUB$loo$bf)))
cat(sprintf("BB  LOO bsr 范围: %.3f - %.3f（原 %.3f - %.3f）\n",
            min(new$loo$bsr), max(new$loo$bsr), min(PUB$loo$bsr), max(PUB$loo$bsr)))
cat(sprintf("SL  bf: %s（原 %s）\n",
            paste(sprintf("%.3f", new$sl$bf), collapse=", "),
            paste(sprintf("%.3f", PUB$sl$bf), collapse=", ")))
cat(sprintf("GP  bf: %s（原 %s）\n",
            paste(sprintf("%.3f", new$grace_period_sensitivity$bf), collapse=", "),
            paste(sprintf("%.3f", PUB$grace_period_sensitivity$bf), collapse=", ")))
cat(sprintf("NC  logRR 范围: [%.3f, %.3f]；全部保护性 = %s（原 TRUE）\n",
            min(NC$matched_to_main$logRr), max(NC$matched_to_main$logRr),
            all(NC$matched_to_main$logRr < 0)))
cat(sprintf("NC  Shapiro p = %.4f（原 %.4f）\n",
            new$diagnostics$shapiro_p, PUB$diagnostics$shapiro_p))

# ---- 8. 写盘 -----------------------------------------------------------------
saveRDS(new, file.path(OUT_DIR, "data", "bsr_results_v35_guideline.rds"))
idx <- match(NC_OBJ$estimates$outcome, NC$matched_to_main$outcome)
stopifnot(!any(is.na(idx)))
nc_obj_new <- NC_OBJ
nc_obj_new$estimates$logRr   <- NC$matched_to_main$logRr[idx]
nc_obj_new$estimates$seLogRr <- NC$matched_to_main$seLogRr[idx]
# v40 修正：只换 logRr/seLogRr 会让同一行的 rr / rr_ci_* / p_value 停留在旧面板，
# 下游若读这些列就会拿到与新 logRr 不符的数（exp(logRr) != rr）。LTMLE 的 RR 区间
# 与 p 值都是 log 尺度上的正态构造（已在 K2 面板逐位验证：rr = exp(logRr)，
# CI = exp(logRr ± qnorm(0.975)·seLogRr)，p = 2(1−Φ(|logRr|/seLogRr))），此处按同一构造重算。
.z <- qnorm(0.975)
nc_obj_new$estimates$rr          <- exp(NC$matched_to_main$logRr[idx])
nc_obj_new$estimates$rr_ci_lower <- exp(NC$matched_to_main$logRr[idx] -
                                          .z * NC$matched_to_main$seLogRr[idx])
nc_obj_new$estimates$rr_ci_upper <- exp(NC$matched_to_main$logRr[idx] +
                                          .z * NC$matched_to_main$seLogRr[idx])
nc_obj_new$estimates$p_value     <- 2 * (1 - pnorm(abs(NC$matched_to_main$logRr[idx] /
                                                         NC$matched_to_main$seLogRr[idx])))
stopifnot(max(abs(exp(nc_obj_new$estimates$logRr) - nc_obj_new$estimates$rr)) < 1e-12)
saveRDS(nc_obj_new, file.path(OUT_DIR, "data", "negative_controls_expanded_guideline.rds"))
cat("\n已写出:\n  output/data/bsr_results_v35_guideline.rds\n",
    " output/data/negative_controls_expanded_guideline.rds\n",
    " output/tables/v40_guideline_null_promotion.csv\n", sep="")
