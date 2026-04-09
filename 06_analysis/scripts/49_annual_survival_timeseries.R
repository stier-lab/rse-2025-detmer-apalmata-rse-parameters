#!/usr/bin/env Rscript
# =============================================================================
# FIGURE S20: ANNUAL SURVIVAL TIME SERIES (2-panel: a / b)
# =============================================================================
# Panel a: Annual mean survival (Wilson 95% CI) for natural colonies,
#          with major disturbance events marked as vertical bands
# Panel b: Number of colonies monitored per year (sample size context)
#
# Data: Natural colonies only (population_type == "Natural colony")
# Source: 06_analysis/output/prepared_survival_data.rds
# Disturbance overlay: 05_data/standardized/apal_disturbance_stressor_timeline.csv
#
# OUTPUT: 06_analysis/figures/supplementary/FigS20_annual_survival_timeseries.{png,pdf}
#         174 x 140 mm (double-column, vertical stack), 300 DPI
#
# Author: Detmer & Stier Lab
# Date: 2026-04
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(patchwork)
  library(scales)
})

if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

pal <- MANUSCRIPT_PALETTE
project_root <- get_project_root()
output_dir <- file.path(project_root, "06_analysis/output")

require_output <- function(path) {
  if (!file.exists(path)) stop("Required file not found: ", path)
  path
}

cat("\n")
cat("================================================================\n")
cat("  FIGURE S20: Annual Survival Time Series (a|b)\n")
cat("================================================================\n\n")

# =============================================================================
# 1. LOAD AND FILTER DATA
# =============================================================================

surv_data <- readRDS(require_output(file.path(output_dir, "prepared_survival_data.rds")))

# Natural colonies only
nat_data <- surv_data %>%
  filter(population_type == "Natural colony") %>%
  filter(!is.na(survey_yr), !is.na(survived))

cat(sprintf("  Natural colony observations: %d\n", nrow(nat_data)))
cat(sprintf("  Year range: %d - %d\n", min(nat_data$survey_yr), max(nat_data$survey_yr)))
cat(sprintf("  Studies: %s\n", paste(unique(nat_data$study), collapse = ", ")))

# =============================================================================
# 2. COMPUTE ANNUAL SURVIVAL WITH WILSON CIs
# =============================================================================

min_n <- 20  # minimum colonies per year for reliable estimate

annual_surv_all <- nat_data %>%
  group_by(survey_yr) %>%
  summarise(
    n_colonies = n(),
    n_survived = sum(survived),
    .groups = "drop"
  ) %>%
  rowwise() %>%
  mutate(
    ci = list(wilson_ci(n_survived, n_colonies)),
    survival = ci$estimate,
    ci_lower = ci$lower,
    ci_upper = ci$upper
  ) %>%
  ungroup() %>%
  select(-ci)

# Flag years with small samples (shown in panel b but not connected in panel a)
annual_surv <- annual_surv_all %>%
  mutate(reliable = n_colonies >= min_n)

n_excluded <- sum(!annual_surv$reliable)
if (n_excluded > 0) {
  cat(sprintf("\n  NOTE: %d year(s) with n < %d excluded from survival panel:\n",
              n_excluded, min_n))
  print(as.data.frame(filter(annual_surv, !reliable)), row.names = FALSE)
}

cat("\n  Annual survival estimates (n >= ", min_n, "):\n", sep = "")
print(as.data.frame(filter(annual_surv, reliable)), row.names = FALSE)

# =============================================================================
# 3. LOAD DISTURBANCE EVENTS FOR OVERLAY
# =============================================================================

disturbance_path <- file.path(project_root, "05_data/standardized/apal_disturbance_stressor_timeline.csv")

# Select major Caribbean-wide or regional events overlapping the monitoring period
# that are acute and clearly datable
disturbance_events <- if (file.exists(disturbance_path)) {
  timeline <- read.csv(disturbance_path, stringsAsFactors = FALSE)

  # Filter to acute events within monitoring window (2004-2024)
  # and at regional or Caribbean-wide scale
  events <- timeline %>%
    filter(
      Start_Year >= 2004, Start_Year <= 2024,
      Spatial_Scale %in% c("regional", "caribbean-wide"),
      Analysis_Tier == "acute_event" | Event_Name == "2023 Marine Heatwave"
    ) %>%
    # Consolidate: keep the key events most relevant to survival
    select(Event_Name, Event_Type, Start_Year, End_Year, Spatial_Scale) %>%
    distinct()

  cat(sprintf("\n  Disturbance events for overlay: %d\n", nrow(events)))
  if (nrow(events) > 0) print(events, row.names = FALSE)
  events
} else {
  cat("\n  No disturbance timeline file found; skipping event overlay.\n")
  tibble(Event_Name = character(), Event_Type = character(),
         Start_Year = integer(), End_Year = integer(), Spatial_Scale = character())
}

