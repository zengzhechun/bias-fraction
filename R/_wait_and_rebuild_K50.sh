#!/bin/bash
# ============================================================================
# Wait for the K = 50 simulation to finish, then rebuild everything downstream.
#
# The simulation (R/16_sim_v37p1_80grid.R) is already running in another
# process. This script only waits for it to exit, then hands off to
# _rebuild_after_K50.sh, which gates on the RDS actually holding 960
# conditions before touching anything.
# ============================================================================
BASE="/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/第38版"
cd "$BASE" || exit 1

PAT='Resources/bin/exec/R.*16_sim_v37p1_80grid'
echo "[$(date '+%Y-%m-%d %H:%M:%S')] waiting for the K=50 simulation to exit ..."

waited=0
while pgrep -f "$PAT" > /dev/null 2>&1; do
  sleep 30
  waited=$((waited + 30))
  if [ $((waited % 600)) -eq 0 ]; then
    echo "[$(date '+%H:%M:%S')] still running ($(tail -1 output/simulation/run_progress_v37p1.txt 2>/dev/null))"
  fi
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] simulation process exited."
sleep 5
echo "[$(date '+%H:%M:%S')] final progress line:"
tail -1 output/simulation/run_progress_v37p1.txt 2>/dev/null

echo
bash R/_rebuild_after_K50.sh
