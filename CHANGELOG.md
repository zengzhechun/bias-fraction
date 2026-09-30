# V35 修改摘要（2026-08-16）

依据：`manuscript_v34/审稿意见_WorkBuddy_v34_2026-08-12.md`（M1–M8 + m1–m7 分级问题清单）。
本目录由 manuscript_v34 全量复制而来，逐条修复后形成 V35 全套文档。

## 一、Major（投稿前必须修复）

| # | 审稿意见 | 修复内容 | 涉及文件 |
|---|---|---|---|
| M1 | fister2016hrguided 4/5 作者虚构 + DOI 错 | 作者列替换为 Fister M, Mikuz U, Starc V, Vrtovec B, Haddad F；DOI 改 10.1016/j.jelectrocard.2016.01.002 | `manuscript/references.bib`、`Submit/JAMA Network Open/manuscript/references.bib`（两份同步） |
| M2 | titratehf2024 标题/一作/卷期页/DOI 全错 | 整条重写为 Malgie J, et al. "Contemporary guideline-directed medical therapy in de novo, chronic, and worsening heart failure patients: first data from the TITRATE-HF study". Eur J Heart Fail 2024;26(7):1549-1560, doi:10.1002/ejhf.3267。经 grep 核实正文陈述与文献内容一致，无需改正文 | 同上两份 bib |
| M3 | bok2024bbadjustment 第 2/3 作者虚构 | 改为 Bok RW, Lacoste JL, Fang W, Kido K（仅 4 人） | 同上两份 bib |
| M4 | Table S4 引用 4 处指向不存在的表 | 补充材料**新增 eTable 7**（每配置 BER vs BF 相对偏倚对照表，数据源 table02 新增列 bsr_rel_bias；null 行标 "Not defined"）；两版正文 "Table S4"×2 → "eTable 7"（完全版 Results/Discussion、投稿版 Results） | `manuscript/supplementary_v35.qmd`、`Submit/.../supplement_jama_v35.qmd`、两版正文 |
| M5 | TARGET checklist 位置错引（eAppendix 10 → 应为 5） | 完全版 Methods "eAppendix 10" → "eAppendix 5" | `manuscript/manuscript_v35.qmd` |

说明：M1–M3 三条问题文献经 grep 确认在四份 qmd 正文中**均未被引用**（仅存在于 bib 条目池），故只需修正 bib 本身，正文无需改动。

## 二、Moderate（强烈建议）

| # | 审稿意见 | 修复内容 | 涉及文件 |
|---|---|---|---|
| M6 | null 条件（48/336）被排除出 BF 全部汇总统计，与"BF 在零效应处天然有限"卖点矛盾 | **代码修复 + 真实重跑**：`run_sim_worker_v35.R` 中 `bf_true` 在 null 条件下由 NaN 改为 1（`ber_to_bf(Inf)` 的正确极限）；BF 的 RMSE/相对偏倚统计纳入 null 条件。修复不消耗额外随机数（common random numbers），全部 336 条件重跑后估计与 v34 **逐位一致**（分类准确率 80.0/41.8/95.1、BF 0.9058 [0.7403, 0.9930]、+2.1%/−31.7%、RMSE 0.1345/0.1187 全部复现）。**新增 null 统计**：48 个 null 条件下 BF 平均相对偏倚 −30.2%、RMSE 0.3390（有界量表上限效应致向下收缩，对应 eAppendix 11 Property 1）；BER 相对偏倚在零效应处无定义（真值 ∞）——该对比直接支撑"BF 在零效应处天然有限"的卖点。正文 Results 新增一句报告；merge 脚本新增 `bf_rel_bias_null`/`bf_rmse_null` 列（bf 主列保持非 null 口径以维持与 v34 文本连续性） | `analysis/run_sim_worker_v35.R`、`analysis/merge_sim_results_v35.R`、两版正文、讲解器 HTML |
| M7 | "randomly selected 30%" 与代码确定性实现不符 | 文字改为与代码一致的确定性描述："a fixed, pre-specified subset of round(K×0.3) controls—the last 4 of 12 or the last 8 of 25"；eTable 2 caption 同步加 fixed subset 说明；代码注释文档化该固定子集实现（`rep(bias_mu, n_nc−n_ex)` 后接 `rep(bias_mu+0.15, n_ex)`） | 完全版正文、两版补充材料、worker 代码 |
| M8 | plug-in vs bootstrap 中位数点估计差异未报告 | 补充材料**新增 eTable 8**（两口径对照：BB 案例 plug-in BF 0.968 vs bootstrap 中位数 0.906；BER 30.4 vs 9.6）；完全版正文加一句引述 | 完全版正文 + 补充材料 |

