# 第39版目录说明

> Quantifying Systematic Bias in Observational Causal Estimates Using Negative Controls: The Bias Attribution Fraction
>
> 最后更新：2026-09-09　|　文件总数 289 个　|　总体积 161.3 MB

---

## 一、这个目录里有什么

三件事：**方法学论文的三条投稿轨道**（JAMA Network Open、medRxiv/MedArchive、完整长稿）、**产生全部数字的 R 分析管线**、**配套的交互式讲解器**。

核心指标是 **BAF（Bias Attribution Fraction，偏倚分数）**：

```
BAF = |μ̂_B| / (|μ̂_B| + |ψ̃|)
```

μ̂_B 是负对照经验零分布的中心，ψ̃ 是校准后的对数相对风险。BAF 落在 [0, 1]，0 表示校准后的效应完全由真实效应构成，1 表示完全由系统偏倚构成。分区：偏倚主导 BAF > 0.5，混合区 1/3 到 0.5，效应主导 BAF < 1/3。

研究分三部分串联：第一部分定义指标并构造可信区间；第二部分在 960 个条件 × 1000 次重复 = 960,000 次蒙特卡洛重复中评估指标；第三部分把指标用到 MIMIC-IV 的两个 β 受体阻滞剂目标试验仿真问题上。

---

## 二、开工前必须知道的四条铁律

### 1. 数字的唯一信源是 `output/tables/v39_all_numbers.json`

全稿每一个数字都从这个 JSON 动态取值，qmd 里不写死数字。要改数字，改 JSON 或改产生它的 R 脚本，**不要在 qmd 里手改**。心算四舍五入一律禁止，用 `sprintf("%.1f", )` 这类函数。

### 2. qmd 是信源，docx 是渲染产物

直接编辑 docx 会被下一次渲染覆盖。人机双写、改稿一律在 qmd 上做。确实要改 docx 底层（例如放大图片）用 python-docx 的 `doc.save()`，这是安全的。

### 3. 渲染三原则

```bash
# 1) 显式 --to docx
# 2) 原地渲染，不要用 --output-dir
# 3) 渲染后按顺序跑后处理脚本（JAMA 轨道）
quarto render manuscript_jama_v39.qmd --to docx
python3 _post_format_jama.py
python3 _post_bold_abstract.py
python3 _post_landscape_jama.py     # 仅投稿版需要
```

判据是「文件 mtime 更新 + 锚点齐全」，**退出码不可信**（quarto 出错也可能返回 0）。

macOS 上渲染中文路径需要显式设置 locale，否则 R 的 `setwd()` 会报 `unable to translate ... to native encoding`：

```bash
export PATH="/Library/Frameworks/R.framework/Resources/bin:/Applications/quarto/bin:$PATH"
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 LC_CTYPE=en_US.UTF-8
```

qmd 里有 `source("../R/00_config.R")`，所以 **qmd 必须放在「第39版」的直接子目录下渲染**（例如 `第39版/manuscript/`），那里同时有 `references.bib` 与 csl 文件。

### 4. 双版本铁律：投稿版横向，双写版纵向

在腾讯文档编辑器里打开做双写的 docx **必须是纵向版**（`w:orient="landscape"` 计数 = 0）。含横向节的 docx 被本地编辑器打开时会被**静默截断该节之后的全部内容**，曾导致论文后半部丢失。

任何一次渲染之后**二选一**：

| 用途 | 脚本 | 期望计数 |
|---|---|---|
| 投稿上传 | `_post_landscape_jama.py` | landscape = 1 |
| 人机双写 | `_post_portrait_for_coauthor.py` | landscape = 0 |

**切忌对同一文件两个都跑**（互相破坏）。交付前用 python 数 `w:orient="landscape"`，并查段数与末段是否为 "Word Count"，不要只看文件大小。

---

## 三、目录树

