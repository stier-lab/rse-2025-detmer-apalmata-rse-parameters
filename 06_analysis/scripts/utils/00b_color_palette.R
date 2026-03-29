################################################################################
# 00b_color_palette.R - Color Palettes for Manuscript Figures
################################################################################

# --- Okabe-Ito colorblind-safe palette (primary qualitative palette) ---
OKABE_ITO <- c("#E69F00", "#56B4E9", "#009E73", "#F0E442",
               "#0072B2", "#D55E00", "#CC79A7")

# --- Manuscript color palette (semantic naming) ---
MANUSCRIPT_PALETTE <- list(
  # Population type colors (Okabe-Ito blue & vermillion)
  natural     = "#0072B2",
  restoration = "#D55E00",

  # Survival palette (blues)
  surv_dark   = "#0a3d62",
  surv_mid    = "#1565c0",
  surv_light  = "#42a5f5",

  # Growth palette (teals)
  grow_dark   = "#004d40",
  grow_mid    = "#00897b",
  grow_light  = "#4db6ac",

  # Accent
  accent      = "#d84315",

  # Neutrals
  slate_dark  = "#1e293b",
  slate_mid   = "#475569",
  slate_light = "#94a3b8",
  grid        = "#f1f5f9"
)

# --- Size class colors (for heatmaps and categorical plots) ---
SIZE_CLASS_COLORS <- c(
  "SC1" = "#E69F00",
  "SC2" = "#56B4E9",
  "SC3" = "#009E73",
  "SC4" = "#0072B2",
  "SC5" = "#D55E00"
)

cat("Loaded 00b_color_palette.R\n")
