# Bias Attribution Fraction (BAF): Quantifying Systematic Bias in Observational Causal Estimates Using Negative Controls

> **Status:** Manuscript in preparation for *JAMA Network Open* and a *medRxiv* preprint.
> Companion R package: [**biasratio**](https://github.com/zengzhechun/biasratio) (v0.3.1) — BAF/BER implementation built on OHDSI `EmpiricalCalibration`.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Explainer v39](https://img.shields.io/badge/Explainer-v39-blue.svg)](https://zengzhechun.github.io/bias-fraction/)

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

### Key results (from the manuscript)

- **Simulation (960 conditions, 1,000 repetitions each; 960,000 total).** The five-factor design
  crosses effect size, bias centre, target-estimate precision, number of negative controls, and
  the degree of exchangeability violation. Adding BAF to the calibrated *P* value improved
  discrimination of bias-dominated estimates (**AUC 0.787 → 0.918**) and reduced the misuse rate
  (bias-dominated estimates wrongly declared usable) from **36.0% to 2.9%**.
- **Case study (MIMIC-IV; 15,053 hospitalisations assessed, 376 excluded for death within the
  7-day grace period, 14,677 analysed; target trial emulation of β-blocker therapy vs 1-year
  all-cause mortality).** The study was designed under the **TARGET guideline** and analysed with
  a **doubly robust TMLE** estimator. After calibration the β-blocker estimate was
  indistinguishable from the null (**BAF = 0.91; 95% credible interval, 0.74 to 0.99**) and was
  labelled *not usable as effect evidence*. Guideline-directed medical therapy (GDMT) served as a
  known-effect comparison (**BAF = 0.51; 0.36 to 0.60**, *competitive, no verdict*). This
  methodological demonstration does **not** establish that β-blockers are ineffective.

> **Take-home message:** methodological rigour (TARGET-guided design plus a state-of-the-art TMLE)
> alone cannot certify an observational estimate as credible. An empirical bias diagnostic is a
> necessary complement to best practice.

### Known limitation carried in the manuscript

The 12 negative controls were fitted on a cohort in which exposure counts **all** β-blocker
agents, whereas the target estimates use the guideline-restricted definition (carvedilol,
metoprolol succinate, or bisoprolol at ≥50% of the target dose). Refitting the panel to match the
target cohort widens the bias standard error (0.068 → 0.113) and moves the GDMT calibrated
*P* value from 0.045 to 0.103, so GDMT would no longer clear the first screening layer. **Both
verdict labels are unchanged.** The disclosure is written into the manuscript, and the diagnostic
scripts are `R/90_diag_nc_exposure_consistency.R` and `R/91_diag_matched_null_impact.R`.

## Repository structure

| Path | Contents |
|------|----------|
| `R/` | Full analysis pipeline, `00_config.R` through `29_gdmt_missing_sensitivity.R`, plus `90_diag_nc_exposure_consistency.R` and `91_diag_matched_null_impact.R`. `01_bsr_core.R` holds the core BAF/BER functions; `16_sim_v37p1_80grid.R` builds the 960-condition grid; `18_v39_three_part_analysis.R` produces every number reported in v39; `27`–`29` are the v39 validation analyses (lookup-table hold-out, interval joint propagation, GDMT missing-exposure sensitivity) |
| `manuscript/` | Quarto sources for all three v39 tracks (JAMA / medRxiv / full working report), references (BibTeX/CSL), and the DOCX post-processing scripts (`_post_*.py`, `_audit_*.py`, `_word_count_jama.py`, `_render_v39_all.sh`) |
| `submission/` | *JAMA Network Open* and *medRxiv* submission sources (`.qmd`), cover letters, CSL and BibTeX |
| `paper/` | Rendered manuscripts (DOCX) for all three v39 tracks, main text and supplement |
| `output/tables/` | **`v39_all_numbers.json` is the single source of truth for every number in the manuscript**, plus the per-section CSV exports (`v39_part1/2/3_*`, dual-view ROC, lookup table, case verdicts, negative-control diagnostics) |
| `output/figures/` | Publication figures: `v39/` (main text) and `continuous_bf/` (supplement) |
| `analysis/` | Earlier standalone scripts, including `v39_step1_ba_mcmc_2d_density.R` |
| `simulation/` | Monte-Carlo **synthetic** results and scripts — fully reproducible, no patients |
| `Target/` | TARGET guideline compliance materials (reporting checklist, flow diagram, table) |
| `figures/` | Earlier aggregate figures (calibration, simulation heatmap, classification domains, LOO, QQ, bootstrap) |
| `docs/` | Working documents: the v39 change list, the `biasratio` consistency audit, and the naming note that records why the metric is called BAF rather than BF |
| `logs/v39/` | Render and diagnostic logs for the v39 build |
| `index.html` | GitHub Pages entry point = the **v39** interactive explainer (runs in any browser) |
| `互动讲解器_v39_三部分结构.html` | v39 explainer under its working filename, organised as the manuscript's three parts (agreement / screening / case studies) |
| `互动讲解器_v38_三部分结构.html` | Superseded v38 explainer, kept for provenance |
| `互动讲解器_BF_simulator_v37.html` | Earlier self-contained explainer (internal name retained for link stability) |
| `算法说明_临床版_v1.html` | Plain-language algorithm walkthrough written for clinical readers |
| `CHANGELOG.md` | Revision log |
| `REVIEW.md` | Reviewer comments that motivated the v35 revision |

## Data availability & what is (and is not) in this repo

- **MIMIC-IV (v2.2)** and **MIMIC-IV-ECG (v1.0.1)** are available from PhysioNet
  ([mimiciv](https://physionet.org/content/mimiciv/),
  [mimic-iv-ecg](https://physionet.org/content/mimic-iv-ecg/1.0.1/)) to **credentialed users** who
  complete the required human-subjects training.
- ⚠️ **This repository contains no patient-level data.** The row-level LTMLE analysis frames
  (`DATA/*.rds`) are **not** distributed here, and neither are the large simulation objects in
  `output/simulation/` (tens of megabytes; regenerate with `R/16`, `R/27`–`R/29`).
- ✅ Published here: **aggregate result tables** (including the MIMIC case-study aggregates such as
  `baseline_table1.csv`, `table01_BAF_results.csv`, `v39_part3_case_verdicts.csv`, and
  `v39_all_numbers.json`), **synthetic simulation outputs**, all analysis code, and the rendered
  manuscripts. The simulation study is fully reproducible from the included objects.

## How to use / reproduce

### Interactive explainer (no install)

**BAF v39 interactive explainer (latest):** <https://zengzhechun.github.io/bias-fraction/>

A self-contained, bilingual (简体中文 / English) explainer for manuscript v39, organised as the
manuscript's three parts: (1) how closely BAF tracks the truth, assessed by Bland-Altman
agreement; (2) the two-layer screening rule that turns BAF into a verdict, with its 12-bucket
lookup table; (3) the two MIMIC-IV case studies. It covers the BAF concept, negative-control
calibration, the three-zone classification, the 960-condition (960,000-repetition) simulation, and
a live lab carrying the case-study results. Everything runs client-side in the browser. Only
MathJax, used for formula rendering, is loaded from a CDN, so an internet connection is needed for
the equations to display. **[`算法说明_临床版_v1.html`](算法说明_临床版_v1.html)** is a shorter
clinical-facing walkthrough with no external dependencies at all.

### Reproducing the analysis (R)

```r
# Requirements: R (>= 4.3) with EmpiricalCalibration, ggplot2, data.table, quarto
# 1) Simulation (fully synthetic; reproducible from the included objects)
source("R/16_sim_v37p1_80grid.R")          # builds the 960-condition factorial grid
source("R/18_v39_three_part_analysis.R")   # produces output/tables/v39_all_numbers.json
source("R/27_lookup_holdout.R")            # lookup-table hold-out validation
source("R/28_interval_joint_propagation.R")# interval joint propagation
source("R/29_gdmt_missing_sensitivity.R")  # GDMT missing-exposure sensitivity

# 2) Case study (requires credentialed MIMIC-IV; row-level frames are not distributed)
source("R/00_config.R"); source("R/01_bsr_core.R")
#    then rerun the LTMLE pipeline to regenerate output/data/*.rds
source("R/90_diag_nc_exposure_consistency.R")  # negative-control exposure consistency
source("R/91_diag_matched_null_impact.R")      # impact of a matched panel (self-checking)

# Render manuscripts
quarto render manuscript/manuscript_v39.qmd             # full working report
quarto render manuscript/manuscript_jama_v39.qmd        # JAMA version
quarto render manuscript/manuscript_medarchive_v39.qmd  # medRxiv version
```

> The case-study numbers in the explainer and manuscripts are **aggregate estimates** only; the
> underlying patient-level records are not distributed here.

## Relationship to the `biasratio` R package

The [`biasratio`](https://github.com/zengzhechun/biasratio) package (v0.3.1) provides the reusable
implementation of BAF and BER on top of OHDSI `EmpiricalCalibration`. This repository is the
**application paper plus interactive explainer** for the method; `biasratio` is the
**general-purpose software**. They share the same mathematical core (BAF = BER/(1+BER)).

> Terminology note: the metric was called the *Bias Fraction* (BF) up to v38 and was renamed
> **Bias Attribution Fraction (BAF)** in v39, to avoid collision with the Bayes factor. All
> files from v39 onward use BAF; earlier versions retain BF as published. Lowercase `bf` remains
> an internal code identifier (`bf_classify()`, `bf_rules()`) and is intentionally unchanged.

## License

Code is released under the **MIT License** (see [`LICENSE`](LICENSE)). The manuscript text and
figures are distributed under **CC-BY 4.0**, consistent with the intended *medRxiv* preprint.

## Citation

> Zeng Z, Wang J, Zuo H, Shu L. Quantifying Systematic Bias in Observational Causal Estimates
> Using Negative Controls: The Bias Attribution Fraction. *JAMA Network Open* (in preparation);
> preprint at medRxiv. Code: <https://github.com/zengzhechun/bias-fraction>.

## Acknowledgements

We thank the MIMIC-IV team for making the database available and the OHDSI /
`EmpiricalCalibration` developers for the empirical-calibration tools this work builds upon. AI
tools were used for manuscript editing and language polishing during revision; all content was
critically reviewed by the authors.

---
<details><summary>中文简介</summary>

本研究提出**偏倚分数（Bias Attribution Fraction, BAF）**：一种基于阴性对照校准、有界 [0,1] 的实证可信度指标，
用于量化「经过校准后的观测性因果效应估计中，有多大比例来自系统性偏倚」。BAF = BER/(1+BER)，
并配套「偏倚主导 / 混合 / 效应主导」三区分类。指标在 v39 由 Bias Fraction 更名为 Bias Attribution Fraction，
以避免与贝叶斯因子（Bayes factor）混淆。

模拟研究为 960 个条件 × 1000 次重复（共 96 万次）。把 BAF 加入校准 p 值后，判别力由 AUC 0.787 提升到 0.918，
误用率由 36.0% 降到 2.9%。案例研究使用 MIMIC-IV：15,053 例进入评估，376 例因 7 天宽限期内死亡被排除，
14,677 例进入分析（β 受体阻滞剂与 1 年全因死亡）。经校准后 β 阻滞剂估计为 BAF = 0.91（95% 可信区间 0.74–0.99），
判为「不可作效应证据」；指南导向药物治疗（GDMT）作为已知效应对照，BAF = 0.51（0.36–0.60）。

本仓库包含论文源代码、图表、合成模拟结果，以及一个**无需安装、浏览器直接运行**的中英双语互动讲解器
（<https://zengzhechun.github.io/bias-fraction/>）。仓库**不含任何 MIMIC 患者级数据**，仅发布汇总结果与合成模拟输出，
配套 R 包为 [biasratio](https://github.com/zengzhechun/biasratio)（v0.3.1）。论文正在准备投稿 *JAMA Network Open* 并发布 *medRxiv* 预印本。
</details>
