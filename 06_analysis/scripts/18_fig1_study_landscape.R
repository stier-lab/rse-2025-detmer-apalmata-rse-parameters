#!/usr/bin/env Rscript
# =============================================================================
# FIGURE 1: STUDY LANDSCAPE (2-panel: a=map, b=data availability)
# =============================================================================
#
# PURPOSE: Generate Figure 1 for the manuscript showing study locations and
#          data availability across the Caribbean.
#
# Panel a: Caribbean map showing ALL studies in the meta-analysis:
#   - Tier 1 (individual-level data, 6 studies): filled circles
#   - Tier 2 (summary-level data, 10 studies): filled triangles
# Bubble size = total sample size per region; shape = data tier
# Also outputs supplementary size distribution histogram (unchanged)
#
# INPUTS:
#   - 06_analysis/output/prepared_survival_data.rds (individual-level survival)
#   - 06_analysis/output/prepared_growth_data.rds (individual-level growth)
#   - 06_analysis/output/expanded_meta_analysis_study_effects.csv (all study effects)
#   - 05_data/standardized/apal_surv_summ.csv (summary data for Tier 2 coords)
#
# OUTPUTS:
#   - 06_analysis/figures/manuscript/Fig1_study_landscape.{png,pdf}
#   - 06_analysis/figures/supplementary/FigS1_size_distribution.{png,pdf}
#
# Journal: Coral Reefs (Springer) — 174mm double-column, 8-12pt
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(sf)
  library(rnaturalearth)
  library(rnaturalearthdata)
  library(ggrepel)
  library(scales)
})

if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

pal <- MANUSCRIPT_PALETTE

# =============================================================================
# LOAD DATA
# =============================================================================

cat("Loading data...\n")

project_root <- get_project_root()

# Individual-level data (Tier 1 — 6 studies)
surv_data <- readRDS(file.path(project_root, "06_analysis/output/prepared_survival_data.rds")) %>%
  filter(!is.na(size_class), !is.na(survived))

growth_data <- readRDS(file.path(project_root, "06_analysis/output/prepared_growth_data.rds"))

# Expanded meta-analysis study effects (all 16 studies with data tier)
expanded_studies <- read.csv(file.path(project_root,
  "06_analysis/output/expanded_meta_analysis_study_effects.csv"))

# Summary survival data (for Tier 2 coordinates)
summ_data <- read.csv(file.path(project_root,
  "05_data/standardized/apal_surv_summ.csv"))

n_studies_ind <- n_distinct(surv_data$study)
n_studies_all <- n_distinct(expanded_studies$study)

cat("  Individual-level:", nrow(surv_data), "survival,", nrow(growth_data), "growth |",
    n_distinct(surv_data$region), "regions |", n_studies_ind, "studies\n")
cat("  All studies (meta-analysis):", n_studies_all, "studies |",
    n_distinct(expanded_studies$region), "regions\n")

# =============================================================================
# FIGURE 1: CARIBBEAN MAP — All 16 Studies
# =============================================================================

cat("Figure 1: Caribbean map (all studies)...\n")

world <- ne_countries(scale = "medium", returnclass = "sf")

bbox <- c(xmin = -90, xmax = -58, ymin = 10, ymax = 28)

# --- Build Tier 1 region data from individual-level observations ---
tier1_regions <- surv_data %>%
  filter(!is.na(latitude), !is.na(longitude)) %>%
  group_by(region) %>%
  summarise(
    lat       = mean(latitude, na.rm = TRUE),
    lon       = mean(longitude, na.rm = TRUE),
    n         = n(),
    n_studies = n_distinct(study),
    .groups   = "drop"
  ) %>%
  mutate(data_tier = "Individual + summary data")

# --- Build Tier 2 coordinates from summary data ---
# Get mean lat/lon per study from apal_surv_summ.csv
summ_coords <- summ_data %>%
  filter(!is.na(latitude), !is.na(longitude)) %>%
  group_by(study, region) %>%
  summarise(
    lat = mean(latitude, na.rm = TRUE),
    lon = mean(longitude, na.rm = TRUE),
    .groups = "drop"
  )

# Identify Tier 2 studies from expanded_studies
tier2_studies <- expanded_studies %>%
  filter(grepl("Tier 2", data_tier))

# Merge Florida Keys into Florida for mapping
tier2_studies <- tier2_studies %>%
  mutate(map_region = if_else(region == "Florida Keys", "Florida", region))