## 三、Minor（建议）

| # | 审稿意见 | 修复内容 |
|---|---|---|
| m1 | log_bsr floor 1e-4 未文档化 | eAppendix 9 加句 "the log ratio is floored at 10⁻⁴ before the log transform" | 两版补充材料 |
| m2 | Fieller vs bootstrap CI 分歧仅一句带过 | eAppendix 1 新增 "Why the two interval methods can disagree" 段：Fieller 允许 BF≥0.59 弱于 bootstrap 下界 0.74，及两个方法学设计差异的原因 | 两版补充材料 |
| m3 | "factors of 2" 阈值表述不精确 | 投稿版改为精确表述："The threshold 0.5 marks bias and residual effect of equal magnitude (BER = 1); the threshold 1/3 marks a residual effect twice the bias (BER = 0.5)" | `Submit/.../manuscript_jama_v35.qmd` |
| m4 | Table S1/S7/S8 与 eTable 双编号系统 | 统一改编：Table S1→eTable 9、Table S7→eTable 10、Table S8→eTable 11（新增表直接编 eTable 7/8，避免重排现有 eTable 1–6 的正文引用） | 完全版补充材料 |
| m5 | Abstract "calibrated RR, 1.01" 与 "+137% to +319%" 硬编码 | 改为内联计算：`` `r round(bb$bsr$rr_true, 2)` `` 与 `` `r sprintf("%.0f", ber_relbias_exv0_range[1])` ``（数值已验证不变，纯稳健性） | 两版正文 |
| m6 | 投稿版未报告 GDMT Fieller 结果 | GDMT 段新增："the Fieller confidence set was bounded, [0.42, 1.80], and also straddled the ratio threshold of 1 (eAppendix 1 in the Supplement)" | 投稿版正文 |
| m7 | 合作作者邮箱占位符、Zenodo DOI 待补 | **作者投稿前自查项**（AI 无法代办）：补齐合作者机构邮箱、Data Sharing Statement 的 Zenodo DOI。见下方自查清单 | — |

## 四、版本号与交叉引用升级

- 4 份 qmd 重命名为 v35（`manuscript_v35.qmd`、`supplementary_v35.qmd`、`manuscript_jama_v35.qmd`、`supplement_jama_v35.qmd`），date 统一 2026-08-16
- 5 个 R 脚本重命名 + 输出名升级：`sim_v35_*`、`simulation_merged_v35.rds`、`bsr_results_v35.rds`、`table02_simulation_summary_v35.csv`；`R/00_config.R` 新增 `V35_DIR`
- `互动讲解器_BF_simulator_v35.html`：版本标识升级；BER 倍数比喻段新增 v35 null 证据句（null 条件下 BF 可估计、BER 无定义的直接模拟证据）
- grep 验证：四份 qmd 无残留 "Table S4"、无错误 "eAppendix 10" 引用（仅剩 eAppendix 10 章节标题自身）、无功能性 v34 路径引用

## 五、数据管线重跑记录