```
第39版/
├── README.md                      本文件
├── 互动讲解器_v39_三部分结构.html       ← 主讲解器（对外分享，GitHub Pages 入口）
├── 互动讲解器_BF_simulator_v37.html    旧版 v37 模拟器（保留备查）
├── 互动讲解器_红区决策实验室_v39draft.html  红区决策交互实验（草稿）
├── 算法说明_临床版_v1.html            面向临床读者的算法说明
├── 方法学咨询_...ox-alpha_20260823.md   外部 AI 方法学咨询记录
├── 审稿意见评价与改进计划_ox-alpha_v37.md
├── Review_ox-alpha_20260823_001459.md
├── Review-R2_复审_...ox-alpha_20260823.md
├── 审稿报告_TraeWork_v39+...md
├── 审稿意见处理清单_Trae_v39_2026-08-27.md
├── V37_第二部分架构设计_2026-08-26.md
│
├── R/                             分析管线（32 个脚本，见下表）
├── analysis/                      一次性分析草稿
│   └── v39_step1_ba_mcmc_2d_density.R   Bland-Altman 二维密度图（第一步用）
│
├── manuscript/                    ★ 工作版稿件（渲染工作目录）
│   ├── manuscript_jama_v39.qmd           JAMA 主稿信源
│   ├── manuscript_jama_v39.docx          JAMA 主稿（纵向双写版）
│   ├── supplementary_jama_v39.qmd/.docx  JAMA 补充材料（eMethods + eTable 1-7）
│   ├── manuscript_medarchive_v39.qmd/.docx    medRxiv 主稿
│   ├── supplementary_medarchive_v39.qmd/.docx medRxiv 补充材料（S1-S5）
│   ├── manuscript_v39.qmd/.docx          完整长稿（工作底稿）
│   ├── supplementary_v39.qmd/.docx       完整长稿补充材料
│   ├── references.bib                    65 条参考文献
│   ├── american-medical-association.csl  JAMA 引用格式
│   ├── vancouver.csl                    温哥华格式（备用）
│   ├── _post_format_jama.py             后处理 1：JAMA 版式（字体/行距/页边距）
│   ├── _post_bold_abstract.py           后处理 2：摘要 7 个标签加粗
│   ├── _post_landscape_jama.py          后处理 3：Fig2+Table2 转横向节（投稿用）
│   ├── _post_portrait_for_coauthor.py   后处理 3'：剥离横向节（双写用）
│   ├── _word_count_jama.py              字数统计
│   ├── _audit_stale_numbers.py          审计：qmd 里是否残留写死的旧数字
│   ├── _audit_hardcoded_numbers.py      审计：硬编码数字
│   ├── 审稿意见_QoderWork_v39_2026-09-05.md
│   └── _aplus_backup/landscape_SUBMISSION_20260905/   横向投稿版存档
│
├── Submit/JAMA Network Open/      投稿包
│   ├── 投稿核对表_JAMA与medRxiv_v37.md
│   ├── 杂志要求/                        期刊官方 PDF（稿约、补充材料规范等）
│   ├── manuscript/                      JAMA 轨道（与 manuscript/ 同步）
│   │   ├── manuscript_jama_v39.qmd/.docx
│   │   ├── supplementary_jama_v39.qmd/.docx
│   │   ├── Cover_Letter.txt
│   │   ├── JAMA_合规审查_v37.md
│   │   ├── _sync_docx_to_qmd.py        反向同步：docx 改动写回 qmd
│   │   ├── R/                           20_roc_paper_fig.R、23_dual_view_metrics.R
│   │   ├── figures/                     投稿用图（4 个 PNG）
│   │   ├── output/                      渲染期临时表
│   │   └── AI 审稿/                     15 份 AI 审稿意见与投稿信草稿
│   └── medRxiv_prep/                    medRxiv 轨道
│       ├── manuscript_medarchive_v39.qmd/.docx      ★ 投稿主稿
│       ├── supplementary_medarchive_v39.qmd/.docx   ★ 投稿补充材料
│       ├── medRxiv_投稿字段_v37.md       投稿表单字段
│       ├── _archive_工作长稿_v39/        另一份长稿（已归档，不再投稿）
│       ├── _prerender_backup_medrx/      本轮改动前的 qmd 备份
│       └── output/tables/                双视角判别度数据
│
├── Target/                        TARGET 指南原文与清单（目标试验仿真核对用）
├── 工作产出/                       临时产出（桑基图修复截图）
├── _aplus_backup/                 关键中间产物备份
│   ├── v39_all_numbers.json
│   ├── data/                      4 个 rds（含 GDMT / grace-period 原估计）
│   └── landscape_SUBMISSION_clean_20260904/
│
├── output/
│   ├── tables/                    ★ 全部数字与表（24 个）
│   ├── figures/                   主图与技术路线图
│   ├── figures/v39/               论文正式用图（9 个 PNG）
│   ├── figures/continuous_bf/     连续 BAF 诊断图（33 个，含 figJ 三维 HTML）
│   ├── data/                      估计中间结果 rds
│   ├── simulation/                仿真原始对象（95.7 MB，可由脚本重算）
│   └── shared_bias_dag.png/.svg   偏倚交换性 DAG
│
└── .workbuddy/                    工具脚本与工作记忆
    ├── memory/                    日志 2026-08-21 ~ 09-05 + MEMORY.md
    └── *.py / *.cjs               讲解器注入与路线图渲染脚本
```