# Create a join key that maps expanded study names back to summary study names
# e.g., "vardi_2011_jamaica" -> "vardi_2011", others stay as-is
tier2_studies <- tier2_studies %>%
  mutate(study_join = case_when(
    grepl("^vardi_2011_", study) ~ "vardi_2011",
    TRUE ~ study
  ))

# Join Tier 2 studies with their coordinates from summ_data
tier2_with_coords <- tier2_studies %>%
  left_join(summ_coords, by = c("study_join" = "study"), suffix = c("", "_summ"),
            relationship = "many-to-many") %>%
  # For studies with multiple regions in summ_data (e.g., vardi_2011),
  # keep only the row matching the expanded_studies region
  filter(
    is.na(region_summ) |    # no match in summ
    region_summ == region   # exact match
  )

# Fallback coordinates for studies/regions missing from summ_data
fallback_coords <- tribble(
  ~region,                   ~lat,    ~lon,
  "Jamaica",                  18.1,  -77.3,
  "Puerto Rico",              18.2,  -66.5,
  "Virgin Gorda",             18.45, -64.4,
  "British Virgin Islands",   18.5,  -64.6,
  "Bahamas",                  25.0,  -77.5,
  "Florida Keys",             24.7,  -81.0
)

# Fill in coordinates: prefer summ_data, fall back to hardcoded
tier2_with_coords <- tier2_with_coords %>%
  mutate(
    lat_final = coalesce(lat, fallback_coords$lat[match(region, fallback_coords$region)]),
    lon_final = coalesce(lon, fallback_coords$lon[match(region, fallback_coords$region)])
  )

# Aggregate Tier 2 by map_region (after FK merge)
tier2_regions <- tier2_with_coords %>%
  group_by(map_region) %>%
  summarise(
    lat       = mean(lat_final, na.rm = TRUE),
    lon       = mean(lon_final, na.rm = TRUE),
    n         = sum(n_total),
    n_studies = n(),
    .groups   = "drop"
  ) %>%
  rename(region = map_region)

# Determine which Tier 2 regions are also in Tier 1
tier2_only <- tier2_regions %>%
  filter(!(region %in% tier1_regions$region)) %>%
  mutate(data_tier = "Summary data only")

# For regions in BOTH tiers, add Tier 2 sample sizes to Tier 1
mixed_regions <- tier2_regions %>%
  filter(region %in% tier1_regions$region)

tier1_regions <- tier1_regions %>%
  left_join(mixed_regions %>% select(region, n_t2 = n), by = "region") %>%
  mutate(
    n = n + coalesce(n_t2, 0)
  ) %>%
  select(-n_t2)

# Combine into a single region_data for plotting
region_data <- bind_rows(tier1_regions, tier2_only)

# --- Nudge values for label placement ---
region_data <- region_data %>%
  mutate(
    nudge_x = case_when(
      region == "Florida"              ~ -3.5,
      region == "Mexico"               ~  3.0,
      region == "Navassa"              ~ -3.0,
      region == "Dominican Republic"   ~  2.5,
      region == "USVI"                 ~ -3.5,
      region == "Curacao"              ~  3.0,
      region == "Jamaica"              ~ -3.5,
      region == "Puerto Rico"          ~  3.5,
      region == "Virgin Gorda"         ~  3.5,
      region == "British Virgin Islands" ~ 3.5,
      region == "Bahamas"              ~ -3.0,
      TRUE ~ 0
    ),
    nudge_y = case_when(
      region == "Florida"              ~  1.5,
      region == "Mexico"               ~  1.5,
      region == "Navassa"              ~ -1.5,
      region == "Dominican Republic"   ~  2.0,
      region == "USVI"                 ~ -2.5,
      region == "Curacao"              ~  1.5,
      region == "Jamaica"              ~  1.5,
      region == "Puerto Rico"          ~  1.8,
      region == "Virgin Gorda"         ~  0.0,
      region == "British Virgin Islands" ~ -2.0,
      region == "Bahamas"              ~  1.5,
      TRUE ~ 1.2
    ),
    label = sprintf("%s\n(n = %s)", region, comma(n))
  )

# Count total studies and regions for annotation
n_regions_map <- nrow(region_data)

cat("  Map regions:", n_regions_map, "| Tier 1:", sum(region_data$data_tier != "Summary data only"),
    "| Tier 2 only:", sum(region_data$data_tier == "Summary data only"), "\n")

