#!/bin/bash
# ============================================================================
# v38b downstream rebuild after adding the K = 50 negative-control tier.
#
# The simulation itself (R/16_sim_v37p1_80grid.R) must have finished first:
# output/simulation/comparison_results_v37p1.rds must hold 960 conditions.
#
# Order matters: 18 writes v38_all_numbers.json, and 20 reads it back, so 18
# has to run first. The Bland-Altman script (analysis/) reads the RDS directly
# and is independent of the JSON.
#
# Usage:  bash R/_rebuild_after_K50.sh
# ============================================================================
set -u
BASE="/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/第38版"
cd "$BASE" || exit 1

RDS="output/simulation/comparison_results_v37p1.rds"
STAMP=$(date +%Y%m%d_%H%M)
LOGDIR="logs"; mkdir -p "$LOGDIR"

echo "============================================================"
echo " v38b downstream rebuild  (K = 50 tier)"
echo " started: $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"

# --- gate: refuse to run unless the simulation really has 960 conditions -----
N=$(Rscript -e "cat(length(readRDS('$RDS')))" 2>/dev/null | tail -1)
echo "conditions in $RDS : $N"
if [ "$N" != "960" ]; then
  echo "ABORT: expected 960 conditions, found '$N'."
  echo "       Finish the K = 50 simulation run first (R/16_sim_v37p1_80grid.R)."
  exit 1
fi

run () {
  local name="$1"; shift
  echo "------------------------------------------------------------"
  echo "[$(date '+%H:%M:%S')] $name"
  echo "------------------------------------------------------------"
  if "$@" > "$LOGDIR/${STAMP}_${name}.log" 2>&1; then
    echo "   OK  (log: $LOGDIR/${STAMP}_${name}.log)"
  else
    echo "   FAILED (log: $LOGDIR/${STAMP}_${name}.log)"
    tail -20 "$LOGDIR/${STAMP}_${name}.log"
    exit 1
  fi
}

# 1) master numbers + CSVs + Part II figures (writes v38_all_numbers.json)
run "18_three_part" Rscript R/18_v38_three_part_analysis.R

# 2) Bland-Altman tri-panel, true-BF view (Figure 1)
run "ba_mcmc_2d"    Rscript analysis/v38_step1_ba_mcmc_2d_density.R

# 3) ROC paper figure (Figure 2) - reads the JSON written by step 1
run "20_roc_paper"  Rscript R/20_roc_paper_fig.R

# 4) Youden thresholds / operating points feeding Table 2
run "21_youden"     Rscript R/21_youden_thresholds.R

echo "============================================================"
echo " downstream rebuild complete: $(date '+%Y-%m-%d %H:%M:%S')"
echo " Next (manual): refresh the figure/table numbers hard-coded in"
echo "   manuscript/manuscript_jama_v38.qmd  (Fig 1, Fig 2, Table 2 captions)"
echo " then render with:  quarto render manuscript_jama_v38.qmd --to docx"
echo " and re-apply:      python3 manuscript/_post_bold_abstract.py"
echo "============================================================"
