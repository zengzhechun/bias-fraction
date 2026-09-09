# 从 baseline_smd_results 抽取 12 个临床相关变量，生成 JAMA 风格的 Table 1
# A+ (2026-09-04): 增加"调整后 SMD (stabilized IPTW)"列，倾向模型含全部 16 个
# Table 3 基线变量 (见 R/25_adjusted_smd_iptw.R)，用于体现加权后基线可比性。
suppressMessages({ library(tableone); library(dplyr) })

bs <- readRDS("/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/DATA/baseline_smd_results.rds")
t1 <- bs$table1

# 调整后 SMD (optA: 全部16变量 stabilized IPTW)，键名 = 原始变量名
adj_iptw <- readRDS(file.path("output", "tables", "adjusted_smd_iptw.rds"))$adjA

map <- list(
  "age"             = c("Age, mean (SD), y", "cont"),
  "gender"          = c("Female, n (%)", "F"),
  "L_hr_W0"         = c("Heart rate, mean (SD), bpm", "cont"),
  "L_qrs_W0"        = c("QRS duration, mean (SD), ms", "cont"),
  "L_qtc_W0"        = c("QTc interval, mean (SD), ms", "cont"),
  "L_cr_W0"         = c("Creatinine, mean (SD), mg/dL", "cont"),
  "L_egfr_W0"       = c("eGFR, mean (SD), mL/min/1.73m^2", "cont"),
  "L_hb_W0"         = c("Hemoglobin, mean (SD), g/dL", "cont"),
  "L_na_W0"         = c("Sodium, mean (SD), mEq/L", "cont"),
  "L_k_W0"          = c("Potassium, mean (SD), mEq/L", "cont"),
  "L_af_W0"         = c("Atrial fibrillation, n (%)", "Yes"),
  "L_lbbb_W0"       = c("Left bundle branch block, n (%)", "Yes"),
  "qtc_prolonged"   = c("Prolonged QTc, n (%)", "Yes"),
  "qrs_ge120"       = c("Wide QRS (>=120 ms), n (%)", "Yes"),
  "egfr_lt60"       = c("eGFR <60 mL/min/1.73m^2, n (%)", "Yes"),
  "age_ge75"        = c("Age >=75 y, n (%)", "Yes")
)

ovr    <- t1$ContTable$Overall
cat_ovr <- t1$CatTable$Overall
trt_o  <- t1$ContTable$`>=50% Guideline BB`
trl_o  <- t1$ContTable$`<50% Guideline BB`
trt_c  <- t1$CatTable$`>=50% Guideline BB`
trl_c  <- t1$CatTable$`<50% Guideline BB`

# smd_values 的名称形如 "age (mean (SD))" / "gender (%)"
smd_key <- c(
  age = "age (mean (SD))",
  L_hr_W0 = "L_hr_W0 (mean (SD))",
  L_qrs_W0 = "L_qrs_W0 (mean (SD))",
  L_qtc_W0 = "L_qtc_W0 (mean (SD))",
  L_cr_W0 = "L_cr_W0 (mean (SD))",
  L_egfr_W0 = "L_egfr_W0 (mean (SD))",
  L_hb_W0 = "L_hb_W0 (mean (SD))",
  L_na_W0 = "L_na_W0 (mean (SD))",
  L_k_W0 = "L_k_W0 (mean (SD))",
  gender = "gender (%)",
  L_af_W0 = "L_af_W0 (%)",
  L_lbbb_W0 = "L_lbbb_W0 (%)",
  qtc_prolonged = "qtc_prolonged (%)",
  qrs_ge120 = "qrs_ge120 (%)",
  egfr_lt60 = "egfr_lt60 (%)",
  age_ge75 = "age_ge75 (%)"
)

get_cat <- function(cat_list, var, level){
  df <- cat_list[[var]]
  idx <- which(df$level == level)
  if(length(idx)==0) return(c(freq=NA, pct=NA))
  c(freq=as.integer(df$freq[idx]), pct=as.numeric(df$percent[idx]))
}

build_row <- function(var, label, kind){
  if(kind=="cont"){
    overall <- sprintf("%.1f (%.1f)", ovr[var,"mean"], ovr[var,"sd"])
    trt     <- sprintf("%.1f (%.1f)", trt_o[var,"mean"], trt_o[var,"sd"])
    trl     <- sprintf("%.1f (%.1f)", trl_o[var,"mean"], trl_o[var,"sd"])
  } else {
    lvl <- map[[var]][2]
    o <- get_cat(cat_ovr, var, lvl)
    t <- get_cat(trt_c, var, lvl)
    l <- get_cat(trl_c, var, lvl)
    overall <- sprintf("%d (%.1f)", o["freq"], o["pct"])
    trt     <- sprintf("%d (%.1f)", t["freq"], t["pct"])
    trl     <- sprintf("%d (%.1f)", l["freq"], l["pct"])
  }
  sk <- smd_key[[var]]
  smd <- bs$smd_values[sk]
  smd_str <- if(is.na(smd)) "" else sprintf("%.3f", smd)
  adj <- adj_iptw[[var]]
  adj_str <- if(is.na(adj)) "" else sprintf("%.3f", adj)
  c(Variable=label, Overall=overall, `Achieved >=50%`=trt,
    `Did not achieve 50%`=trl, SMD=smd_str, `SMD (IPTW)`=adj_str)
}

rows  <- lapply(names(map), function(v) build_row(v, map[[v]][1], map[[v]][2]))
n_row <- c(Variable="N", Overall=as.character(bs$n_total),
           `Achieved >=50%`=as.character(bs$n_treat),
           `Did not achieve 50%`=as.character(bs$n_control), SMD="", `SMD (IPTW)`="")
mat  <- do.call(rbind, c(list(n_row), rows))
out  <- as.data.frame(mat, stringsAsFactors=FALSE)
rownames(out) <- NULL

out_dir <- file.path("output", "tables")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
saveRDS(out, file.path(out_dir, "baseline_table1.rds"))
write.csv(out, file.path(out_dir, "baseline_table1.csv"), row.names = FALSE)
cat("WROTE:", file.path(out_dir, "baseline_table1.csv"), "\n\n")
print(out, right = FALSE)