# --- Build the map ---
fig1 <- ggplot() +
  geom_rect(aes(xmin = bbox["xmin"], xmax = bbox["xmax"],
                ymin = bbox["ymin"], ymax = bbox["ymax"]),
            fill = "#dce9f5", color = NA) +
  geom_sf(data = world, fill = "#f0f0f0", color = "#bdbdbd",
          linewidth = 0.3) +
  geom_point(data = region_data,
             aes(x = lon, y = lat, size = n, shape = data_tier),
             fill = pal$surv_mid, color = pal$surv_dark,
             stroke = 0.7, alpha = 0.9) +
  scale_shape_manual(
    name = "Data type",
    values = c("Individual + summary data" = 21,   # filled circle
               "Summary data only"         = 24),  # filled triangle
    labels = c("Individual + summary data" = "Individual-level studies (Tier 1)",
               "Summary data only"         = "Summary-level studies (Tier 2)")
  ) +
  geom_text_repel(data = region_data,
                  aes(x = lon, y = lat, label = label),
                  size = 2.8, color = pal$slate_dark, lineheight = 0.85,
                  fontface = "plain",
                  nudge_x = region_data$nudge_x,
                  nudge_y = region_data$nudge_y,
                  segment.color = pal$slate_light,
                  segment.size = 0.3,
                  box.padding = 0.3,
                  point.padding = 0.3,
                  min.segment.length = 0,
                  max.overlaps = Inf,
                  seed = 42) +
  scale_size_area(
    name = "Observations",
    max_size = 12,
    breaks = c(100, 500, 2000, 4000),
    labels = comma
  ) +
  coord_sf(xlim = c(bbox["xmin"], bbox["xmax"]),
           ylim = c(bbox["ymin"], bbox["ymax"]),
           expand = FALSE, datum = NA) +
  # Manual scale bar (~500 km at ~18°N latitude)
  # 500 km ≈ 5.1° longitude at 18°N (cos(18°) ≈ 0.951, 1° ≈ 111 km * 0.951 = 105.6 km)
  annotate("segment",
           x = bbox["xmax"] - 7, xend = bbox["xmax"] - 7 + 5.1,
           y = bbox["ymin"] + 1.5, yend = bbox["ymin"] + 1.5,
           linewidth = 0.8, color = "grey30") +
  annotate("text",
           x = bbox["xmax"] - 7 + 2.55, y = bbox["ymin"] + 2.5,
           label = "500 km", size = 2.3, color = "grey30") +
  labs(x = NULL, y = NULL) +
  theme_manuscript() +
  theme(
    panel.grid       = element_blank(),
    axis.text        = element_blank(),
    axis.ticks       = element_blank(),
    axis.title       = element_blank(),
    axis.line        = element_blank(),
    plot.margin      = margin(5, 12, 4, 8),
    legend.position  = "top",
    legend.direction = "horizontal",
    legend.box       = "vertical",
    legend.key       = element_blank(),
    legend.key.size  = unit(0.7, "lines"),
    legend.spacing.y = unit(0.5, "lines"),
    legend.margin    = margin(2, 0, 0, 0),
    legend.title     = element_text(size = 8, face = "bold"),
    legend.text      = element_text(size = 8)
  ) +
  guides(
    size = guide_legend(
      override.aes = list(shape = 21, fill = pal$surv_mid,
                          color = pal$surv_dark, stroke = 0.4),
      nrow = 1
    ),
    shape = guide_legend(
      override.aes = list(size = 3.5, fill = pal$surv_mid,
                          color = pal$surv_dark, stroke = 0.5),
      nrow = 1
    )
  )

# Add panel tag
fig1a <- fig1 + labs(tag = "a")

# =============================================================================
# PANEL B: DATA AVAILABILITY MATRIX (size class x region)
# =============================================================================

cat("Panel b: Data availability matrix...\n")

library(patchwork)

# Build size_class x region matrix from survival data
avail_data <- surv_data %>%
  filter(!is.na(size_class), !is.na(region)) %>%
  group_by(size_class, region) %>%
  summarise(n = n(), .groups = "drop")

# Ensure all SC x region combos exist (fill missing with 0)
all_combos <- expand.grid(
  size_class = factor(SIZE_LABELS, levels = SIZE_LABELS),
  region = sort(unique(surv_data$region[!is.na(surv_data$region)])),
  stringsAsFactors = FALSE
)
avail_data <- all_combos %>%
  left_join(avail_data, by = c("size_class", "region")) %>%
  mutate(n = ifelse(is.na(n), 0, n))

