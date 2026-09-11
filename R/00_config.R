# manuscript v39 (directory "第39版"): Global Configuration
# v39 reorganises the paper into three sequential parts:
#   Part I  - the metric (BAF definition, bounded scale, CI construction)
#   Part II - simulation study, two steps:
#             Step 1  Bland-Altman agreement -> the BAF estimator is accurate
#             Step 2  two-layer decision rule (calibrated p + continuous BAF + CI width)
#                     -> BAF with its CI is a valid complement to the calibrated p-value
#   Part III- beta-blocker target trial emulation, two clinical questions
#             (BB >=50% target dose; GDMT >=2 of 3 classes), with negative controls
# Directory paths below point at "第39版"; all analysis outputs stay inside it.
# ---------------------------------------------------------------------------
# manuscript_v37 header retained for provenance:
# v37 inherits the v34 metric reframing (BAF primary, BER auxiliary) and adopts the
# v35 continuous BAF analysis. KEY v37 CHANGE (per team decision 2026-08-21):
#   The PRIMARY analysis of the simulation study is now the Bland-Altman agreement
#   study of the continuous BAF estimator (interior version, excluding BAF=1, as the
#   primary; full version including BAF=1 as transparency). The three-zone
#   classification becomes a SECONDARY analysis that supplies the clinical
#   decision interface. BAF is treated throughout as a continuous quantity.
# Code keeps bsr_* object names (bsr == BER) for backward compatibility with v33 RDS outputs.
BASE_DIR <- "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker"
DATA_DIR <- file.path(BASE_DIR, "DATA")
# v39: the working directory is now "第39版". V39_DIR is the live root; the
# V38_DIR / V37_DIR names are kept as aliases so that older scripts that refer
# to them keep working without edits.
V39_DIR  <- file.path(BASE_DIR, "第39版")
V38_DIR  <- V39_DIR   # backward-compatible alias
V37_DIR  <- V39_DIR   # backward-compatible alias
OUT_DIR  <- file.path(V39_DIR, "output")
FIG_DIR  <- file.path(OUT_DIR, "figures")
TAB_DIR  <- file.path(OUT_DIR, "tables")
SIM_DIR  <- file.path(OUT_DIR, "simulation")
LOG_DIR  <- file.path(V39_DIR, "logs")

dir.create(FIG_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(TAB_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(SIM_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(LOG_DIR, showWarnings = FALSE, recursive = TRUE)

# NC_MIN_EVENTS is a documentation constant: the >=50-events screening rule for
# negative controls (stated in Methods) is applied upstream during cohort building,
# not in this analysis layer.
NC_MIN_EVENTS <- 50

# BAF zone thresholds (v34, unchanged in v35): bias-dominated BAF > 0.5;
# competitive 1/3 <= BAF <= 0.5; effect-dominated BAF < 1/3.
# Equivalent to BER thresholds 1 and 0.5.
BF_THRESH_BIAS   <- 0.5
BF_THRESH_EFFECT <- 1 / 3

# Academic color palette
COLOR_BIAS_DOM     <- "#8B4A4A"  # muted burgundy
COLOR_EFFECT_DOM   <- "#5A7A5A"  # muted sage
COLOR_COMPETITIVE  <- "#B8A060"  # muted gold
COLOR_OHDSI        <- "#5B8FA8"  # steel blue
COLOR_UNCAL        <- "#8B3A3A"  # dark red
COLOR_NEUTRAL      <- "#6E7B8B"  # cool grey
COLOR_GRID         <- "#E8E8E8"  # very light grey for grid
COLOR_TEXT         <- "#2C2C2C"  # dark charcoal (not pure black)

# Palette keyed on the number of negative controls (K). Named, so the mapping
# never depends on factor-level ordering. Deliberately avoids the zone colours
# above, which carry bias/effect semantics and must not be reused for K.
# Extend here whenever a new K level is added to the simulation grid.
COLOR_K <- c("12" = COLOR_OHDSI,       # steel blue
             "25" = COLOR_COMPETITIVE, # muted gold
             "50" = "#7A6A8A")         # muted plum