---

## 四、逐文件用途

### 4.1 R 分析管线（`R/`，35 个脚本）

管线顺序即编号顺序。前面几个是基础设施，16 到 19 是 v39 主体，20 之后是论文专用图表。

| 文件 | 用途 |
|---|---|
| `00_config.R` | 全局配置。目录常量（`BASE_DIR` / `TAB_DIR` / `FIG_DIR`）、BAF 分区阈值、配色。**所有脚本都 source 它** |
| `01_bsr_core.R` | 核心函数库：经验零分布拟合、BAF 计算、可信区间、两层筛检 |
| `02_comparison_study.R` | 早期对比研究网格（v35 时代），`sigma_ps` 因子在这里驱动 `se_psi_obs` |
| `02b_incremental.R` | 增量续跑支持 |
| `02c_slice.R` | 仿真分片（把大网格切成小片跑） |
| `02d_merge.R` | 分片结果合并 |
| `03_inject_explainer.R` | 把结果注入讲解器 HTML |
| `04_continuous_bf_analysis.R` | 连续 BAF 分析（诊断图 A-F 的数据） |
| `05_bf_calibration_scatter.R` | BAF 校准散点图 + logit 校准改进版 |
| `06_bland_altman.R` | Bland-Altman 一致性与 CCC |
| `07_bf_3d_distribution.R` | 三维 BAF 误差分布（Plotly） |
| `08_trim_sensitivity.R` | 截尾敏感性分析 |
| `09_interior_ba_viz.R` | 内部集 Bland-Altman 可视化 |
| `10_ba_full_viz.R` | 全网格 Bland-Altman 可视化 |
| `12_build_sim_frame.R` | 构建仿真设计框（960 个条件） |
| `13_clinical_ba_viz.R` | 临床视角 Bland-Altman（x 轴 = 预测 BAF，即临床医生真正看到的量） |
| `14_pivot_data_export.R` | 透视表导出 |
| `15_bf_algorithm_improvement.R` | BAF 算法改进评估 |
| `16_sim_v37p1_80grid.R` | **主体仿真**：960 条件 × 1000 重复 = 960,000，随机种子 43 |
| `17_rebuild_pivot.R` | K=50 档加入后重建透视表 |
| `18_v39_three_part_analysis.R` | **v39 三部分分析总脚本**：产出 `v39_all_numbers.json` 的大部分内容 |
| `19_v39_explainer_data.R` | 生成讲解器数据 `v39_explainer_data.json` |
| `20_roc_paper_fig.R` | 论文用 ROC 图（双视角） |
| `21_youden_thresholds.R` | Youden 阈值扫描 |
| `22_merge_fig3_fig4.R` | 合并图 3、图 4 |
| `23_dual_view_metrics.R` | **双视角操作特征**：R0-R4 / C1-C2 各按「判可用」与「扣下」两种阳性定义打分 |
| `24_baseline_table_publication.R` | 发表级基线特征表 |
| `25_adjusted_smd_iptw.R` | IPTW 加权后 SMD（问题 1） |
| `26_adjusted_smd_iptw_gdmt.R` | IPTW 加权后 SMD（问题 2，GDMT） |
| `27_lookup_holdout.R` | **查找表留出验证**：5 折交叉验证，两套留出方案（留出重复 / 留出条件），产出 `v39_lookup_holdout.csv` |
| `28_interval_joint_propagation.R` | **区间联合传播**：把目标估计的抽样变异一并传播，量化覆盖率缺口，产出 `v39_interval_joint_propagation.csv` |
| `29_gdmt_missing_sensitivity.R` | **GDMT 缺失敏感性**：3,494 例 GDMT 评分不确定患者的四种处理口径，产出 `v39_gdmt_missing_sensitivity.csv` |
| `_bench_K50.R` | K=50 档基准测试 |
| `_rebuild_after_K50.sh` / `_wait_and_rebuild_K50.sh` | 加入 K=50 后的重跑编排 |

