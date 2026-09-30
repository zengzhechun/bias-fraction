# ============================================================================
# 94_negative_control_screening_audit.R
#
# 目的（审稿意见第 4 条）：把 12 个阴性对照的完整筛选流程做成可复算的审计表，
#   写清每一级的纳入 / 排除标准与剩余条数，以支撑「分析前预先选定、非事后挑选」
#   这一声明。
#
# 筛选链（四级）：
#   L0  初始候选清单：20 个"与 β 受体阻滞剂无合理因果通路"的结局病种
#   L1  代码可行性：4 个（fracture / burn / poisoning / inguinal hernia）在
#       MIMIC-IV diagnoses_icd 中 0 条 hadm_id —— 外部原因码与外科码未被该表
#       完整收录 —— 排除，余 16 个。此级记录于 config_negative_controls.R 头注，
#       本脚本按该文件的 16 个定义复算其后各级。
#   L2  事件量门槛（probe）：在心力衰竭队列中按 ICD-9/ICD-10 码统计曾出现过该
#       诊断的独立 subject_id 数（W0 索引住院 + W1 之后住院合计），要求 >= 50。
#       复算对象：scripts/probe_negative_controls_Codex.R
#   L3  分析窗门槛：在分析队列（宽限期存活者，Y_W0 == 0）中统计 W1 窗（宽限期
#       之后）发生该结局的人数，要求 >= 50。复算对象：
#       scripts/run_negative_controls_expanded_Codex.R 里的 NC_MIN_EVENTS 检查。
#       未过此级的两个结局在扩展估计中被跳过，故最终报告面板为 12 个。
#
# 输出：output/tables/v40_negative_control_screening.csv
# ============================================================================
suppressPackageStartupMessages({
  library(data.table)
  library(jsonlite)
})

BASE_DIR <- "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg"
WORK_DIR <- file.path(BASE_DIR, "Topic1_LTMLE_Betablocker")
DATA_DIR <- file.path(WORK_DIR, "DATA")
V40_DIR  <- file.path(WORK_DIR, "第40版")
TAB_DIR  <- file.path(V40_DIR, "output", "tables")
MIMIC_HOSP <- file.path(BASE_DIR, "mimic-iv-2.2/hosp")
NC_MIN_EVENTS <- 50L

source(file.path(WORK_DIR, "scripts", "config_negative_controls.R"))

# ---- 1. L2 probe：队列内曾出现该诊断的独立患者数 ---------------------------
diag <- fread(file.path(MIMIC_HOSP, "diagnoses_icd.csv"),
              select = c("subject_id", "hadm_id", "icd_code", "icd_version"))
diag[, icd_nodot := gsub("\\.", "", icd_code)]

hf_cohort  <- readRDS(file.path(DATA_DIR, "hf_cohort_processed.rds"))
hf_lookup  <- unique(hf_cohort[, .(subject_id, index_hadm_id = as.character(hosp_hadm_id))])
index_hadm_map <- setNames(hf_lookup$index_hadm_id, hf_lookup$subject_id)

diag_hf <- diag[subject_id %in% hf_cohort$subject_id]
diag_hf[, is_index_hosp := as.character(hadm_id) == index_hadm_map[as.character(subject_id)]]
diag_hf[is.na(is_index_hosp), is_index_hosp := FALSE]
diag_hf[, window := fifelse(is_index_hosp, "W0", "W1")]

for (nc_name in names(NC_CODES)) {
  nc <- NC_CODES[[nc_name]]
  all_codes <- unique(c(gsub("\\.", "", nc$icd10), gsub("\\.", "", nc$icd9)))
  diag_hf[, paste0("nc_", nc_name) := icd_nodot %chin% all_codes]
}

probe <- rbindlist(lapply(names(NC_CODES), function(nm) {
  col <- paste0("nc_", nm)
  # 列名不能叫 key：data.table(key = ...) 是设置索引键的参数，会与列名解析冲突
  data.table(
    nc_key    = nm,
    label     = NC_CODES[[nm]]$label,
    domain    = NC_CODES[[nm]]$domain,
    n_w0      = diag_hf[window == "W0" & get(col) == TRUE, length(unique(subject_id))],
    n_w1      = diag_hf[window == "W1" & get(col) == TRUE, length(unique(subject_id))]
  )
}))
probe[, n_patients_probe := n_w0 + n_w1]
probe[, pass_L2 := n_patients_probe >= NC_MIN_EVENTS]

# ---- 2. L3 分析窗事件数：宽限期存活者的 W1 计数 -----------------------------
lt <- as.data.table(readRDS(file.path(DATA_DIR, "ltmle_wide_K2.rds")))
valid_ids <- unique(lt[Y_W0 == 0, subject_id])
cat(sprintf("分析队列（Y_W0 == 0）：%d 人\n", length(valid_ids)))

for (nc_name in names(NC_CODES)) {
  col_name <- paste0("nc_", nc_name)
  n_pts <- diag_hf[window == "W1" & get(col_name) == TRUE &
                     subject_id %in% valid_ids, length(unique(subject_id))]
  probe[nc_key == nc_name, n_events_analytic := n_pts]
}
probe[, pass_L3 := n_events_analytic >= NC_MIN_EVENTS]

# ---- 3. 与已发表面板交叉校验 ------------------------------------------------
panel <- readRDS(file.path(DATA_DIR, "negative_controls_expanded.rds"))$estimates$outcome
probe[, in_reported_panel := nc_key %in% panel]
stopifnot(sum(probe$in_reported_panel) == 12L)
# 报告面板必须恰好等于「过 L2 且过 L3」的集合
stopifnot(identical(sort(probe[pass_L2 == TRUE & pass_L3 == TRUE, nc_key]),
                    sort(probe[in_reported_panel == TRUE, nc_key])))

# ---- 4. 汇总与落盘 ----------------------------------------------------------
probe[, status := fifelse(!pass_L2,
                          sprintf("excluded at L2 (<%d patients)", NC_MIN_EVENTS),
                          fifelse(!pass_L3,
                                  sprintf("excluded at L3 (<%d events in the analytic window)", NC_MIN_EVENTS),
                                  "retained in the reported panel"))]
setorder(probe, -in_reported_panel, -pass_L2, -n_patients_probe)
print(probe[, .(label, domain, n_patients_probe, pass_L2,
                n_events_analytic, pass_L3, in_reported_panel)], row.names = FALSE)

cat(sprintf("\nL1 -> L2: 16 个候选，%d 个过 probE 门槛\n", sum(probe$pass_L2)))
cat(sprintf("L2 -> L3: %d 个过 probe，%d 个过分析窗门槛\n", sum(probe$pass_L2), sum(probe$pass_L3)))
cat(sprintf("报告面板：%d 个\n", sum(probe$in_reported_panel)))
cat("L0 起点：20 个（config_negative_controls.R 头注记载的 4 个零事件排除项：",
    "fracture / burn / poisoning / inguinal_hernia）\n")

write.csv(probe, file.path(TAB_DIR, "v40_negative_control_screening.csv"),
          row.names = FALSE)
cat("\n已写出: output/tables/v40_negative_control_screening.csv\n")