# Build annotation labels: short names for plot
# Group adjacent events (2022 Diadema + 2023 heatwave) to avoid label overlap
event_labels <- disturbance_events %>%
  mutate(
    event_group = case_when(
      Start_Year == 2005                 ~ "2005_events",
      grepl("3rd Global", Event_Name)    ~ "bleaching_2014",
      Start_Year %in% c(2022, 2023)      ~ "2022_2023_events",
      TRUE                               ~ Event_Name
    ),
    short_label = case_when(
      grepl("Thermal", Event_Name) & grepl("2005", Event_Name) ~ "Bleaching\n(2005)",
      grepl("Irma", Event_Name)                                 ~ "Hurricane\nIrma (2017)",
      Start_Year %in% c(2022, 2023)                             ~ "Diadema +\nheatwave\n(2022-23)",
      TRUE                                                      ~ Event_Name
    )
  )

# Deduplicate overlapping events into bands
event_bands <- event_labels %>%
  group_by(event_group) %>%
  summarise(
    xmin = min(Start_Year) - 0.4,
    xmax = max(End_Year) + 0.4,
    label = first(short_label),
    .groups = "drop"
  )

cat(sprintf("\n  Event bands for shading: %d\n", nrow(event_bands)))

# =============================================================================
# 4. PANEL A: ANNUAL SURVIVAL
# =============================================================================

cat("\nPanel a: Annual survival with CI...\n")

# Separate reliable vs unreliable years
surv_reliable   <- filter(annual_surv, reliable)
surv_unreliable <- filter(annual_surv, !reliable)

# Y-axis: focus on the range of reliable data
y_min_a <- max(0.5, floor(min(surv_reliable$ci_lower) * 20) / 20 - 0.05)

p_a <- ggplot(surv_reliable, aes(x = survey_yr, y = survival)) +
  # Disturbance event shading
  {if (nrow(event_bands) > 0)
    geom_rect(data = event_bands,
              aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf),
              inherit.aes = FALSE,
              fill = pal$accent, alpha = 0.08)
  } +
  # Disturbance event labels at top
  {if (nrow(event_bands) > 0)
    geom_text(data = event_bands,
              aes(x = (xmin + xmax) / 2, y = Inf, label = label),
              inherit.aes = FALSE,
              vjust = 1.2, size = 2.2, color = pal$accent,
              lineheight = 0.85, fontface = "italic")
  } +
  # Confidence ribbon (reliable years only)
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper),
              fill = pal$surv_mid, alpha = 0.25) +
  # Line (reliable years only)
  geom_line(color = pal$surv_dark, linewidth = 0.7) +
  # Reliable points sized by sample size
  geom_point(aes(size = n_colonies), color = pal$surv_dark, fill = pal$surv_mid,
             shape = 21, stroke = 0.5) +
  # Unreliable years as open points (if any fall within y-axis range)
  {if (nrow(surv_unreliable) > 0)
    geom_point(data = surv_unreliable,
               aes(x = survey_yr, y = pmax(survival, y_min_a)),
               color = pal$slate_light, shape = 1, size = 2, stroke = 0.5)
  } +
  scale_size_continuous(range = c(1.5, 4), guide = "none") +
  scale_x_continuous(breaks = seq(2004, 2024, by = 2),
                     limits = c(2003.5, 2024.5)) +
  scale_y_continuous(labels = label_percent(accuracy = 1),
                     limits = c(y_min_a, 1.02),
                     breaks = seq(0.5, 1, by = 0.1)) +
  labs(x = NULL,
       y = "Annual survival") +
  theme_manuscript(base_size = 10) +
  theme(
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    plot.margin = margin(8, 10, 2, 10, "mm")
  )

# =============================================================================
# 5. PANEL B: SAMPLE SIZE PER YEAR
# =============================================================================

cat("Panel b: Annual sample size...\n")

# Show ALL years in bar chart (including low-n); shade unreliable bars differently
p_b <- ggplot(annual_surv, aes(x = survey_yr, y = n_colonies, fill = reliable)) +
  geom_col(alpha = 0.6, width = 0.7, show.legend = FALSE) +
  scale_fill_manual(values = c("TRUE" = pal$surv_mid, "FALSE" = pal$slate_light)) +
  geom_text(aes(label = n_colonies), vjust = -0.3, size = 2.3,
            color = pal$slate_mid) +
  # Threshold line
  geom_hline(yintercept = min_n, linetype = "dashed", color = pal$slate_light,
             linewidth = 0.3) +
  scale_x_continuous(breaks = seq(2004, 2024, by = 2),
                     limits = c(2003.5, 2024.5)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(x = "Year",
       y = "Colonies monitored") +
  theme_manuscript(base_size = 10) +
  theme(
    plot.margin = margin(2, 10, 8, 10, "mm")
  )

# =============================================================================
# 6. COMBINE PANELS WITH PATCHWORK
# =============================================================================

cat("Combining panels...\n")

p_combined <- p_a / p_b +
  plot_layout(heights = c(3, 1.2)) +
  plot_annotation(tag_levels = "a") &
  theme(plot.tag = element_text(size = 12, face = "bold", color = pal$slate_dark))

# =============================================================================
# 7. SAVE
# =============================================================================

fig_dir <- file.path(project_root, "06_analysis/figures/supplementary")
save_manuscript_fig(
  plot = p_combined,
  filename = "FigS20_annual_survival_timeseries",
  width_mm = 174,
  height_mm = 140,
  fig_dir = fig_dir
)

cat("\nDone.\n")
