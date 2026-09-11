#!/bin/bash
# monitor_v37p1.sh
# Self-polling monitor (every 300s) for the 80-cell simulation.
# - keeps the sim alive (relaunches via the v39-writer script if it dies, so it
#   resumes into comparison_results_v39.rds which matches the in-progress file)
# - on COMPLETE, runs post_v37p1_pipeline.sh (rename v39->37.1 + regenerate figures)
PROJ="/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/manuscript_v37"
SIM="$PROJ/output/simulation"
PROG="$SIM/run_progress_v39.txt"
LOG="$SIM/v37p1_monitor.log"
RSCRIPT="/usr/local/bin/Rscript"
SIM_SCRIPT="$PROJ/R/16_sim_v39_80grid.R.bak"   # v39-writer: resumes into comparison_results_v39.rds
PIPELINE="$SIM/post_v37p1_pipeline.sh"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] MONITOR v37p1 started (interval=300s)" >> "$LOG"

while true; do
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  if grep -q "COMPLETE" "$PROG" 2>/dev/null; then
    echo "[$ts] MONITOR: simulation COMPLETE. Launching post-v37p1 pipeline." >> "$LOG"
    bash "$PIPELINE" >> "$LOG" 2>&1
    echo "[$ts] MONITOR: pipeline finished. Stopping monitor." >> "$LOG"
    break
  fi
  if ! pgrep -fl "16_sim_v39_80grid" > /dev/null; then
    echo "[$ts] MONITOR: sim DEAD, relaunching via v39-writer script..." >> "$LOG"
    cd "$PROJ" && nohup "$RSCRIPT" "$SIM_SCRIPT" > "$SIM/v39_run.log" 2>&1 & disown
    sleep 6
    if pgrep -fl "16_sim_v39_80grid" > /dev/null; then
      echo "[$ts] MONITOR: relaunched OK." >> "$LOG"
    else
      echo "[$ts] MONITOR: relaunch FAILED, retry next cycle." >> "$LOG"
    fi
  else
    echo "[$ts] MONITOR: alive. $(tail -1 "$PROG" 2>/dev/null)" >> "$LOG"
  fi
  sleep 300
done
echo "[$(date '+%Y-%m-%d %H:%M:%S')] MONITOR v37p1 exited." >> "$LOG"