4 个模拟 worker（约 5 秒/个）+ merge + 案例分析 + 7 张图全部重跑，输出至 v35 目录：
- `simulation_merged_v35.rds`（336×21）、`bsr_results_v35.rds`、`table02_simulation_summary_v35.csv`（新增 3 列）
- 7 张 figures 重生成
- **逐位复现验证**：所有 v34 已报告数值不变；仅新增 null 统计（−30.2%、RMSE 0.3390）

## 六、投稿前作者自查清单（m7 遗留）

- [ ] 合作者机构邮箱补全（Wang Jinwen / Zuo Huijuan / Shu Lixia）
- [ ] Data Sharing Statement 的 Zenodo DOI（数据/代码归档后填入）
- [ ] Cover Letter 最终核对（已确认无 v34 残留引用）

## 七、渲染产物

- `manuscript/manuscript_v35.docx`、`manuscript/supplementary_v35.docx`
- `Submit/JAMA Network Open/manuscript/manuscript_jama_v35.docx`、`supplement_jama_v35.docx`
- 渲染后 docx 抽查通过：eTable 7/8/9/10/11、null 条件句（−30.2%）、fixed pre-specified subset、Fieller 分歧段、floor 句均正确呈现；无 "Table S4"/"randomly selected" 残留
- 备注：GDMT Fieller 上界真值 1.7953，四版 docx 统一渲染为 "1.8"（R `round()` 尾零省略，审稿报告中的 "1.80" 为简写），与 v34 逐字一致，未改动

## 八、追加修改（2026-08-16 下午）：强化 MIMIC 案例研究的核心叙事

应用户要求，在两版正文与讲解器中突出两层含义：**① 案例研究本身的严谨性**——从严格遵循 TARGET 指南（Transparent Reporting of Observational Studies Emulating a Target Trial）到采用前沿 TMLE 双重稳健估计器的全流程规范；**② 即便方法论已达最优，系统性偏移依然不可避免**——设计规范与估计精良各自解决的是其设计上能解决的威胁，未测量混杂不在其列，经验性偏倚诊断是最佳实践的必要补充而非否定。

| 文件 | 修改位置 | 内容 |
|---|---|---|
| `manuscript_v35.qmd`（完全版） | Abstract Results / Conclusions、Introduction 末段、Methods 案例设计开头、TMLE 段、Results 校准段末、Discussion 案例段、Clinical interpretation，共 7 处 | "Although the case study was designed under the TARGET guideline and analyzed with doubly robust TMLE..."；"state-of-the-art doubly robust estimator that represents the current frontier of causal inference methodology"；"dual safeguard—rigorous design and a frontier estimator"；"cannot be dismissed as an artifact of sloppy analysis"；"not a concession of weakness but a necessary complement" |
| `manuscript_jama_v35.qmd`（投稿版） | Abstract Results / Conclusions、Methods 案例设计 + TMLE 段、Results 校准段末、Discussion 案例段、Conclusions，共 7 处 | 同上两层含义的紧凑版（JAMA 篇幅约束） |
| `互动讲解器_BF_simulator_v35.html` | ① 背景卡片、⑥ 病例研究开篇 callout、术语表，共 3 处 | "严格遵循 TARGET 指南…TMLE 因果推断方法论前沿的双重稳健估计器"；"即便有这双重保障，估计仍被系统性偏移主导（BF = 0.91）…经验性偏倚诊断不是对研究严谨性的否定，而是最佳实践的必要补充"；术语表新增 TARGET 指南词条 |

渲染产物已同步更新：`manuscript_v35.docx`、`manuscript_jama_v35.docx`（docx 抽查 5 个关键短语全部命中；HTML div/ul 标签平衡校验通过）。

## 2026-08-17 — Provenance clarification (origin attribution)

Clarified the originality boundary across all documents (both manuscripts, both supplements,
cover letter, simulator, README):