> 命名提醒：`spec_bd_pct` 与 `ppv_not_bd_pct` 是 R/18 的历史命名，实际语义分别是 **BD 视角的灵敏度** 与 **BD 视角的 NPV**。名字错，数字对，读代码时别被名字带偏。

### 4.2 数字与表（`output/tables/`，27 个）

| 文件 | 用途 |
|---|---|
| **`v39_all_numbers.json`** | **全稿唯一数字信源**。三部分全部数字都在这里 |
| `v39_dual_view.json` | 双视角操作特征（ED / BD 两套灵敏度、特异度、PPV、NPV） |
| `v39_dual_view_strategy.csv` | 双视角按规则汇总（10 列宽表的数据源） |
| `v39_dual_view_auc.csv` | 双视角 AUC |
| `v39_dual_view_roc.csv` | ROC 曲线坐标 |
| `v39_part1_bland_altman.csv` | 第一部分 Bland-Altman 结果 |
| `v39_part1_ba_mcmc_full_stats.csv` | MCMC 版 Bland-Altman 统计量 |
| `v39_part2_reliability_lookup.csv` | 12 桶查找表（BAF × 区间半宽 → 偏倚主导概率） |
| `v39_part2_strategy_comparison.csv` | R0-R4 / C1-C2 策略比较 |
| `v39_part2_discrimination.csv` | 判别度（含似然比 χ²） |
| `v39_part2_ci_width_rules.csv` | 区间宽度与覆盖 |
| `v39_part2_flow.csv` | 决策级联各阶段的流量 |
| `v39_part2_subgroups.csv` | 7 个预设亚组 |
| `v39_part2_confusion3x3.csv` | 真值分区 × 判定 3×3 混淆矩阵 |
| `v39_part3_case_verdicts.csv` | 两个临床问题的判定 |
| `v39_lookup_holdout.csv` | 查找表留出验证（正文 Limitations 与补充 Table S10 / eTable 8） |
| `v39_interval_joint_propagation.csv` | 区间联合传播与覆盖率（Table S11 / eTable 9） |
| `v39_gdmt_missing_sensitivity.csv` | GDMT 缺失四口径敏感性（Table S12 / eTable 10） |
| `v39_roc_paper_auc.txt` | ROC 图用的 AUC 数值 |
| `v39_explainer_data.json` | 讲解器数据 |
| `baseline_table1.csv/.rds` | 基线特征表 |
| `adjusted_smd_iptw.rds` / `_gdmt.rds` | 加权后 SMD（问题 1 / 问题 2） |
| `table01_BF_results.csv` | 早期 BAF 结果（v35 遗留） |
| `table02_simulation_summary_v35.csv` | 早期仿真汇总 |
| `threshold_sweep_results.csv` | 阈值扫描 |

### 4.3 图（`output/figures/`）

| 目录 / 文件 | 用途 |
|---|---|
| `v39/` | **论文正式用图**：fig3 经验零分布与 BAF 面板、figI Bland-Altman MCMC、figP1 内部集 BA、figP2A 可靠性曲线、figP2B 决策级联、figP2C ROC（含 paper 版）、figP2D 区间宽度 |
| `continuous_bf/` | 连续 BAF 诊断图 A-N：误差/覆盖/区间宽度随 BAF_true 变化、按 K 与交换性违反分层、校准曲线、三维 BAF 误差（`figJ_3d_bf_error.html` 5.7 MB）、截尾敏感性 |
| `fig01`–`fig07` | v35 时代的主图（校准图、BAF 主图、仿真热图、分类域、留一法敏感性、QQ 诊断、Bootstrap BAF） |
| `figN_clinical_ba_full/interior` | 临床视角 Bland-Altman |
| `fig_sweep_*` | 阈值扫描前沿与热图 |
| `technical_roadmap_zh/en` | 中英文技术路线图（SVG + PNG） |
| `shared_bias_dag.png/.svg` | 偏倚交换性 DAG（论文与讲解器共用） |

