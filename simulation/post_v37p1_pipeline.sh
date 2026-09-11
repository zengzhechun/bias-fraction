#!/bin/bash
# post_v37p1_pipeline.sh
# Triggered by monitor_v37p1.sh when the 80-cell simulation reports COMPLETE.
# 1) rename v39 artifacts -> 37.1 (unifies version label with the manuscript_v37 dir)
# 2) regenerate all figure/analysis outputs from the 37.1 (640-condition) data
# R/03 (HTML explainer injection) is handled manually by the agent (preserves 3D edits).
PROJ="/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/manuscript_v37"
SIM="$PROJ/output/simulation"
RS="/usr/local/bin/Rscript"
LOG="$SIM/v37p1_pipeline.log"

cd "$PROJ" || exit 1
echo "[pipeline $(date '+%Y-%m-%d %H:%M:%S')] START: rename v39 -> v37p1" >> "$LOG"

mv -f "$SIM/comparison_results_v39.rds" "$SIM/comparison_results_v37p1.rds"
mv -f "$SIM/comparison_agg_v39.rds"     "$SIM/comparison_agg_v37p1.rds"
mv -f "$SIM/comparison_agg_v39.json"    "$SIM/comparison_agg_v37p1.json"
mv -f "$SIM/diag_mc_v39.rds"           "$SIM/diag_mc_v37p1.rds"
mv -f "$SIM/diag_mcmc_v39.rds"         "$SIM/diag_mcmc_v37p1.rds"
mv -f "$SIM/run_progress_v39.txt"      "$SIM/run_progress_v37p1.txt" 2>/dev/null
mv -f "$SIM/v39_run.log"               "$SIM/v37p1_run.log" 2>/dev/null
echo "[pipeline $(date '+%Y-%m-%d %H:%M:%S')] renamed. regenerating figures..." >> "$LOG"

for f in R/04_continuous_bf_analysis.R R/05_bf_calibration_scatter.R R/06_bland_altman.R R/07_bf_3d_distribution.R R/08_trim_sensitivity.R R/09_interior_ba_viz.R R/10_ba_full_viz.R R/12_build_sim_frame.R R/13_clinical_ba_viz.R R/14_pivot_data_export.R R/03_inject_explainer.R; do
  echo "[pipeline $(date '+%Y-%m-%d %H:%M:%S')] >>> $f" >> "$LOG"
  "$RS" "$PROJ/$f" >> "$LOG" 2>&1
  echo "[pipeline $(date '+%Y-%m-%d %H:%M:%S')] <<< $f exit=$?" >> "$LOG"
done
echo "[pipeline $(date '+%Y-%m-%d %H:%M:%S')] FIGURES + HTML-DATA DONE (docx CN/EN text sync handled manually by agent)" >> "$LOG"