- BF and BER are explicitly stated as **new metrics proposed by this work** (first appearance in
  the Abstract/Introduction, in the metric definitions, in the Discussion, and in the Data
  Sharing statements).
- Empirical calibration is explicitly attributed as **pre-existing methodology by Schuemie et al.**,
  implemented in the OHDSI `EmpiricalCalibration` R package (with citations), and not a
  contribution of this paper.
- Added explicit boundary sentences (e.g., "does not include BF or BER", "not an existing output
  of the calibration software") to preclude any reading that BF/BER are package-native metrics.
- Positioned BF/BER as **strengthening and extending** the existing framework's metrics (from a
  binary calibrated p-value to a bounded, continuous diagnostic).
- Simulator: bilingual (zh/en) provenance statements added at hero, framework section, animation
  B/D steps, metric dictionary, glossary (new EmpiricalCalibration entry), and footer.

## 2026-09-11 — v39: BAF renaming, three v39 validation analyses, negative-control disclosure

### 1. Metric renamed BF → Bias Attribution Fraction (BAF)

The acronym *BF* collided with the Bayes factor. From v39 onward the diagnostic quantity and the
rule tables use **BAF** everywhere (manuscripts in all three tracks, supplements, figures,
tables, explainers, code output, and the `biasratio` R package, which moved to **v0.3.1**).

- Lowercase `bf` is **deliberately unchanged**: it is an internal code identifier
  (`bf_classify()`, `bf_rules()`, `BF_THRESH_BIAS`) and renaming it would break the API.
- Files and documents predating v39 (v34–v38 audit records, review reports) **intentionally keep
  BF** as published. This is not an oversight.
- `output/tables/table01_BF_results.csv` → `table01_BAF_results.csv` (headers renamed too).

### 2. New in v39: three validation analyses

| Script | Analysis | Result |
|---|---|---|
| `R/27_lookup_holdout.R` | 5-fold hold-out validation of the 12-bucket lookup table (two schemes: hold out repetitions, hold out conditions) | Misuse rate unchanged to two decimals; worst-rule 2.2% → 2.4%, five-fold spread ≤ 4.1% |
| `R/28_interval_joint_propagation.R` | Joint propagation of interval uncertainty | Coverage 78.8% → 97.7% |
| `R/29_gdmt_missing_sensitivity.R` | GDMT missing-exposure sensitivity, four definitions | Reported in Table S12 / eTable 10 |

All three landed in every track: long report and medRxiv use Table S10/S11/S12, JAMA uses
eTable 8/9/10.

### 3. Cohort flow made explicit and scripted

The manuscript previously reported only the analysis cohort. The flow is now stated and
cross-checked: **15,053 hospitalisations assessed for eligibility → 376 excluded (death within the
7-day grace period, `Y_W0 == 1`) → 14,677 analysed** (1,772 exposed / 12,905 control). The setup
block recomputes all three from the LTMLE input file and asserts consistency with Table 3 via
`stopifnot`, so no number can drift on its own.

> Earlier internal notes described "15,053 vs 14,677" as a population inconsistency against
> Table 3. That diagnosis was **wrong**: both numbers are correct and sit upstream/downstream in
> the same flow. The apparent "43% vs 12% adherence" gap has a different cause, below.

### 4. 🔴 Negative-control exposure definition disclosed

Direct inspection disproved the previously recorded explanation (that the negative controls used a
weaker two-point treatment node, a censoring node, or a survival outcome). Both sides are in fact
single-point (`Anodes = "A_W0"`), have no censoring node, are non-survival, share the same 10
baseline covariates, and apply the same grace-period exclusion. The real difference is that the
two panels are read from **different covariate tables**, where `A_W0` encodes different exposures:

| | Panel | `A_W0` counts | Share at or above target dose |
|---|---|---|---|
| Target estimates | `ltmle_wide_K2_guideline.rds` | carvedilol / metoprolol succinate / bisoprolol, ≥50% of target dose | 11.8% |
| Negative controls | `ltmle_wide_K2.rds` | all β-blocker agents | 43.0% |

