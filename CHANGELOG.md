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

