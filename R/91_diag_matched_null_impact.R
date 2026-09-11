# ============================================================================
# 91_diag_matched_null_impact.R  —  只读诊断脚本
#
# 目的：量化「把经验原假设改用与主分析一致的暴露定义」对两个临床案例的
#       BAF、可信区间、校准 P 值、以及最终判定的影响。
#
# 背景：R/90_diag_nc_exposure_consistency.R 已经证明
#         · 12 个负对照拟合在 ltmle_wide_K2.rds 上（A_W0 计入全部 β 受体阻滞剂，
#           43.0% 达 50% 目标剂量）
#         · 主分析拟合在 ltmle_wide_K2_guideline.rds 上（A_W0 只计入
#           carvedilol / metoprolol succinate / bisoprolol，11.8% 达阈值）
#       本脚本把 90 号脚本算出的两套负对照估计（logRR 与 SE）分别喂给
#       01_bsr_core.R 的同一套函数，复现已发表数字并给出配平后的数字。
#       案例端的输入取自已发表管线本身：
#         · BB  ：grace_period_guideline_results.rds$grace_period_exclusion
#         · GDMT：bias_calibration_results.rds$calibrated[["GDMT >=2/3 Classes (1-Year)"]]
#       与 manuscript_v35/analysis/run_bsr_analysis_v35.R 第 31-36、61-66 行一致。
#
# 自校验：K2 那一路必须逐位复现 output/data/bsr_results_v35.rds 里的
#         bb$bsr / gdmt$bsr（mu_bias、sigma_bias、log_rr_true、cal_p、bf）
#         以及 bb$boot / gdmt$boot 的 BAF 中位数。任何一项对不上就 stop()。
#
# 本脚本不修改任何既有数据或稿件，只写
#   output/tables/diag_matched_null_impact.{json,csv}
# ============================================================================
suppressPackageStartupMessages({
  library(jsonlite)
  library(EmpiricalCalibration)
})

V39_DIR <- "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/第39版"
DATA_DIR <- "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/DATA"
setwd(V39_DIR)
source("R/01_bsr_core.R")

TAB_DIR <- file.path(V39_DIR, "output", "tables")
OUT_DIR <- file.path(V39_DIR, "output")
N_BOOT  <- 2000L
SEED    <- 42L

# ---- 1. 复现判定所需的两张表：查找表分箱与判定阈值 ---------------------------
NUM <- jsonlite::fromJSON(file.path(TAB_DIR, "v39_all_numbers.json"),
                          simplifyVector = FALSE)
LOOK     <- read.csv(file.path(TAB_DIR, "v39_part2_reliability_lookup.csv"))
brk      <- c(LOOK$bf_lo[1], LOOK$bf_hi)
med_half <- as.numeric(NUM$part2$ci_width$median_half_width)
VERDICT_BREAKS <- c(0.15, 0.45, 0.65)
verdict_of <- function(p) {
  ifelse(is.na(p), "insufficient evidence",
  ifelse(p <  VERDICT_BREAKS[1], "usable as effect evidence",
  ifelse(p <  VERDICT_BREAKS[2], "mixed, hypothesis-generating",
  ifelse(p <  VERDICT_BREAKS[3], "competitive, no verdict",
                                 "not usable as effect evidence"))))
}
cat(sprintf("查找表分箱数 %d，中位半宽 %.6f，判定阈值 %s\n",
            nrow(LOOK), med_half, paste(VERDICT_BREAKS, collapse = "/")))

# ---- 2. 两套负对照面板 -------------------------------------------------------
diag <- jsonlite::fromJSON(file.path(TAB_DIR, "diag_nc_exposure_consistency.json"),
                          simplifyVector = FALSE)
panel <- function(arm) {
  est <- arm$estimates
  data.frame(
    label   = vapply(est, function(x) x$label,   character(1)),
    logRr   = vapply(est, function(x) as.numeric(x$logRr),   numeric(1)),
    seLogRr = vapply(est, function(x) as.numeric(x$seLogRr), numeric(1)),
    stringsAsFactors = FALSE
  )
}
panels <- list(
  matched_to_main = panel(diag$arm_guide),  # 与主分析同暴露定义
  published_k2    = panel(diag$arm_k2)      # 已发表所用的面板
)
for (nm in names(panels)) {
  cat(sprintf("面板 %-15s K = %2d，logRR 范围 [%.3f, %.3f]\n",
              nm, nrow(panels[[nm]]),
              min(panels[[nm]]$logRr), max(panels[[nm]]$logRr)))
}
stopifnot(nrow(panels$matched_to_main) == 12L,
          nrow(panels$published_k2)    == 12L)

# ---- 3. 两个案例的（与面板无关的）估计量与 SE，取自已发表管线 ----------------
grace   <- readRDS(file.path(DATA_DIR, "grace_period_guideline_results.rds"))
cal_res <- readRDS(file.path(DATA_DIR, "bias_calibration_results.rds"))

ex          <- grace$grace_period_exclusion
bb_log_rr   <- log(ex$rr)
bb_se       <- (log(ex$rr_ci[2]) - log(ex$rr_ci[1])) / (2 * 1.96)

gdm         <- cal_res$calibrated[["GDMT >=2/3 Classes (1-Year)"]]
gdmt_log_rr <- log(gdm$rr)
gdmt_se     <- gdm$seLogRr

case_input <- list(
  bb   = list(label = "Beta-blocker >=50% target dose", logRr = bb_log_rr,   seLogRr = bb_se),
  gdmt = list(label = "GDMT >=2 of 3 classes",          logRr = gdmt_log_rr, seLogRr = gdmt_se)
)
cat(sprintf("\n案例端输入：BB logRR = %.6f (se %.6f)；GDMT logRR = %.6f (se %.6f)\n",
            bb_log_rr, bb_se, gdmt_log_rr, gdmt_se))

