# manuscript_v34: Global Configuration
# v34: metric reframed — Bias Fraction (BF) primary, bias-effect ratio (BER) auxiliary.
# BF = |mu_B| / (|mu_B| + |psi_tilde|) = BER / (1 + BER) in [0,1].
# Code keeps bsr_* object names (bsr == BER) for backward compatibility with v33 RDS outputs.
BASE_DIR <- "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker"
DATA_DIR <- file.path(BASE_DIR, "DATA")
V34_DIR  <- file.path(BASE_DIR, "manuscript_v34")
OUT_DIR  <- file.path(V34_DIR, "output")
FIG_DIR  <- file.path(OUT_DIR, "figures")
TAB_DIR  <- file.path(OUT_DIR, "tables")
SIM_DIR  <- file.path(OUT_DIR, "simulation")
LOG_DIR  <- file.path(V34_DIR, "logs")

dir.create(FIG_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(TAB_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(SIM_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(LOG_DIR, showWarnings = FALSE, recursive = TRUE)

# NC_MIN_EVENTS is a documentation constant: the >=50-events screening rule for
# negative controls (stated in Methods) is applied upstream during cohort building,
# not in this analysis layer.
NC_MIN_EVENTS <- 50

# BF zone thresholds (v34): bias-dominated BF > 0.5; competitive 1/3 <= BF <= 0.5;
# effect-dominated BF < 1/3. Equivalent to BER thresholds 1 and 0.5.
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
