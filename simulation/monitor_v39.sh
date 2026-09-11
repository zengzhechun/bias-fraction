#!/bin/bash
# v39 simulation self-polling monitor: checks every 300s, auto-relaunches if dead.
PROJ="/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/manuscript_v37"
PROG="$PROJ/output/simulation/run_progress_v39.txt"
LOG="$PROJ/output/simulation/v39_monitor.log"
RSCRIPT="/usr/local/bin/Rscript"
SIM="$PROJ/R/16_sim_v39_80grid.R"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] MONITOR: started (interval=300s)" >> "$LOG"

while true; do
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  if grep -q "COMPLETE" "$PROG" 2>/dev/null; then
    echo "[$ts] MONITOR: simulation COMPLETE. Stopping monitor." >> "$LOG"
    break
  fi
  if ! pgrep -fl "16_sim_v39_80grid" > /dev/null; then
    echo "[$ts] MONITOR: process DEAD, relaunching via nohup..." >> "$LOG"
    cd "$PROJ" && nohup "$RSCRIPT" "$SIM" > "$PROJ/output/simulation/v39_run.log" 2>&1 & disown
    sleep 6
    if pgrep -fl "16_sim_v39_80grid" > /dev/null; then
      echo "[$ts] MONITOR: relaunched OK (pid $(pgrep -f 16_sim_v39_80grid | head -1))." >> "$LOG"
    else
      echo "[$ts] MONITOR: relaunch FAILED, will retry next cycle." >> "$LOG"
    fi
  else
    last=$(tail -1 "$PROG" 2>/dev/null)
    echo "[$ts] MONITOR: alive. $last" >> "$LOG"
  fi
  sleep 300
done
echo "[$(date '+%Y-%m-%d %H:%M:%S')] MONITOR: exited." >> "$LOG"
