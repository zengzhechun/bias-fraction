# ============================================================================
# TARGET guideline reporting artifacts (v34)
#
# 1) fig08_target_flow.png/.pdf : participant flow diagram following the
#    TARGET 2025 template for emulations with a unique time of eligibility
#    and treatment strategies distinguishable at baseline (template 1).
#    Counts verified against DATA/ltmle_wide_K2_guideline.rds and
#    output/data/tmle_results.rds (primary n_treat = 1772).
# 2) output/tables/baseline_table_v34.csv : baseline characteristics by
#    treatment strategy with SMDs, from DATA/baseline_smd_results.rds.
# ============================================================================
source("../R/00_config.R")
library(grid)

# ---- Verified counts -------------------------------------------------------
n_assessed   <- 15053   # HF hospitalizations in the analysis frame
n_excl_death <- 376     # died during the 7-day grace period
n_elig       <- 14677   # eligible at time zero
n_arm_a      <- 1772    # >= 50% target dose (12.1%)
n_arm_b      <- 12905   # <  50% target dose (87.9%)
d_a          <- 294     # 1-year all-cause deaths, strategy A (16.6%)
d_b          <- 2487    # 1-year all-cause deaths, strategy B (19.3%)
n_gdmt_anal  <- 11183   # GDMT analysis sample (complete medication data)
n_gdmt_hi    <- 1744    # >= 2 of 3 GDMT classes
n_gdmt_lo    <- 9439    # <  2 of 3 GDMT classes

# ---- Palette (from 00_config.R) --------------------------------------------
ink    <- COLOR_TEXT      # "#2C2C2C"
neutral<- COLOR_NEUTRAL   # "#6E7B8B"
sage   <- COLOR_EFFECT_DOM# "#5A7A5A" strategy A
gold   <- COLOR_COMPETITIVE # "#B8A060" strategy B
burg   <- COLOR_BIAS_DOM  # "#8B4A4A" exclusion
steel  <- COLOR_OHDSI     # "#5B8FA8"

lighten <- function(hex, f = 0.88) {
  rgb <- col2rgb(hex) / 255
  rgb <- rgb + (1 - rgb) * f
  rgb(rgb[1], rgb[2], rgb[3])
}

draw_box <- function(x1, x2, y1, y2, fill, border, lines, cex = 0.92,
                     lineheight = 1.15) {
  grid.rect(x = unit(x1, "npc"), y = unit(y1, "npc"),
            width = unit(x2 - x1, "npc"), height = unit(y2 - y1, "npc"),
            just = c("left", "bottom"), gp = gpar(fill = fill, col = border,
            lwd = 1.4))
  grid.text(paste(lines, collapse = "\n"),
            x = unit((x1 + x2) / 2, "npc"), y = unit((y1 + y2) / 2, "npc"),
            gp = gpar(col = ink, fontsize = 10.5 * cex, lineheight = lineheight))
}

draw_arrow <- function(x1, y1, x2, y2) {
  grid.segments(x0 = unit(x1, "npc"), y0 = unit(y1, "npc"),
                x1 = unit(x2, "npc"), y1 = unit(y2, "npc"),
                arrow = arrow(angle = 22, length = unit(0.09, "in"),
                              ends = "last", type = "open"),
                gp = gpar(col = neutral, lwd = 1.3, fill = neutral))
}

draw_line <- function(x1, y1, x2, y2) {
  grid.segments(x0 = unit(x1, "npc"), y0 = unit(y1, "npc"),
                x1 = unit(x2, "npc"), y1 = unit(y2, "npc"),
                gp = gpar(col = neutral, lwd = 1.3))
}

side_label <- function(txt, y) {
  grid.text(txt, x = unit(0.025, "npc"), y = unit(y, "npc"), rot = 90,
            gp = gpar(col = neutral, fontsize = 10, fontface = "bold"))
}