### 4.4 仿真对象（`output/simulation/`，39 个，95.7 MB）

| 文件 | 用途 |
|---|---|
| `comparison_results_v37p1.rds` | 主仿真原始重复（56 MB，可由 `16_sim_v37p1_80grid.R` 重算） |
| `comparison_agg_v37p1.json/.rds` | 聚合结果 |
| `v39_ba_mcmc_reps.rds` | MCMC 版 Bland-Altman 的逐次重复（14.6 MB） |
| `v39_ba_mcmc_stats.rds` | 上者的统计量 |
| `comparison_results.rds` / `_72cond.rds` / `ci_sim_results_*` | v35 时代中间结果 |
| `diag_mc*.rds` / `diag_mcmc*.rds` | 蒙特卡洛误差诊断 |
| `monitor_*.sh` / `post_v37p1_pipeline.sh` | 长时间仿真的监控与续跑脚本 |
| `threshold_sweep.R` / `sim_smallK_*.R` | 阈值扫描与小 K 的一类错误校正 |
| `condition_walkthrough_*` | 单个条件的走查示例（演示用） |

> 这些 rds 都在 `.gitignore` 里，GitHub 上不传。体积最大的三个占 95 MB，需要空间时优先清理，重算代价是跑一次 `16_sim_v37p1_80grid.R`。

### 4.5 讲解器与说明文档（根目录）

| 文件 | 用途 |
|---|---|
| **`互动讲解器_v39_三部分结构.html`** | 主交付物。482 KB 单文件，左侧时间轴 + 右侧卡片，三部分结构，含 SVG/Canvas 图表、双语切换。托管在 GitHub Pages |
| `算法说明_临床版_v1.html` | 面向临床医生的算法说明（不含公式推导） |
| `互动讲解器_BF_simulator_v37.html` | v37 旧版，保留对照 |
| `互动讲解器_红区决策实验室_v39draft.html` | 红区（偏倚主导）决策交互实验，草稿 |
| `方法学咨询_BAF天花板修正与NC小样本贝叶斯方案_...md` | BAF 上界修正与负对照小样本贝叶斯方案 |
| `审稿意见评价与改进计划_ox-alpha_v37.md` / `Review_ox-alpha_....md` / `Review-R2_复审_....md` | 外部 AI 审稿 |
| `审稿报告_TraeWork_v39+...md` / `审稿意见处理清单_Trae_v39_....md` | 内部审稿与处理清单 |
| `V37_第二部分架构设计_2026-08-26.md` | 第二部分架构设计记录 |

### 4.6 `.workbuddy/`

| 文件 | 用途 |
|---|---|
| `memory/MEMORY.md` | 项目长期记忆（约定、坑、待办） |
| `memory/2026-*.md` | 每日工作日志（append-only） |
| `inject_emp_v39.py` / `inject_brisk_appendix.py` | 向讲解器注入内容 |
| `extract_roadmap_en.cjs` / `render_roadmap_zh_en.cjs` / `test_toggle.cjs` | 路线图与语言切换的渲染/测试脚本 |

---

## 五、三条投稿轨道的关系

| 轨道 | 主稿 | 补充材料 | 定位 |
|---|---|---|---|
| **JAMA Network Open** | `Submit/JAMA Network Open/manuscript/manuscript_jama_v39.*` | `supplementary_jama_v39.*`（eMethods + eTable 1-10） | 主投稿目标。正文实测 **6,665 词**，超 3,000 上限近一倍，压缩尚未开始；文内 `Word Count` 声明已同步为 6,665 |
| **medRxiv / MedArchive** | `Submit/JAMA Network Open/medRxiv_prep/manuscript_medarchive_v39.*` | `supplementary_medarchive_v39.*`（S1-S6，Table S1-S12） | 预印本。含 Preprint notice（CC-BY 4.0）与关键词，正文更长 |
| **完整长稿** | `manuscript/manuscript_v39.*`（另有归档副本） | `supplementary_v39.*` | 工作底稿，不投稿 |

