# `legacy/` — superseded versions (v34–v39), kept for provenance

Everything here is **history**. Nothing in this directory is part of the current
release. The repo's live structure (root, `R/`, `manuscript/`, `paper/`,
`submission/`, `output/`, `logs/v40/`, `analysis/`, `simulation/`, `Target/`,
`docs/`, `figures/`) reflects **manuscript v40 only**.

These files were moved here on 2026-09-30 so that a reader following the main
README never lands on the previous version. Nothing was deleted: the move is
recorded in git and `git log --follow` still traces each file.

| Path | What it is |
|------|------------|
| `explainers/` | Superseded interactive explainers: the v37 BF simulator, and the v38 / v39 three-part explainers. The current one is `index.html` at the repo root (= `互动讲解器_v40_三部分结构.html`). |
| `manuscript/` | v35–v39 Quarto sources for all three tracks, plus `_render_v39_all.sh` (superseded by `_render_v40_all.sh`). |
| `paper/` | Rendered DOCX for v35–v39. Current renders live in `paper/`. |
| `submission/` | v35–v39 submission sources and the two 2026-09-05 cover-letter drafts. Current submission sources live in `submission/`. |
| `R/` | `18_v38_*` / `18_v39_*` / `19_v38_*` / `19_v39_*` analysis scripts, superseded by `18_v40_three_part_analysis.R` and `19_v40_explainer_data.R`. |
| `analysis/` | `v39_step1_ba_mcmc_2d_density.R`. |
| `simulation/` | `monitor_v39.sh`. |
| `tables_v38_v39/` | The v38 / v39 JSON + CSV result exports that used to sit in `output/tables/`. The single source of truth for the current release is `output/tables/v40_all_numbers.json`. |
| `figures_v38/`, `figures_v39/` | Figure directories that used to sit in `output/figures/`. The current figures are in `output/figures/v40/`. |
| `logs_v39/`, `logs_v39_from_v40/` | v39-round logs. `logs_v39_from_v40/` holds the 2026-09-11 logs that had been mixed into `logs/v40/`. Current logs are in `logs/v40/`. |
| `docs/` | The v39-round working documents, including `第39版_README.md` (the v39 directory guide). The current directory guide is `docs/第40版_README.md`. |
| `manuscript_v34/` | The whole v34 working tree. |
| `table02_simulation_summary_v35.csv` | v35 simulation summary. |

## Relationship to the current release

The metric was renamed **BF → BAF** (Bias Attribution Fraction) in the v39 round, and
the evidence base was rebuilt for v40: a **1,920,000-repetition** pooled factorial
simulation (primary grid plus a sign-flipped companion grid), a negative-control panel
refitted on the guideline-restricted exposure contrast, and a direction-regime analysis.
Numbers in v39-era files are therefore **not** comparable with v40 numbers, and the
v39 explainers state figures that the v40 manuscript no longer reports.

An archival script that performed this move is kept at
`manuscript/_archive_v39_to_legacy.py` in the source project (it defaults to a dry run).

## One deliberate inconsistency: the postcode

Everything under `legacy/` spells the Tongzhou Campus postcode as **101149**. That value is
wrong — the hospital's own site gives `No. 225 Songzhuang South 1st Street, Tongzhou District,
Beijing **101118**`. It has been corrected to 101118 in every **current (v40)** source and render.
The archived files were deliberately **left as they were originally submitted**, so that each
`legacy/` artefact stays byte-identical to the version it records. If you are reading a v34–v39
file and need the address, use 101118.