3,993 rows coded `A_W0 = 2` in the K2 file are coded 0 in the guideline file. Quantified impact
(scripts `R/90`–`R/91`, whose K2 arm reproduces the published empirical null bit-for-bit as a
self-check):

| Quantity | As published | Panel refitted to the target cohort |
|---|---|---|
| `mu_B` | −0.1905 | −0.1678 |
| `sigma_B` | 0.0680 | 0.1129 (+66.1%) |
| Question 1 calibrated *P* / BAF | 0.946 / 0.907 [0.739, 0.993] | 0.894 / 0.875 [0.385, 0.992] |
| Question 2 calibrated *P* / BAF | 0.045 / 0.510 [0.356, 0.603] | 0.103 / 0.460 [0.186, 0.619] |
| Verdict labels | not usable / competitive | **unchanged** |

Question 2 would no longer clear the first screening layer, and 2 of 12 negative controls turn
positive (fall without fracture RR 1.195; gout RR 1.136). The disclosure is written into Methods,
Limitations, and the supplement across all three tracks. The decision whether to re-run the
negative controls on the guideline cohort is still open; it would move every case-study BAF number
and the Abstract, Key Points, Results, Discussion, and eTable 6.

### 5. Cover letters and explainers brought back into sync

- Three different title variants were in circulation; all three cover letters now quote the
  manuscript title being submitted. A duplicated word-count sentence was removed, and the count
  updated **6,471 → 6,665** (the v39 negative-control disclosure added 194 words).
- `Cover_Letter.txt` still carried v33-era figures (640 conditions; zone accuracy 58.1/95.7/25.0;
  GDMT BAF 0.45). Replaced with the v39 values from `v39_all_numbers.json`.
- Interval naming corrected to "95% credible interval" (the manuscript defines it as a credible,
  not a confidence, interval).
- Em dashes removed from the explainers. **Rule applied: only the doubled CJK dash `——` is
  rewritten**; single `—` characters are left alone because many are empty-cell placeholders in
  tables and JS (`d = '—'`), which are data, not punctuation.
- `算法说明_临床版_v1.html` also had **stale simulation sizes** (`64 万次` / `640 个条件`) left over
  from the old design; corrected to `96 万次` / `960 个条件`.
- `index.html` now serves the **v39** explainer; the v38 explainer remains in the repo for
  provenance.

### 6. Repository contents

Added for v39: `R/27`–`R/29`, `R/90`–`R/91`, six v39 `.qmd` sources, six rendered `.docx`
manuscripts, the v39 figure and table exports, `Target/` (TARGET reporting materials), and
`docs/`. Large simulation objects (tens of MB) and the row-level LTMLE frames remain excluded.

## 2026-09-11 (follow-up) — `算法说明_临床版_v1.html` realigned to the v39 lookup

The clinical algorithm sheet had been only **partially** resynchronised: its simulation size had been
updated to `96 万次 / 960 个条件`, but its 12-bin lookup table, its narrow/wide threshold and its
worked example were still the pre-v39 values. Because the sheet is published on the same Pages site
as the v39 explainer, two companion documents were quoting different lookup tables for the same
algorithm. Every replacement below was taken mechanically from `output/tables/v39_all_numbers.json`.

