# Bias Attribution Fraction (BAF): Quantifying Systematic Bias in Observational Causal Estimates Using Negative Controls

> **Status:** Manuscript in preparation for *JAMA Network Open* and a *medRxiv* preprint (manuscript **v40**).
> Companion R package: [**bafratio**](https://github.com/zengzhechun/bafratio) (v0.4.0) — BAF/BER implementation built on OHDSI `EmpiricalCalibration`.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Explainer v40](https://img.shields.io/badge/Explainer-v40-blue.svg)](https://zengzhechun.github.io/bias-fraction/)

## Overview

Observational comparative-effectiveness studies rest on the no-unmeasured-confounding
assumption. Negative-control calibration detects residual bias but traditionally returns only a
binary calibrated *p*-value. It does **not** say how large the bias is relative to the effect that
survives calibration. A calibrated estimate near the null could mean a genuinely null treatment
effect *or* an estimate overwhelmed by bias.

We propose the **Bias Attribution Fraction (BAF)**, together with its auxiliary unbounded form, the
**Bias-Effect Ratio (BER)**, as **new metrics introduced by this work**. They build on, but are
*not part of*, the pre-existing OHDSI empirical calibration framework (Schuemie et al., 2014/2018)
and its `EmpiricalCalibration` R package. They extend that framework from a binary significance
test to a bounded, continuous diagnostic:

$$
\mathrm{BAF} = \frac{|\hat{\mu}_B|}{|\hat{\mu}_B| + |\tilde{\psi}|}
= \frac{|\hat{\mu}_B|}{|\hat{\mu}_B| + |\hat{\psi}_{\text{obs}} - \hat{\mu}_B|}
$$

where $\hat{\mu}_B$ is the systematic bias estimated from negative controls (via the OHDSI
`EmpiricalCalibration` `fitNull` procedure) and $\tilde{\psi}$ is the bias-corrected (calibrated)
estimate. BAF reports, on a bounded $[0,1]$ scale, **the share of the total calibrated signal
attributable to bias**. It is a one-to-one transformation of BER: $\mathrm{BAF} = \mathrm{BER}/(1+\mathrm{BER})$.

A **three-zone classification** summarises the verdict:

| Zone | Rule | Interpretation |
|------|------|----------------|
| **Bias-dominated** | BAF > 0.5 (credible-interval lower bound > 0.5) | Bias accounts for more than half of the calibrated signal |
| **Mixed** | 1/3 ≤ BAF ≤ 0.5 (or the interval crosses a boundary) | Bias and residual effect are comparable |
| **Effect-dominated** | BAF < 1/3 (credible-interval upper bound < 1/3) | Residual effect is at least twice the bias |

Interval bounds are **credible** intervals: they propagate draws of $\hat{\mu}_B$ while holding
$\hat{\psi}_{\text{obs}}$ fixed, and therefore carry no frequentist coverage guarantee.

### Key results (v40)

- **Simulation — 1,920 conditions × 1,000 repetitions = 1,920,000 estimates.** The evidence base is
  a **pooled factorial design**: a primary grid (960 conditions) plus a **sign-flipped companion
  grid** (960 conditions, mirror-imaged bias centres) so that the diagnostic is evaluated under
  positive *and* negative confounding. Both grids share the same five factors (effect size, bias
  centre, target-estimate precision, number of negative controls, degree of exchangeability
  violation); the truth mix is 52.5% bias-dominated / 28.75% mixed / 18.75% effect-dominated.
  Adding BAF to the calibrated *P* value improved discrimination of bias-dominated estimates
  (**AUC 0.787 → 0.922**; likelihood-ratio χ² = 3835.1, df = 1, *P* < .001) and reduced the misuse
  rate (bias-dominated estimates wrongly declared usable) from **53.4% under an uncalibrated rule,
  or 36.0% under the calibrated *P* value alone, to 3.0%** under the full two-layer rule — at a
  yield of 22.1% of conditions declared usable.
- **Bias-direction regimes (new in v40).** Pooling the two grids isolates four regimes — inflation
  (960 conditions, coverage 71.1%), shrinkage (420, 46.9%), cancellation (36, 18.4%) and reversal
  (504, 36.1%). Point estimates stay stable across directions (|bias| ≤ 0.069), whereas interval
  coverage degrades under sign reversal; the three-zone classification is more robust than the
  interval. Full tables: `output/tables/v40_direction_regimes.csv`,
  `v40_direction_summary.csv`/`.json`.
- **Case study (MIMIC-IV; 15,053 hospitalisations screened, 376 excluded for death within the
  7-day grace period, **14,677** analysed; target trial emulation of β-blocker therapy vs 1-year
  all-cause mortality).** The study was designed under the **TARGET guideline** and analysed with
  a **doubly robust TMLE** estimator. After calibration the β-blocker estimate was
  indistinguishable from the null (**BAF = 0.87; 95% credible interval, 0.38 to 0.99**) and was
  labelled *not usable as effect evidence*. Guideline-directed medical therapy (GDMT) served as a
  known-effect comparison (**BAF = 0.46; 0.19 to 0.62**, *mixed / competitive*). Notably,
  **neither question cleared the first screening layer** (calibrated *P* = 0.894 and 0.103), so the
  calibrated *P* value alone would have licensed both. This methodological demonstration does
  **not** establish that β-blockers are ineffective.

> **Take-home message:** methodological rigour (TARGET-guided design plus a state-of-the-art TMLE)
> alone cannot certify an observational estimate as credible. An empirical bias diagnostic is a
> necessary complement to best practice.

### What changed since v39

| Item | v39 | **v40** |
|------|-----|---------|
| Evidence base | 960 conditions, 960,000 estimates | **1,920 conditions, 1,920,000 estimates** (primary + sign-flipped companion grid) |
| Primary metric wording | Bias Fraction (BF → BAF) | BAF throughout; package renamed `biasratio` → **`bafratio`** |
| Negative-control panel | exposure counted *all* β-blocker agents (mismatched with the target contrast) | **refitted on the guideline-restricted contrast**; bias SD 0.068 → 0.113 |
| GDMT calibrated *P* | 0.045 (cleared layer 1) | **0.103** (does not clear layer 1) |
| Agreement / discrimination | in-sample calibration on the primary grid | Bland–Altman agreement **and** discrimination recomputed on the pooled grid |
| Direction coverage | single (negative-μ_B) direction | **four bias-direction regimes** (§ above) |

Verdict labels are unchanged by the panel re-fit; the exposure-definition audit is documented in
`R/90_diag_nc_exposure_consistency.R` and `R/91_diag_matched_null_impact.R`, and the promotion of
the guideline-restricted panel lives in `R/92_promote_guideline_null.R` /
`R/93_promote_guideline_calibration.R`.

## Repository structure

Everything below the top level reflects **manuscript v40 only**; superseded v34–v39 material is
preserved under `legacy/` (see `legacy/README.md`).

| Path | Contents |
|------|----------|
| `R/` | Full analysis pipeline, `00_config.R` through `29_gdmt_missing_sensitivity.R`, plus the v40 diagnostic/promotion scripts `90_diag_nc_exposure_consistency.R`, `91_diag_matched_null_impact.R`, `92_promote_guideline_null.R`, `93_promote_guideline_calibration.R`, `94_negative_control_screening_audit.R`, `95_ejection_fraction_proxy_sensitivity.R`, `96_mirror_mu_regimes.R`, `97_direction_regimes_summary.R`, `98_redraw_case_and_gap_figures.R`. `01_bsr_core.R` holds the core BAF/BER functions; `16_sim_v37p1_80grid.R` builds the factorial grid; **`18_v40_three_part_analysis.R` produces every number reported in v40**; **`19_v40_explainer_data.R` rebuilds the explainer payload**; `27`–`29` are the validation analyses (lookup-table hold-out, interval joint propagation, GDMT missing-exposure sensitivity) |
| `manuscript/` | Quarto sources for all three v40 tracks (JAMA / medRxiv / full working report), references (BibTeX/CSL), the v40 sync helper `_sync_v40_to_github.py`, and the DOCX post-processing scripts (`_post_*.py`, `_audit_*.py`, `_word_count_jama.py`, `_render_v40_all.sh`) |
| `submission/` | *JAMA Network Open* and *medRxiv* submission sources (`.qmd`), the cover letter, CSL and BibTeX. JAMA letters are numbered in upload order (`Cover_Letter.txt` = 01, main manuscript = 02, supplement = 03) |
| `paper/` | Rendered manuscripts (DOCX) for all three v40 tracks, main text and supplement, including the submission-ready `manuscript-JNO-V40.docx` and `supplementary-JNO_v40.docx` |
| `output/tables/` | **`v40_all_numbers.json` is the single source of truth for every number in the manuscript**, plus the per-section exports (`v40_part1/2/3_*`, `v40_dual_view_*`, `v40_part2_reliability_lookup.csv`, `v40_part3_case_verdicts.csv`, `v40_direction_*`, negative-control and guideline-promotion diagnostics) |
| `output/figures/` | Publication figures: **`v40/`** (all current main-text and supplement panels) and `continuous_bf/` (legacy continuity assets) |
| `analysis/` | Standalone analysis scripts (Bland–Altman MCMC / 2-D density step) |
| `simulation/` | Monte-Carlo **synthetic** results and scripts — fully reproducible, no patients. The large `.rds` objects are git-ignored; see *Data availability* |
| `Target/` | TARGET guideline compliance materials (reporting checklist, flow diagram, table) |
| `figures/` | Earlier aggregate figures (calibration, simulation heatmap, classification domains, LOO, QQ, bootstrap) kept for provenance |
| `docs/` | `第40版_README.md` — the v40 directory guide |
| `logs/v40/` | Render and diagnostic logs for the v40 build |
| `index.html` | **GitHub Pages entry point = the v40 interactive explainer** (runs in any browser) |
| `explainer_v40.html` | ASCII-named copy of the v40 explainer, for stable URL references |
| `互动讲解器_v40_三部分结构.html` | v40 explainer under its working filename, organised as the manuscript's three parts (agreement / screening / case studies) |
| `algorithm_walkthrough_zh.html` | Plain-language algorithm walkthrough for clinical readers (Chinese) |
| `算法说明_临床版_v1.html` | Same walkthrough under its working filename |
| `legacy/` | Superseded v34–v39 sources, renders, tables, figures, logs and explainers — see `legacy/README.md` |
| `CHANGELOG.md` | Revision log |
| `REVIEW.md` | Reviewer comments that motivated the v35 revision |

## Data availability & what is (and is not) in this repo

- **MIMIC-IV (v2.2)** and **MIMIC-IV-ECG (v1.0)** are available from PhysioNet
  ([mimiciv](https://physionet.org/content/mimiciv/),
  [mimic-iv-ecg](https://physionet.org/content/mimic-iv-ecg/1.0/)) to **credentialed users** who
  complete the required human-subjects training.
- ⚠️ **This repository contains no patient-level data.** The row-level LTMLE analysis frames
  (`DATA/*.rds`) are **not** distributed here, and neither are the large simulation objects in
  `simulation/` (tens of megabytes: `v40_ba_gibbs_reps.rds`, `v40_interval_joint_reps.rds`,
  `v40_comparison_results*.rds`, `v40_sim_frame*.rds` — regenerate with `R/16`, `R/18`, `R/27`–`R/29`).
  Three small derived objects **are** committed: `v40_lookup_holdout.rds`,
  `v40_gdmt_missing_sensitivity.rds`, `v40_ba_gibbs_stats.rds`.
- ✅ Published here: **aggregate result tables** (including the MIMIC case-study aggregates such as
  `baseline_table1.csv`, `table01_BAF_results.csv`, `v40_part3_case_verdicts.csv`, and
  `v40_all_numbers.json`), **synthetic simulation outputs**, all analysis code, and the rendered
  manuscripts. The simulation study is fully reproducible from the included objects.

## How to use / reproduce

### Interactive explainer (no install)

**BAF v40 interactive explainer (latest):** <https://zengzhechun.github.io/bias-fraction/>
· stable alias: <https://zengzhechun.github.io/bias-fraction/explainer_v40.html>

A self-contained, bilingual (简体中文 / English) explainer for manuscript v40, organised as the
manuscript's three parts: (1) how closely BAF tracks the truth, assessed by Bland–Altman
agreement; (2) the two-layer screening rule that turns BAF into a verdict, with its 12-bucket
lookup table; (3) the two MIMIC-IV case studies, plus a bias-direction section. It covers the BAF
concept, negative-control calibration, the three-zone classification, the 1,920-condition
(1,920,000-estimate) pooled simulation, and a live lab carrying the case-study results. Everything
runs client-side in the browser. Only MathJax, used for formula rendering, is loaded from a CDN, so
an internet connection is needed for the equations to display.

**[Algorithm walkthrough for clinical readers](https://zengzhechun.github.io/bias-fraction/algorithm_walkthrough_zh.html)**
is a shorter Chinese-language walkthrough with no external dependencies at all. (The Chinese-named
originals — `互动讲解器_v40_三部分结构.html` and `算法说明_临床版_v1.html` — are also served by
Pages; the ASCII aliases above are preferred for linking.)

> Links to the explainers must use the absolute `https://zengzhechun.github.io/...` form. A relative
> link such as `algorithm_walkthrough_zh.html` opens GitHub's *blob* view and shows **source code**
> rather than the rendered page.

### Reproducing the analysis (R)

```r
# Requirements: R (>= 4.3) with EmpiricalCalibration, ggplot2, data.table, quarto
# 1) Simulation (fully synthetic; reproducible from the included objects)
source("R/16_sim_v37p1_80grid.R")            # builds the 960-condition primary grid
source("R/96_mirror_mu_regimes.R")           # builds the sign-flipped companion grid
source("R/18_v40_three_part_analysis.R")     # writes output/tables/v40_all_numbers.json
source("R/19_v40_explainer_data.R")          # writes output/tables/v40_explainer_data.json
source("R/97_direction_regimes_summary.R")   # bias-direction regime tables
source("R/27_lookup_holdout.R")              # lookup-table hold-out validation
source("R/28_interval_joint_propagation.R")  # interval joint propagation
source("R/29_gdmt_missing_sensitivity.R")    # GDMT missing-exposure sensitivity

# 2) Case study (requires credentialed MIMIC-IV; row-level frames are not distributed)
source("R/00_config.R"); source("R/01_bsr_core.R")
#    then rerun the LTMLE pipeline to regenerate output/data/*.rds
source("R/90_diag_nc_exposure_consistency.R")  # negative-control exposure consistency
source("R/91_diag_matched_null_impact.R")      # impact of a matched panel (self-checking)
source("R/92_promote_guideline_null.R")        # promote the guideline-restricted panel
source("R/93_promote_guideline_calibration.R") # recalibrate the promoted panel
source("R/94_negative_control_screening_audit.R")
source("R/95_ejection_fraction_proxy_sensitivity.R")

# Render manuscripts
quarto render manuscript/manuscript_v40.qmd             # full working report
quarto render manuscript/manuscript_jama_v40.qmd        # JAMA version
quarto render manuscript/manuscript_medarchive_v40.qmd  # medRxiv version
```

> The case-study numbers in the explainer and manuscripts are **aggregate estimates** only; the
> underlying patient-level records are not distributed here.

### Key result tables

| File | What it holds |
|------|---------------|
| `output/tables/v40_all_numbers.json` | Every number in the manuscript (design, part 1/2/3) |
| `output/tables/v40_part1_bland_altman.csv` | Agreement: bias, LoA, CCC, slope (interior & full) |
| `output/tables/v40_part2_discrimination.csv` | AUC for calibrated *P*, BAF̂, BAF̂ + half-width, + calibrated *P* |
| `output/tables/v40_part2_strategy_comparison.csv` | Yield / misuse for R0–R4 and BAF-only comparators C1–C2 |
| `output/tables/v40_part2_reliability_lookup.csv` | The 12-bucket BAF lookup table |
| `output/tables/v40_part2_subgroups.csv` | Performance by number of negative controls (K = 12 / 25 / 50) |
| `output/tables/v40_part3_case_verdicts.csv` | β-blocker and GDMT case results and verdicts |
| `output/tables/v40_direction_summary.csv` | Bias-direction regimes: inflation / shrinkage / cancellation / reversal |

Selected pooled-grid figures (`output/tables/`, same values as the manuscript):

| Rule | Declared usable | Bias-dominated among declared |
|------|-----------------|------------------------------|
| R0 — uncalibrated *P* < .05 (no bias correction) | 67.7% | 53.4% |
| R1 — calibrated *P* < .05 (layer 1 only) | 61.8% | 36.0% |
| R2 — R1 + BAF point estimate < 0.5 | 44.2% | 16.5% |
| R3 — R1 + whole BAF credible interval < 0.5 | 35.5% | 10.2% |
| **R4 — R1 + calibrated-probability verdict (full two-layer)** | **22.1%** | **3.0%** |
| C1 — BAF point estimate alone | 51.3% | 18.7% |
| C2 — whole BAF credible interval < 0.5, alone | 38.7% | 11.0% |

| Bias-direction regime | Conditions | Coverage | Zone match | Misuse under R3 |
|-----------------------|-----------|----------|-----------|-----------------|
| Inflation | 960 | 71.1% | 53.1% | 7.4% |
| Shrinkage | 420 | 46.9% | 42.5% | 0% |
| Cancellation | 36 | 18.4% | 18.4% | 0% |
| Reversal | 504 | 36.1% | 84.3% | 100% |

## Relationship to the `bafratio` R package

The [`bafratio`](https://github.com/zengzhechun/bafratio) package (v0.4.0) provides the reusable
implementation of BAF and BER on top of OHDSI `EmpiricalCalibration` (public functions are
`baf_*`; `ber_classify()` and the `$ber` field name are intentionally unchanged). This repository
is the **application paper plus interactive explainer** for the method; `bafratio` is the
**general-purpose software**. They share the same mathematical core (BAF = BER/(1+BER)).

> Terminology note: the metric was called the *Bias Fraction* (**BF**) up to v38 and was renamed
> **Bias Attribution Fraction (BAF)** in v39, to avoid collision with the Bayes factor (the package
> was renamed `biasratio` → `bafratio` in the same round). All v39-and-later files use BAF; earlier
> versions retained under `legacy/` keep BF as published. Lowercase `bf` survives only as an
> internal code identifier (`baf_classify()` internals, `$ber`).

## License

Code is released under the **MIT License** (see [`LICENSE`](LICENSE)). The manuscript text and
figures are distributed under **CC-BY 4.0**, consistent with the intended *medRxiv* preprint.

## Citation

> Zeng Z, Wang J, Zuo H, Shu L. Quantifying Systematic Bias in Observational Causal Estimates: The
> Bias Attribution Fraction. *JAMA Network Open* (in preparation); preprint at medRxiv. Code:
> <https://github.com/zengzhechun/bias-fraction>.

## Acknowledgements

We thank the MIMIC-IV team for making the database available and the OHDSI /
`EmpiricalCalibration` developers for the empirical-calibration tools this work builds upon. AI
tools were used for manuscript editing and language polishing during revision; all content was
critically reviewed by the authors.

---
<details><summary>中文简介</summary>

本研究提出**偏倚分数（Bias Attribution Fraction, BAF）**：一种基于阴性对照校准、有界 [0,1] 的实证可信度指标，
用于量化「经过校准后的观测性因果效应估计中，有多大比例来自系统性偏倚」。BAF = BER/(1+BER)，
并配套「偏倚主导 / 混合 / 效应主导」三区分类。指标在 v39 由 Bias Fraction（BF）更名为 Bias Attribution Fraction，
以避免与贝叶斯因子（Bayes factor）混淆；配套 R 包亦由 `biasratio` 更名为 [`bafratio`](https://github.com/zengzhechun/bafratio)（v0.4.0）。

**证据基础（v40）** 为**合并池设计**：主网格 960 个条件 + 符号翻转的镜像网格 960 个条件，各 1000 次重复，
共 **1,920 个条件 / 192 万次估计**（真值构成：偏倚主导 52.5%、混合 28.75%、效应主导 18.75%）。
把 BAF 加入校准 p 值后，判别力由 AUC 0.787 提升到 **0.922**；误用率（把偏倚主导误判为可用）由
未校准规则的 53.4%、单用校准 p 值的 36.0% 降到 **3.0%**（全两层规则，可用率 22.1%）。

**偏倚方向分析（v40 新增）** 把两个网格合起来拆成四种角色：膨胀（960 个条件，覆盖率 71.1%）、
收缩（420，46.9%）、抵消（36，18.4%）、反转（504，36.1%）。点估计跨方向稳定（|偏差| ≤ 0.069），
区间覆盖率在反向时明显下降，而三档分类比区间稳健。

**案例研究** 使用 MIMIC-IV：15,053 例进入评估，376 例因 7 天宽限期内死亡被排除，
**14,677 例**进入分析（β 受体阻滞剂与 1 年全因死亡），研究按 **TARGET 指南**设计、用**双稳健 TMLE** 估计。
经校准后 β 阻滞剂估计为 **BAF = 0.87（95% 可信区间 0.38–0.99）**，判为「不可作效应证据」；
指南导向药物治疗（GDMT）作为已知效应对照，**BAF = 0.46（0.19–0.62）**。
值得注意的是，**两个问题都没有通过第一层筛检**（校准 p 值 0.894 与 0.103），
即单看校准 p 值会把两者都放行。本研究**不**主张 β 受体阻滞剂无效。

本仓库包含论文源代码、图表、合成模拟结果，以及一个**无需安装、浏览器直接运行**的中英双语互动讲解器
（<https://zengzhechun.github.io/bias-fraction/>，稳定别名 `explainer_v40.html`；另有面向临床读者的
[算法说明](https://zengzhechun.github.io/bias-fraction/algorithm_walkthrough_zh.html)）。
仓库**不含任何 MIMIC 患者级数据**，仅发布汇总结果与合成模拟输出；v34–v39 的旧版本材料统一移至 `legacy/`。
论文正在准备投稿 *JAMA Network Open* 并发布 *medRxiv* 预印本。
</details>