plot_flow <- function() {
  # ---- Eligibility ---------------------------------------------------------
  draw_box(0.10, 0.92, 0.865, 0.955, "grey96", neutral, c(
    "Heart failure hospitalizations assessed for eligibility (n = 15,053)"))

  draw_arrow(0.28, 0.865, 0.28, 0.685)           # down toward eligible
  draw_arrow(0.28, 0.7725, 0.405, 0.7725)        # right into exclusion

  draw_box(0.405, 0.94, 0.705, 0.84, lighten(burg, 0.90), burg, c(
    "Excluded (n = 376)",
    "Died during the 7-day grace period,",
    "before treatment classification at time zero"), cex = 0.88)

  draw_box(0.06, 0.50, 0.585, 0.685, lighten(steel, 0.90), steel, c(
    "Eligible individuals at time zero (n = 14,677)",
    "Time zero: end of the 7-day grace period"), cex = 0.88)

  # ---- Split into strategies ----------------------------------------------
  draw_arrow(0.28, 0.585, 0.28, 0.535)           # eligible -> split point
  draw_line(0.28, 0.535, 0.72, 0.535)            # horizontal split
  draw_arrow(0.28, 0.535, 0.28, 0.475)           # down to arm A
  draw_arrow(0.72, 0.535, 0.72, 0.475)           # down to arm B

  draw_box(0.08, 0.48, 0.375, 0.475, lighten(sage, 0.90), sage, c(
    "Strategy A",
    "Achieved \u2265 50% of target beta-blocker dose",
    "(n = 1,772; 12.1%)"), cex = 0.88)

  draw_box(0.52, 0.92, 0.375, 0.475, lighten(gold, 0.90), gold, c(
    "Strategy B",
    "Received < 50% of target dose",
    "(n = 12,905; 87.9%)"), cex = 0.88)

  # ---- Follow-up -----------------------------------------------------------
  draw_arrow(0.28, 0.375, 0.28, 0.335)
  draw_arrow(0.72, 0.375, 0.72, 0.335)

  fu_lines_a <- c(
    "Follow-up: 1 year (days 8-365)",
    "1-year all-cause deaths: 294 (16.6%)",
    "Losses to follow-up: none",
    "(complete date-of-death ascertainment)",
    "Competing events: none",
    "(all-cause mortality endpoint)")
  fu_lines_b <- c(
    "Follow-up: 1 year (days 8-365)",
    "1-year all-cause deaths: 2,487 (19.3%)",
    "Losses to follow-up: none",
    "(complete date-of-death ascertainment)",
    "Competing events: none",
    "(all-cause mortality endpoint)")
  draw_box(0.055, 0.505, 0.115, 0.335, "grey98", neutral, fu_lines_a,
           cex = 0.84, lineheight = 1.25)
  draw_box(0.495, 0.945, 0.115, 0.335, "grey98", neutral, fu_lines_b,
           cex = 0.84, lineheight = 1.25)

  # ---- Footnote ------------------------------------------------------------
  grid.text(paste0(
    "No participants were censored for nonadherence: the causal contrast is intention-to-treat-like for treatment strategies\n",
    "classified once at time zero. The guideline-directed medical therapy (GDMT) comparison reclassified the same 14,677\n",
    "eligible individuals by number of GDMT classes received; 11,183 patients with complete medication data were analyzed\n",
    "(\u2265 2 of 3 classes, n = 1,744; < 2 classes, n = 9,439). Death counts are crude counts from the emulation cohort."),
    x = unit(0.5, "npc"), y = unit(0.055, "npc"),
    gp = gpar(col = neutral, fontsize = 8.6, lineheight = 1.3))

  # ---- Side labels ---------------------------------------------------------
  side_label("Eligibility", 0.77)
  side_label("Treatment strategies", 0.51)
  side_label("Follow-up", 0.225)
}