# Order regions by total sample size (descending)
region_order_avail <- avail_data %>%
  group_by(region) %>%
  summarise(total = sum(n), .groups = "drop") %>%
  arrange(desc(total)) %>%
  pull(region)
avail_data$region <- factor(avail_data$region, levels = region_order_avail)

fig1b <- ggplot(avail_data, aes(x = region, y = size_class, fill = n)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = ifelse(n > 0, scales::comma(n), "")),
            size = 2.3, color = "white", fontface = "bold") +
  scale_fill_viridis_c(
    name = "n",
    option = "D",
    trans = "sqrt",
    breaks = c(0, 50, 200, 500, 1500),
    labels = scales::comma,
    na.value = "grey85"
  ) +
  scale_x_discrete(guide = guide_axis(angle = 35)) +
  labs(x = NULL, y = "Size class", tag = "b") +
  theme_manuscript() +
  theme(
    axis.text.x = element_text(size = 7, color = "grey30"),
    axis.text.y = element_text(size = 8, color = "grey30"),
    axis.title.y = element_text(size = 9),
    legend.position = "right",
    legend.key.height = unit(12, "mm"),
    legend.key.width = unit(3, "mm"),
    legend.title = element_text(size = 8),
    legend.text = element_text(size = 7),
    plot.margin = margin(4, 8, 4, 8, "mm"),
    panel.grid = element_blank()
  )

# Combine a (map) and b (heatmap) vertically
fig1_combined <- fig1a / fig1b +
  plot_layout(heights = c(1.3, 1))

save_manuscript_fig(fig1_combined, "Fig1_study_landscape", 174, 170)

# =============================================================================
# SUPPLEMENTARY: SIZE DISTRIBUTION
# =============================================================================

cat("Supplementary: Size distribution...\n")

size_data <- bind_rows(
  surv_data %>% select(size_cm2) %>% mutate(type = "Survival"),
  growth_data %>% select(size_cm2) %>% mutate(type = "Growth")
) %>%
  filter(!is.na(size_cm2), size_cm2 > 0)

median_size <- median(size_data$size_cm2, na.rm = TRUE)

fig_size_dist <- ggplot(size_data, aes(x = size_cm2)) +
  geom_histogram(bins = 55, fill = pal$surv_mid, color = "white",
                 alpha = 0.85, linewidth = 0.15) +
  geom_sc_boundaries() +
  geom_rug(alpha = 0.08, color = pal$slate_mid, linewidth = 0.2, sides = "b") +
  geom_vline(xintercept = median_size, color = "#D55E00",
             linewidth = 0.7, linetype = "solid") +
  annotate("text", x = median_size * 0.42, y = 420,
           label = sprintf("Median = %s cm\u00B2", comma(round(median_size))),
           hjust = 1, vjust = 0.5, size = 2.85, color = "#D55E00",
           fontface = "bold") +
  annotate("segment", x = median_size * 0.46, xend = median_size * 0.94,
           y = 420, yend = 420,
           color = "#D55E00", linewidth = 0.3,
           arrow = arrow(length = unit(0.06, "inches"), type = "closed")) +
  annotate("text", x = 30000, y = Inf,
           label = sprintf("N = %s\n%d studies, %d regions",
                           comma(nrow(size_data)), n_studies_ind,
                           n_distinct(surv_data$region)),
           hjust = 1, vjust = 1.4, size = 3.0, color = pal$slate_dark,
           lineheight = 0.9) +
  scale_x_log10(
    breaks = c(1, 10, 100, 1000, 10000),
    labels = comma,
    limits = c(0.8, 40000)
  ) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12)), labels = comma) +
  labs(x = expression(paste("Colony live tissue area (cm"^2, ")")),
       y = "Frequency") +
  theme_manuscript() +
  theme(
    panel.grid.major.x = element_blank(),
    plot.margin = margin(6, 8, 4, 8)
  )

supp_dir <- file.path(project_root, "06_analysis/figures/supplementary")
dir.create(supp_dir, showWarnings = FALSE, recursive = TRUE)
save_manuscript_fig(fig_size_dist, "FigS1_size_distribution",
                    width_mm = 174, height_mm = 100, fig_dir = supp_dir)

cat("\nDone: Figure 1 (map) + Fig S1 (size distribution)\n")
