# Bias Fraction (BF): Quantifying Systematic Bias in Observational Causal Estimates Using Negative Controls

> **Status:** Manuscript under review / in preparation for *JAMA Network Open* and a *medRxiv* preprint.
> Companion R package: [**biasratio**](https://github.com/zengzhechun/biasratio) — Bias-Effect Ratio (BER) implementation built on OHDSI EmpiricalCalibration.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Simulator](https://img.shields.io/badge/Simulator-Online-blue.svg)](https://zengzhechun.github.io/bias-fraction/)

## Overview

Observational comparative-effectiveness studies rest on the no-unmeasured-confounding
assumption. Negative-control calibration detects residual bias but traditionally returns only a
binary calibrated *p*-value — it does **not** say how large the bias is relative to the effect that
survives calibration. A calibrated estimate near the null could mean a genuinely null treatment
effect *or* an estimate overwhelmed by bias.

We propose the **Bias Fraction (BF)**, a bounded credibility metric derived from negative-control
calibration:

$$
\mathrm{BF} = \frac{|\hat{\mu}_B|}{|\hat{\mu}_B| + |\tilde{\psi}|}
= \frac{|\hat{\mu}_B|}{|\hat{\mu}_B| + |\hat{\psi}_{\text{obs}} - \hat{\mu}_B|}
$$

where $\hat{\mu}_B$ is the systematic bias estimated from negative controls (via the OHDSI
`EmpiricalCalibration` `fitNull` procedure) and $\tilde{\psi}$ is the bias-corrected (calibrated)
estimate. BF reports, on a bounded $[0,1]$ scale, **the share of the total calibrated signal
attributable to bias**. BF is a one-to-one transformation of the unbounded Bias-Effect Ratio
(BER): $\mathrm{BF} = \mathrm{BER}/(1+\mathrm{BER})$.

A **three-zone classification** summarizes the verdict:

| Zone | Rule | Interpretation |
|------|------|----------------|
| **Bias-dominated** | BF > 0.5 (CI lower > 0.5) | Bias accounts for > half of the calibrated signal |
| **Mixed** | 1/3 ≤ BF ≤ 0.5 (or CI crosses a boundary) | Bias and residual effect are comparable |
| **Effect-dominated** | BF < 1/3 (CI upper < 1/3) | Residual effect is at least twice the bias |

### Key results (from the manuscript)

- **Simulation (336 conditions, 200 repetitions each):** three-zone classification achieved
  **80.0%** bias-dominated and **95.1%** effect-dominated accuracy (41.8% in the mixed zone;
  overall 69.8%). OHDSI calibration held a 3.3% null-rejection rate.
- **Case study (MIMIC-IV, 14,677 hospitalized heart-failure patients; target trial emulation of
  β-blocker therapy vs 1-year all-cause mortality):** even though the study was designed under the
  **TARGET guideline** and analyzed with a **doubly robust TMLE** estimator, after calibration the
  bias-corrected β-blocker estimate was indistinguishable from the null
  (BF = 0.91 [95% CI, 0.74–0.99]) — *bias-dominated*. Guideline-directed medical therapy (GDMT)
  served as a known-effect comparison (BF = 0.43 [0.26–0.63]). This methodological demonstration
  does **not** establish that β-blockers are ineffective.

> **Take-home message:** methodological rigor (TARGET-guided design + state-of-the-art TMLE) alone
> cannot certify an observational estimate as credible. An empirical bias diagnostic is a necessary
> complement to best practice.

## Repository structure

| Path | Contents |
|------|----------|
| `R/` | Analysis configuration (`00_config.R`) and core BF/BER functions (`01_bsr_core.R`) |
| `analysis/` | R scripts — figure generation, simulation merge, BSR analysis, simulation worker |
| `manuscript/` | Full research-report source (Quarto `.qmd`) + references (BibTeX/CSL) |
| `submission/` | *JAMA Network Open* submission source (`.qmd`) + cover letter |
| `paper/` | Rendered manuscripts (DOCX): full report, supplementary, JAMA version, JAMA supplement |
| `figures/` | Aggregate figures (calibration, BF main, simulation heatmap, classification domains, LOO, QQ, bootstrap) + shared-bias DAG |
| `simulation/` | **Synthetic** 336-condition Monte-Carlo results (`.rds`) — fully reproducible, no patients |
| `tables/` | `table02_simulation_summary_v35.csv` — simulation summary (synthetic) |
| `simulator/` | Self-contained bilingual interactive explainer (HTML, no dependencies) |
| `index.html` | GitHub Pages entry point = the simulator (runs in any browser) |
| `CHANGELOG.md` | Revision log (v34 → v35, reviewer-driven) |
| `REVIEW.md` | Reviewer comments that motivated the v35 revision |

## Data availability & what is (and is not) in this repo

- **MIMIC-IV (v2.2)** and **MIMIC-IV-ECG (v1.0.1)** are available from PhysioNet
  ([mimiciv](https://physionet.org/content/mimiciv/),
  [mimic-iv-ecg](https://physionet.org/content/mimic-iv-ecg/1.0.1/)) to **credentialed users** who
  complete required training in human-subjects research.
- ⚠️ **This repository contains NO patient-level data and NO MIMIC-derived intermediate results.**
  The `output/data/` directory (patient-derived BSR/TMLE results) and the MIMIC case-study table
  (`table01`) are **intentionally excluded** to respect the PhysioNet data-use agreement.
- ✅ Only **synthetic simulation outputs** (`simulation/*.rds`, `tables/table02_*`) and aggregate
  figures/manuscripts are published, so the simulation study is fully reproducible from this repo.
- All analysis code is available at <https://github.com/zengzhechun/bias-fraction>.

## How to use / reproduce

### Interactive simulator (no install)
Open **<https://zengzhechun.github.io/bias-fraction/>** — a self-contained, bilingual
(简体中文 / English) interactive explainer that walks through the BF concept, the negative-control
calibration, the three-zone classification, and a live "lab" with the MIMIC case-study results.
Everything runs client-side; no server or dependencies required.

### Reproducing the analysis (R)

```r
# Requirements: R (>= 4.3) with EmpiricalCalibration, ggplot2, data.table, quarto
# 1) Case study (requires credentialed MIMIC-IV + rerunning the pipeline -> output/data/*.rds)
source("R/00_config.R"); source("R/01_bsr_core.R")
#    run analysis/run_bsr_analysis_v35.R  (reads credentialed MIMIC, writes output/data)
#    run analysis/generate_figures_v35.R  (renders figures/)

# 2) Simulation (fully synthetic — reproducible from the included .rds, no external data)
source("analysis/run_sim_worker_v35.R")   # one config; sweep ex_violation / n_nc
source("analysis/merge_sim_results_v35.R")# combine into simulation_merged_v35.rds
#    summary table -> tables/table02_simulation_summary_v35.csv

# Render manuscripts
quarto render manuscript/manuscript_v35.qmd        # full report
quarto render submission/manuscript_jama_v35.qmd   # JAMA version
```

> The case-study numbers in the simulator and manuscripts are aggregated estimates only; the
> underlying patient-level records are not distributed here.

## Relationship to the `biasratio` R package

The `biasratio` package (<https://github.com/zengzhechun/biasratio>) provides the reusable
`ber_*` implementation of the Bias-Effect Ratio and BF built on OHDSI EmpiricalCalibration. This
repository is the **application paper + interactive explainer** for the method; `biasratio` is the
**general-purpose software**. They share the same mathematical core (BF = BER/(1+BER)).

## License

Code is released under the **MIT License** (see [`LICENSE`](LICENSE)). The manuscript text and
figures are distributed under **CC-BY 4.0**, consistent with the intended *medRxiv* preprint.

## Citation

> Zeng Z, Wang J, Zuo H, Shu L. Quantifying Systematic Bias in Observational Causal Estimates
> Using Negative Controls: The Bias Fraction. *JAMA Network Open* (in preparation); preprint at
> medRxiv. Code: <https://github.com/zengzhechun/bias-fraction>.

## Acknowledgements

We thank the MIMIC-IV team for making the database available and the OHDSI / `EmpiricalCalibration`
developers for the empirical-calibration tools this work builds upon. AI tools were used for
manuscript editing and language polishing during revision; all content was critically reviewed by
the authors.

---
<details><summary>中文简介</summary>

本研究提出**偏倚分数（Bias Fraction, BF）**——一种基于阴性对照校准、有界 [0,1] 的实证可信度指标，
用于量化"经过校准后的观测性因果效应估计中，有多大比例来自系统性偏倚"。BF = BER/(1+BER)，
并配套"偏倚主导 / 混合 / 效应主导"三区分类。

本仓库包含论文源代码、图表、合成模拟结果，以及一个**无需安装、浏览器直接运行**的中英双语互动讲解器
（<https://zengzhechun.github.io/bias-fraction/>）。仓库**不含任何 MIMIC 患者级数据**，仅发布合成模拟输出与汇总结果，
配套 R 包为 [biasratio](https://github.com/zengzhechun/biasratio)。论文正在准备投稿 *JAMA Network Open* 并发布 *medRxiv* 预印本。
</details>