save_flow <- function() {
  use_cairo <- capabilities("cairo")[["cairo"]] ||
               capabilities("quartz")[["quartz"]]
  if (use_cairo) {
    png(file.path(FIG_DIR, "fig08_target_flow.png"), width = 7.5,
        height = 9.6, units = "in", res = 300, type = "cairo")
    grid.newpage(); plot_flow(); dev.off()
    grDevices::cairo_pdf(file.path(FIG_DIR, "fig08_target_flow.pdf"),
                         width = 7.5, height = 9.6)
    grid.newpage(); plot_flow(); dev.off()
  } else {
    png(file.path(FIG_DIR, "fig08_target_flow.png"), width = 7.5,
        height = 9.6, units = "in", res = 300)
    grid.newpage(); plot_flow(); dev.off()
    pdf(file.path(FIG_DIR, "fig08_target_flow.pdf"), width = 7.5,
        height = 9.6)
    grid.newpage(); plot_flow(); dev.off()
  }
  cat("Saved: fig08_target_flow.png / .pdf (cairo:", use_cairo, ")\n")
}
save_flow()

# ============================================================================
# Baseline characteristics by treatment strategy (eTable 9 source)
# ============================================================================
t1  <- readRDS(file.path(DATA_DIR, "baseline_smd_results.rds"))
ct  <- t1$table1$ContTable
cat_t <- t1$table1$CatTable
smd <- t1$smd_clean
arms <- c("Overall", ">=50% Guideline BB", "<50% Guideline BB")

fmt_mean_sd <- function(v) sprintf("%.1f (%.1f)", v$mean, v$sd)
fmt_med_iqr <- function(v) sprintf("%.1f [%.1f, %.1f]", v$median, v$p25, v$p75)
fmt_n_pct <- function(v, level) {
  i <- match(level, v$level)
  sprintf("%d (%.1f)", v$freq[i], v$percent[i])
}

row_cont <- function(var, label, fmt = fmt_mean_sd) {
  vals <- sapply(arms, function(a) fmt(as.list(ct[[a]][var, ])))
  data.frame(Variable = label, Overall = vals[1], ArmA = vals[2],
             ArmB = vals[3], SMD = sprintf("%.3f", smd[[var]]),
             stringsAsFactors = FALSE)
}
row_cat <- function(var, level, label) {
  vals <- sapply(arms, function(a) fmt_n_pct(cat_t[[a]][[var]], level))
  data.frame(Variable = label, Overall = vals[1], ArmA = vals[2],
             ArmB = vals[3], SMD = sprintf("%.3f", smd[[var]]),
             stringsAsFactors = FALSE)
}

baseline <- rbind(
  row_cont("age", "Age, y"),
  row_cat("gender", "F", "Female"),
  row_cat("age_ge75", "Yes", "Age \u2265 75 y"),
  row_cont("L_hr_W0", "Heart rate, bpm"),
  row_cont("L_qrs_W0", "QRS duration, ms"),
  row_cont("L_qtc_W0", "QTc interval (Bazett), ms"),
  row_cat("L_af_W0", "Yes", "Atrial fibrillation"),
  row_cat("L_lbbb_W0", "Yes", "Left bundle branch block"),
  row_cont("L_cr_W0", "Creatinine, mg/dL", fmt_med_iqr),
  row_cont("L_egfr_W0", "eGFR, mL/min/1.73 m\u00b2"),
  row_cat("egfr_lt60", "Yes", "eGFR < 60 mL/min/1.73 m\u00b2"),
  row_cont("L_k_W0", "Potassium, mEq/L"),
  row_cont("L_na_W0", "Sodium, mEq/L"),
  row_cont("L_hb_W0", "Hemoglobin, g/dL"),
  row_cont("L_tnt_W0", "Troponin T, ng/mL", fmt_med_iqr),
  row_cont("L_ntprobnp_W0", "NT-proBNP, pg/mL", fmt_med_iqr),
  row_cont("L_n_ecg_W0", "ECGs during index stay, No.")
)

write.csv(baseline, file.path(TAB_DIR, "baseline_table_v34.csv"),
          row.names = FALSE)
cat("Saved: baseline_table_v34.csv (", nrow(baseline), "rows )\n")
print(baseline, row.names = FALSE)