| Item | Before | After (v39) |
|---|---|---|
| Version banner | `对应论文稿件 v37` + `2026-08-26` | `对应论文稿件 v39` + `2026-09-11` |
| Term used for BAF | `偏倚份额` (9 occurrences) | `偏倚分数`, matching the explainer and README |
| Narrow/wide threshold | `0.133` | `0.1299` (`part2.ci_width.median_half_width`) |
| Bin centres | `0.06, 0.17, 0.26, …` | `0.09, 0.18, 0.27, …` |
| 12 bin rows (centre / narrow / wide / conservative) | v37-era values | `part2.lookup`, all 48 cells |
| Worked example (BAF 0.33, CI 0.15–0.50) | bin 4, `0.0878 / 0.265` → `P ≈ 26.5%` | bin 4, `0.1114 / 0.2390` → `P ≈ 23.9%` |
| Counterexample (BAF 0.85, CI 0.75–0.97) | `P ≈ 94%` | `P ≈ 99.7%` |
| Output-format example | `P ≈ 3.1%` | `P ≈ 3.6%` |
| Bin 7 verdict | `不可作效应证据` | `势均力敌·暂不下结论` (0.6482 < 0.65, so v39 classifies it as competitive) |

Verification performed on the shipped file: all 48 lookup cells re-parsed from the HTML and compared
cell-by-cell against `part2.lookup` (12/12 rows exact); HTML tag pairing checked with `html.parser`
(0 mismatches); the doubled CJK dash `——` count is 0; and the residual scan confirms no `v37`,
`0.133`, `26.5%`, `0.0878` or `偏倚份额` remains. The bin-7 verdict change is the one substantive
downstream effect: the v39 lookup puts that bin just under the 0.65 break, so it moves from
"not usable" to "competitive, no verdict". No manuscript, table or figure number is affected.


## 2026-09-30 — v40: 1.92M pooled evidence base, bias-direction regimes, guideline-restricted negative-control panel, `legacy/` archival

### Evidence base rebuilt as a pooled factorial design

The v39 release rested on a single 960-condition grid (960,000 estimates) whose bias centres were
all negative. v40 pools that **primary grid** with a **sign-flipped companion grid** (mirror-imaged
bias centres, same five factors), giving **1,920 conditions × 1,000 repetitions = 1,920,000
estimates** — 1,728,000 in the interior and 192,000 on the boundary. Truth mix: 52.5%
bias-dominated / 28.75% mixed / 18.75% effect-dominated. The main grid remains the *design*
description; **every performance number is now computed on the pooled grid**.

| Quantity | v39 (primary grid only) | **v40 (pooled)** |
|---|---|---|
| Conditions / estimates | 960 / 960,000 | **1,920 / 1,920,000** |
| Agreement (interior) | bias, SD, CCC on 864,000 | **bias −0.020, SD 0.113, CCC 0.838 on 1,728,000** |
| Agreement (full) | — | **bias −0.040, SD 0.133, CCC 0.810, 93.9% within limits, slope −0.211** |
| Discrimination AUC | 0.787 → 0.918 | **0.787 → 0.922** (LR χ² = 3835.1, df = 1, *P* < .001) |
| Misuse rate | 36.0% → 2.9% | **53.4% (uncalibrated) / 36.0% (calibrated *P* only) → 3.0%** (full two-layer) |
| Yield under the full rule | — | **22.1%** |

The 12-bucket reliability lookup, the dual-view ROC, the confusion matrix and the K-subgroup tables
were all recomputed (`output/tables/v40_part2_*`). Table 1 was upgraded to the pooled design
(μ_B ±0.05 to ±0.40, 16 levels, 1,920 conditions).

### Bias-direction regimes (new)

Pooling the two grids isolates four regimes by construction:

| Regime | Conditions | Coverage | Zone match | Misuse under R3 |
|---|---|---|---|---|
| Inflation | 960 | 71.1% | 53.1% | 7.4% |
| Shrinkage | 420 | 46.9% | 42.5% | 0% |
| Cancellation | 36 | 18.4% | 18.4% | 0% |
| Reversal | 504 | 36.1% | 84.3% | 100% |

Point estimates hold up across directions (|bias| ≤ 0.069); interval coverage and the misuse rate
do not. The three-zone classification is more robust than the credible interval. New scripts:
`R/96_mirror_mu_regimes.R` (builds the companion grid, 8-way parallel, 34.4 min),
`R/97_direction_regimes_summary.R` (writes `v40_direction_regimes.csv`,
`v40_direction_summary.csv/.json`). New supplementary subsections and figures (`figP3_direction_roles`).