# ---- 4. 逐个案例 × 逐套面板：点估计、区间、分箱、判定 -------------------------
run_case <- function(cs, pn) {
  est  <- bsr_estimate(cs$logRr, cs$seLogRr, pn$logRr, pn$seLogRr)
  boot <- bsr_bootstrap(cs$logRr, cs$seLogRr, pn$logRr, pn$seLogRr,
                        n_boot = N_BOOT, seed = SEED)
  bf   <- boot$bf_median
  half <- (boot$bf_ci_hi - boot$bf_ci_lo) / 2
  bin  <- max(which(brk[-length(brk)] <= bf))
  pbd  <- LOOK$p_bd_conservative[bin]
  list(
    mu_bias = unname(est$mu_bias), sigma_bias = unname(est$sigma_bias),
    log_rr_true = unname(est$log_rr_true), rr_true = unname(est$rr_true),
    cal_p = unname(est$cal_p), baf_plugin = unname(est$bf),
    baf = unname(bf), baf_lo = unname(boot$bf_ci_lo), baf_hi = unname(boot$bf_ci_hi),
    half_width = half, ci_class = if (half <= med_half) "narrow" else "wide",
    lookup_bin = bin, p_bias_dominated = pbd,
    verdict = unname(verdict_of(pbd)),
    layer1_pass = unname(est$cal_p) < 0.05,
    boot_fail = boot$n_fail
  )
}

rows <- list()
for (cn in names(case_input)) {
  for (pn in names(panels)) {
    r <- run_case(case_input[[cn]], panels[[pn]])
    rows[[length(rows) + 1]] <- data.frame(
      case = cn, panel = pn, n_nc = nrow(panels[[pn]]),
      mu_bias = r$mu_bias, sigma_bias = r$sigma_bias,
      rr_uncal = exp(case_input[[cn]]$logRr), rr_cal = r$rr_true,
      cal_p = r$cal_p, layer1_pass = r$layer1_pass,
      baf_plugin = r$baf_plugin, baf = r$baf, baf_lo = r$baf_lo, baf_hi = r$baf_hi,
      half_width = r$half_width, ci_class = r$ci_class,
      lookup_bin = r$lookup_bin, p_bias_dominated = r$p_bias_dominated,
      verdict = r$verdict, boot_fail = r$boot_fail,
      stringsAsFactors = FALSE
    )
  }
}
OUT <- do.call(rbind, rows)

# ---- 5. 自校验：K2 面板必须复现已发表数字 ------------------------------------
tol <- 1e-8
pub <- readRDS(file.path(OUT_DIR, "data", "bsr_results_v35.rds"))
for (cn in c("bb", "gdmt")) {
  a <- OUT[OUT$case == cn & OUT$panel == "published_k2", ]
  p <- pub[[cn]]
  chk <- c(mu_bias     = a$mu_bias      - p$bsr$mu_bias,
           sigma_bias  = a$sigma_bias   - p$bsr$sigma_bias,
           log_rr_true = log(a$rr_cal)  - p$bsr$log_rr_true,
           cal_p       = a$cal_p        - p$bsr$cal_p,
           baf_plugin  = a$baf_plugin   - p$bsr$bf)
  cat(sprintf("\n[自校验] %s 的 K2 面板 vs 已发表 bsr_results_v35.rds\n", cn))
  print(round(chk, 12))
  if (any(abs(chk) > tol)) {
    stop(sprintf("自校验失败：%s 最大偏差 %.3e", cn, max(abs(chk))))
  }
  cat(sprintf("  bootstrap BAF 中位差 = %.3e；CI 差 = [%.3e, %.3e]；失败重抽样 %d\n",
              a$baf - p$boot$bf_median,
              a$baf_lo - p$boot$bf_ci_lo,
              a$baf_hi - p$boot$bf_ci_hi,
              a$boot_fail))
  if (abs(a$baf - p$boot$bf_median) > 1e-8) stop("自校验失败：bootstrap BAF 中位未复现")
}
cat("\n自校验通过：published_k2 面板逐位复现已发表结果。\n")

# ---- 6. 输出 -----------------------------------------------------------------
num_cols <- c("mu_bias", "sigma_bias", "rr_uncal", "rr_cal", "cal_p",
              "baf_plugin", "baf", "baf_lo", "baf_hi", "half_width",
              "p_bias_dominated")
OUT[num_cols] <- lapply(OUT[num_cols], function(x) round(as.numeric(x), 6))
cat("\n")
print(OUT[, c("case", "panel", "mu_bias", "sigma_bias", "rr_cal", "cal_p",
              "layer1_pass", "baf", "baf_lo", "baf_hi", "lookup_bin",
              "p_bias_dominated", "verdict")], row.names = FALSE)

write.csv(OUT, file.path(TAB_DIR, "diag_matched_null_impact.csv"), row.names = FALSE)
jsonlite::write_json(
  list(
    generated = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    question  = paste("What changes in the two case-study determinations if the",
                      "empirical null is refitted on a negative-control panel",
                      "using the same exposure definition as the main analysis?"),
    self_check = "published_k2 reproduces bsr_results_v35.rds bit-for-bit",
    n_boot = N_BOOT, seed = SEED,
    rows = OUT
  ),
  file.path(TAB_DIR, "diag_matched_null_impact.json"),
  pretty = TRUE, auto_unbox = TRUE, digits = 8
)
cat("\n已写出 output/tables/diag_matched_null_impact.{csv,json}\n")