三轨**数字完全一致**（都从同一个 JSON 取值），结构与披露详略不同。补充材料是两篇结构不同的文档：JAMA 是 eMethods + eTable 1-10，medRxiv 是 S1-S6（Table S1-S12），不能互相替换。三轨正文与补充材料共用同一批 CSV 与 PNG，数字从同一个 JSON 取值。

---

## 六、常用命令

```bash
# 渲染（在「第39版」目录下，qmd 需位于直接子目录）
cd 第39版
export PATH="/Library/Frameworks/R.framework/Resources/bin:/Applications/quarto/bin:$PATH"
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 LC_CTYPE=en_US.UTF-8
/Applications/quarto/bin/quarto render manuscript/manuscript_jama_v39.qmd --to docx

# 交付前体检（三件事都要查）
python3 - <<'PY'
import zipfile
x = zipfile.ZipFile("manuscript/manuscript_jama_v39.docx").read("word/document.xml").decode()
print("landscape 节数:", x.count('w:orient="landscape"'))   # 双写版须 0，投稿版须 1
print("段数:", x.count("<w:p ") + x.count("<w:p>"))          # 须 114
PY

# 查某个数字
python3 -c "import json;d=json.load(open('output/tables/v39_all_numbers.json'));print(d['part3']['cases'][0])"
```

---

## 七、已知待办与悬而未决的问题

按优先级排列，前两条会影响结论。