### Negative-control panel refitted on the guideline-restricted contrast

In v39 the 12 negative controls were fitted on a cohort in which exposure counted **all**
β-blocker agents, whereas the target estimates use the guideline-restricted definition
(carvedilol, metoprolol succinate, or bisoprolol at ≥50% of target dose). This mismatch was
disclosed as a limitation. In v40 the panel is **promoted to a guideline-restricted null**:

- bias SD widens 0.068 → **0.113**;
- the GDMT calibrated *P* value moves 0.045 → **0.103**, so GDMT **no longer clears the first
  screening layer** — the calibrated *P* value alone would have licensed both case questions;
- **both verdict labels are unchanged** (β-blocker *not usable as effect evidence*, GDMT *mixed /
  competitive*).

Scripts: `R/92_promote_guideline_null.R`, `R/93_promote_guideline_calibration.R`,
`R/94_negative_control_screening_audit.R`, `R/95_ejection_fraction_proxy_sensitivity.R`.
New tables: `v40_guideline_null_promotion.csv`, `v40_negative_control_screening.csv`,
`v40_ejection_fraction_proxy.csv` / `_classification.csv`.

### Case-study numbers (pooled, guideline-restricted)

| Question | Uncalibrated RR | Calibrated RR | Calibrated *P* | BAF̂ (95% CrI) | Layer 1 | Verdict |
|---|---|---|---|---|---|---|
| β-blocker ≥50% target dose | 0.83 | 0.98 | 0.894 | **0.87 (0.38–0.99)** | fail | not usable as effect evidence |
| GDMT ≥2 of 3 classes | 0.68 | 0.81 | 0.103 | **0.46 (0.19–0.62)** | fail | mixed / competitive |

μ_B = −0.168, σ_B = 0.113 shared by both questions; 14,677 patients analysed (15,053 screened,
376 excluded for death within the 7-day grace period).

### Manuscripts and submission package

All seven renders were rebuilt on the pooled base: JAMA full + abbreviated + supplement, medRxiv
main + supplement, full working report + supplement, plus the landscape submission DOCX. The
*JAMA Network Open* upload set is numbered in upload order — `01 Cover_Letter.txt`,
`02 manuscript-JNO-V40.docx`, `03 supplementary-JNO_v40.docx` — via the idempotent
`manuscript/_number_upload_files.py`. Word count of the submitted main text: **2,996**.
Full details in `docs/第40版_README.md` and the source project's
`Submit/JAMA Network Open/JNO投稿材料清单与合规对照_20260929.md`.

### Repository hygiene: `legacy/` archival and explainer link fix

- **117 superseded items** (v34–v39 manuscripts, renders, tables, figures, logs, explainers,
  and the v38/v39 `18_*`/`19_*` scripts) moved to **`legacy/`**, with a new `legacy/README.md`
  explaining each subdirectory. Nothing was deleted; `git log --follow` still traces each file.
  The root, `R/`, `manuscript/`, `paper/`, `submission/`, `output/`, `logs/v40/`, `analysis/`,
  `simulation/`, `Target/`, `docs/` and `figures/` now reflect **v40 only**.
- **Site entry point replaced**: root `index.html` is now the **v40** explainer
  (`互动讲解器_v40_三部分结构.html`), replacing the v39 file that had been serving the Pages site.
- **Relative HTML links fixed.** The README previously linked a walkthrough as
  `[算法说明_临床版_v1.html](算法说明_临床版_v1.html)`. On GitHub a relative link resolves to the
  **blob view, which shows source code**, not the rendered page. All explainer links in the README
  now use absolute Pages URLs. ASCII aliases were added for stable referencing:
  `explainer_v40.html` (= the explainer) and `algorithm_walkthrough_zh.html` (= the clinical
  walkthrough); the Chinese-named originals remain in place.
- **README rewritten for v40**: pooled evidence base, direction regimes, refitted panel, `bafratio`
  v0.4.0, `Explainer v40` badge, updated structure table (including `legacy/`), v40 reproduction
  commands, and a refreshed Chinese summary.
- **`.gitignore`**: the large v40 simulation objects are ignored
  (`v40_ba_gibbs_reps.rds`, `v40_interval_joint_reps.rds`, `v40_comparison_results*.rds`,
  `v40_sim_frame*.rds`); the three small derived objects
  (`v40_lookup_holdout.rds`, `v40_gdmt_missing_sensitivity.rds`, `v40_ba_gibbs_stats.rds`) are
  committed.

### Clinical walkthrough re-synced to v40

`算法说明_临床版_v1.html` / `algorithm_walkthrough_zh.html` had a v40 banner over a **v39 lookup
table**. It has now been re-synced to `output/tables/v40_all_numbers.json` (`part2.lookup`), 43
edits across one document:

- **All 12 lookup rows rewritten** bin by bin (centres 0.125 / 0.233 / 0.310 / 0.372 / 0.424 /
  0.471 / 0.516 / 0.565 / 0.623 / 0.694 / 0.782 / 0.892), with the narrow / wide / conservative
  columns updated to match. Each row keeps its original `data-page-node-id` anchors.
- **Verdict tiers follow the v40 table**: bins 1–3 usable · bins 4–5 mixed · bin 6 competitive ·
  **bins 7–12 not usable as effect evidence** (previously bin 7 onward read 势均力敌).
- **Worked example updated**: BAF̂ 0.33 → **0.37**; conservative P(BD) 23.9% → **27.1%**; narrow /
  wide 0.1114 / 0.2390 → **0.0901 / 0.2709**; bin centre x ≈ 0.3337 → **0.3723**.
- **Counter-example table**: study 2's P(BD) 99.7% → **99.9%**.
- **Evidence base string** `96 万次（960 条件 × 1000）` → **`192 万次（1,920 条件 × 1000）`** (5 places);
  CI half-width reference 0.1299 → **0.0885** (= `part2.ci_width.median_half_width`); the
  layer-1 illustration 3.6% → **2.8%**.
- **Banner and footer** dated 2026-09-11 → **2026-09-30**, version `v1` → **`v1.1`**.

Verified cell by cell: 12/12 lookup rows match the JSON exactly; no v39-era value survives.
The file is byte-identical to the source project's copy (md5 `7d841a80…`), in both the Chinese
name and the ASCII alias.

### Postcode correction (ZIP)

The Anzhen Hospital Tongzhou Campus postcode was written as **101149** throughout. The hospital's
own site lists `No. 225 Songzhuang South 1st Street, Tongzhou District, Beijing 101118`
(Chaoyang Campus: 100029). Corrected to **101118** in:

- **7 qmd sources** — `manuscript/{manuscript_v40, manuscript_jama_v40, jama-V40-缩写版,
  manuscript_medarchive_v40, }.qmd` and `submission/{manuscript_jama_v40, jama-V40-投稿版,
  manuscript_medarchive_v40}.qmd`;
- **5 rendered DOCX** in `paper/` — `manuscript-JNO-V40.docx`, `jama-V40-缩写版.docx`,
  `manuscript_jama_v40.docx`, `manuscript_medarchive_v40.docx`, `manuscript_v40.docx`.

Each DOCX was rewritten with a byte-preserving zip re-pack (member order, compression method and
timestamps carried over); all five are now byte-identical to the corresponding files in the source
`Submit/` and `manuscript/` trees. `submission/Cover_Letter.txt` already read 101118 and was not
touched. The `legacy/` archive keeps the original 101149 spelling on purpose — see
`legacy/README.md`.