| # | 问题 | 说明 |
|---|---|---|
| 0 | **JNO 四项硬性限制全部超标（2026-09-11 实测）** | 正文 **6,665 / 3,000**；摘要 **432 / 350**；Key Points **162 / 75–100**；图表 **3 表 + 3 图 = 6 / 5**。**标题 91 字符**（JAMA 版 `Quantifying Bias in Causal Estimates Using Negative Controls: The Bias Attribution Fraction`，< 100 合规；medRxiv / 长稿版 116 字符，无此限）、参考文献 20 条合规。文内 `Word Count` 声明已同步为 **6,665**（原 6,471 因本轮补入暴露定义段与限制段披露而增加 194 词；更早的 2,949 是 2026-08-28 的硬编码残留，已清除）。三份投稿信（`Cover_Letter.txt` 与 `AI 审稿/` 下两封）已一并同步为 6,665 并改用 JAMA 版标题。**压缩尚未开始**，按用户 2026-09-11 的指示推迟到内容完整之后再统一处理；压缩阶段的优先候选是本轮新增的两句披露 |
| 1 | **负对照与主分析所用的暴露定义不同（2026-09-11 实证更正，原描述有误）** | 主分析 `scripts/run_grace_period_guideline.R` 读 `ltmle_wide_K2_guideline.rds`，其中 `A_W0 >= 2`（达到指南目标剂量 ≥50%）在 `Y_W0==0` 子集中占 **1,772/14,677 = 12.1%**；12 个负对照 `scripts/run_negative_controls_expanded_Codex.R` 读 `ltmle_wide_K2.rds`，同名 `A_W0 >= 2` 占 **6,379/14,677 = 43.5%**。两文件行数相同（均 15,053，`Y_W0==0` 后均 14,677），`subject_id`/`age`/`death_day` 等列逐值相同，但 **`A_W0` 编码含义不同**（交叉表：K2 的 `A_W0=2` 含 3,993 例在 guideline 编码下为 0；两列 Pearson r = 0.416），是**两个不同的暴露对比**。OHDSI 校准要求负对照与目标估计走同一处理对比，现在不是。**原描述「两点治疗 + 删失节点 vs 单点治疗」经核对不成立**：两侧都是单点 `Anodes="A_W0"`、无 `Cnodes`、仅基线协变量、`survivalOutcome=FALSE`、同样排除宽限期死亡；除暴露定义外只有一处次要差异，`SL.library` 主分析为 `c("SL.glm","SL.glmnet")`、负对照为 `"SL.glm"`。**影响已量化（2026-09-11，诊断 `R/91_diag_matched_null_impact.R`，其 K2 一路逐位复现已发表 `bsr_results_v35.rds`）**：把同一套负对照结局挂到 guideline 队列上重拟合后，`mu_B` 由 **−0.1905 变 −0.1678**（绝对量降 11.9%），`sigma_B` 由 **0.0680 变 0.1129**（升 66.1%）；由此**问题 2 的校准 P 由 0.0452 升到 0.1026，越过 .05，不再通过 layer 1**，BAF 点估计由 0.510 降到 0.460（由偏倚主导区边缘移到混合区边缘），可信区间由 [0.356, 0.603] 展宽为 [0.186, 0.619]；**问题 1 两套面板下都判 not usable as effect evidence**（校准 P 0.946 → 0.894，BAF 0.907 → 0.875）。**判定标签不变**（not usable / competitive, no verdict），但 Q2 的「通过 layer 1」与「点估计略偏倚主导」两处叙述会变；且配平后面板有 2/12 个负对照转为阳性（Fall without fracture RR 1.195、Gout RR 1.136），正文「all 12 negative controls showing protective or null associations」一句需改。治本：负对照改用 guideline 队列与同一 learner，重估两问全部案例数字（诊断见 `R/90_diag_nc_exposure_consistency.R`、`R/91_diag_matched_null_impact.R`） |
| 2 | ~~人群不一致~~ **已澄清（2026-09-11）** | 两个数字都对，只是角色不同：**15,053 = 评估合格性**，其中 **376 例宽限期内未存活至 time-zero 被排除**，**14,677 = 分析队列**（1,772 / 12,905）。讲解器入组流程图早已写对，稿件正文原先只写 14,677 而未交代流程。已在三份稿件的 Methods 补入组流程句，并由脚本从数据计算 + `stopifnot` 与 Table 3 的 N 交叉校验。**2026-09-11 更正**：原描述把这与「达标率 43% vs 12%」混为一谈，后者其实是第 1 条的暴露定义差异，与样本量无关 |
| 3 | Methods 三处断言与代码不符 | 代码是单点治疗、仅基线协变量、单一 glm learner；Methods 却写「处理时变混杂」「处理信息性删失」「三个学习器的 Super Learner」。四处表述需改 |
| 4 | ~~查找表是 in-sample 校准~~ **已处理（v39）** | R/27 做了两套 5 折留出验证。留出重复时各规则误用率小数点后两位不变；留出条件时最严规则误用率 2.2% → 2.4%，五折最大波动 4.1%。已写入正文 Limitations 与补充 Table S10 / eTable 8 |
| 5 | 摘要 432 词，超 JAMA 上限 350 | 待压缩（见第 0 条） |
| 6 | ~~σψ 水平的措辞~~ **已改（v39）** | 原写「brackets the standard errors of the two case-study estimates」，但网格水平是 0.06 与 0.10，最小的那个估计标准误低于下界，"brackets" 不成立。两份补充材料已改为「closely matches ...，the smaller falling marginally below the lower grid level」 |
| 7 | ~~AUC 反转是否写进 Discussion~~ **已写（v39）** | 正文与讨论已点明 BAF̂ 在效应主导视角判别更好（0.951 vs 0.918），校准 P 相反（0.721 vs 0.787）；区间半宽的贡献方向在两个视角不一致，也不加排序信息，保留它只是为了支撑 R3 |
| 8 | 临床治疗策略操作化 | 达标剂量阈值、新使用者入排窗口、HFrEF 的 EF 分界值，待临床数值到位后落稿 |
| 9 | ~~medRxiv 主稿未写明样本量~~ **已补（v39）** | 长稿与 medRxiv 主稿的缺失数据段落已写明「Of the 14,677 patients in the question-2 cohort」。人群口径见第 2 条（已澄清：15,053 评估合格 / 14,677 分析队列） |

---

## 八、相关仓库

| 仓库 | 地址 | 内容 |
|---|---|---|
| `bias-fraction` | https://github.com/zengzhechun/bias-fraction | 论文全部代码、数据、讲解器，GitHub Pages 入口为 `index.html` |
| `biasratio` | https://github.com/zengzhechun/biasratio | BAF 估计量、可信区间、两层筛检、Table 2 全部报告规则（`bf_rules()`）的 R 包实现（v0.3.1，253 个单元测试通过；归档 commit 27c6a0f） |
