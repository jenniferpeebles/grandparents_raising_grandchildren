# Purpose: map direct state/DC percentages and county/equivalent percentages nationwide.
# Inputs: configured ACS B10050 and matching national county cartographic boundaries.
# Outputs: county and state review PNGs, source/QA CSVs and WGS84 GeoJSON. Run after 06, before verification.
# Assumptions: same precision screen and 0-100 magma scale as Georgia; no imputation.
source(file.path("scripts", "00_setup.R"))
for (package in c("sf", "tigris", "ragg", "cowplot")) {
  if (!requireNamespace(package, quietly = TRUE)) stop("Install national-map dependency: ", package)
}
state_scope <- us_state_fips
# Script 03 owns national county retrieval and rankings; maps consume its verified data.
national_path <- file.path("data_clean", "us_counties_grandparents.csv")
if (!file.exists(national_path)) stop("Run script 03 before the national maps.")
national_counties <- readr::read_csv(national_path,
  col_types = cols(geoid = col_character(), state_fips = col_character(), .default = col_guess())) %>%
  mutate(map_pct_responsible = if_else(pct_responsible_exclusion == "Retained", pct_responsible, NA_real_))
stopifnot(setequal(unique(national_counties$state_fips), state_scope), !anyDuplicated(national_counties$geoid),
          all(national_counties$acs_year == acs_year), "national_rank_caregiving_percent" %in% names(national_counties))
export_csv(national_counties %>% select(geoid, name, pct_responsible_exclusion), "national_county_map_audit.csv")
export_csv(national_counties %>% count(pct_responsible_exclusion, name = "records") %>%
  mutate(received = nrow(national_counties)), "national_county_map_summary.csv")
boundary_path <- file.path("data_raw", paste0("us_counties_cb_", acs_year, "_500k.rds"))
if (!file.exists(boundary_path) || refresh_downloads) {
  # Toolbox's state-specific wrapper is not suitable for an unrestricted national pull.
  boundaries <- tigris::counties(cb = TRUE, year = acs_year, resolution = "500k", class = "sf", progress_bar = FALSE)
  saveRDS(list(layer = boundaries, retrieved_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)), boundary_path)
}
boundary_cache <- readRDS(boundary_path)
national_boundaries <- boundary_cache$layer %>% filter(STATEFP %in% state_scope) %>% select(geoid = GEOID)
missing_geometry <- anti_join(national_counties, sf::st_drop_geometry(national_boundaries), by = "geoid")
missing_data <- anti_join(sf::st_drop_geometry(national_boundaries), national_counties, by = "geoid")
export_csv(missing_geometry, "national_counties_without_geometry.csv")
export_csv(missing_data, "national_counties_without_data.csv")
stopifnot(nrow(missing_geometry) == 0L, nrow(missing_data) == 0L,
          !anyDuplicated(national_boundaries$geoid), all(sf::st_is_valid(national_boundaries)),
          !any(sf::st_is_empty(national_boundaries)))
national_map_data <- national_boundaries %>% left_join(national_counties, by = "geoid", relationship = "one-to-one")
stopifnot(nrow(national_map_data) == nrow(national_counties))
# Preserve unshifted geography for handoff. Only the Alaska display wraps dateline fragments.
geojson_path <- peeblestoolbox::export_geojson(national_map_data, paste0("us_county_caregiving_", acs_year, ".geojson"),
  folder = "exports", overwrite = TRUE)
exported <- sf::st_read(geojson_path, quiet = TRUE)
stopifnot(sf::st_crs(exported)$epsg == 4326L, setequal(exported$geoid, national_counties$geoid), all(sf::st_is_valid(exported)))
projected <- sf::st_transform(national_map_data, 3857)
alaska <- projected %>% filter(state_fips == "02")
# EPSG:3857 repeats every world circumference. Move eastern dateline fragments one world west
# for this inset only so all Aleutian islands remain beside Alaska; do not alter handoff coordinates.
world_width <- 2 * pi * 6378137
wrapped <- lapply(sf::st_geometry(alaska), function(feature) {
  parts <- sf::st_cast(sf::st_sfc(feature, crs = 3857), "POLYGON")
  for (i in seq_along(parts)) if (sf::st_bbox(parts[i])[["xmin"]] > 0) parts[i] <- parts[i] - c(world_width, 0)
  sf::st_combine(parts)[[1]]
})
sf::st_geometry(alaska) <- sf::st_sfc(wrapped, crs = 3857)
stopifnot(all(sf::st_is_valid(alaska)), !any(sf::st_is_empty(alaska)))
map_panel <- function(layer, title = NULL, legend = FALSE) {
  # State outlines are derived from the same county polygons, with no additional join.
  state_lines <- layer %>% group_by(state_fips) %>% summarise(.groups = "drop")
  ggplot(layer) + geom_sf(aes(fill = map_pct_responsible), color = "white", linewidth = .035) +
    geom_sf(data = state_lines, fill = NA, color = "#555555", linewidth = .18) +
    scale_fill_viridis_c(option = "magma", begin = .15, end = .90, limits = c(0, 100),
      breaks = seq(0, 100, 25), labels = scales::label_percent(scale = 1), na.value = "#D4D6D8",
      name = "Responsible\n(%)") +
    coord_sf(crs = sf::st_crs(3857), datum = NA, expand = FALSE) +
    labs(title = title) + peeblestoolbox::theme_peebles_map(base_size = 10,
      legend_position = if (legend) "right" else "none") +
    theme(plot.title = element_text(size = 10, face = "bold"), plot.margin = margin(3, 3, 3, 3))
}
mainland_plot <- map_panel(projected %>% filter(!state_fips %in% c("02", "15")), legend = TRUE)
alaska_plot <- map_panel(alaska, "Alaska")
hawaii_plot <- map_panel(projected %>% filter(state_fips == "15"), "Hawaii")
retained <- sum(national_counties$pct_responsible_exclusion == "Retained")
caption <- stringr::str_wrap(paste0("Source: ", acs_period, " ACS five-year estimates, B10050; ", acs_year,
  " Census county boundaries. People age 30+ living with their own grandchildren under 18. ",
  format(retained, big.mark = ","), " of ", format(nrow(national_counties), big.mark = ","),
  " counties/equivalents colored. Gray = unavailable or fails the same precision screen as Georgia; not zero. ",
  "Count and percentage MOEs must each be at most ", severe_moe_threshold * 100,
  "% of their estimates. No significance claim. Web Mercator (EPSG:3857); insets resized, Aleutians wrapped. ",
  "50 states and DC; territories excluded. Plot: us_county_caregiving_map"), width = 165)
us_county_caregiving_map <- cowplot::ggdraw() +
  cowplot::draw_plot(mainland_plot, x = .02, y = .24, width = .96, height = .62) +
  cowplot::draw_plot(alaska_plot, x = .02, y = .10, width = .22, height = .27) +
  cowplot::draw_plot(hawaii_plot, x = .25, y = .11, width = .16, height = .15) +
  cowplot::draw_label("Grandparent caregiving across U.S. counties", x = .025, y = .965,
    hjust = 0, vjust = 1, fontface = "bold", size = 21) +
  cowplot::draw_label(paste(acs_period, "| Share of co-resident grandparents responsible for grandchildren"),
    x = .025, y = .915, hjust = 0, vjust = 1, size = 13) +
  cowplot::draw_label(caption, x = .025, y = .025, hjust = 0, vjust = 0, size = 9, color = "gray35") +
  peeblestoolbox::add_peebles_watermark(size = 44, alpha = .16)
us_county_caregiving_map
peeblestoolbox::save_peebles_plot(us_county_caregiving_map, paste0("us_county_caregiving_map_", acs_year, ".png"),
  folder = file.path("outputs", "graphics"), width = 15, height = 10, dpi = 300, device = ragg::agg_png, bg = "white")
export_csv(tibble(boundary_year = acs_year, boundary_retrieved_utc = boundary_cache$retrieved_utc,
  source = paste0("https://www2.census.gov/geo/tiger/GENZ", acs_year, "/shp/cb_", acs_year, "_us_county_500k.zip"),
  counties = nrow(national_counties), states_and_dc = n_distinct(national_counties$state_fips),
  colored = retained, gray = nrow(national_counties) - retained, unmatched = 0L,
  static_crs = sf::st_crs(projected)$Name, static_epsg = sf::st_crs(projected)$epsg,
  export_epsg = sf::st_crs(exported)$epsg), "national_map_spatial_qa.csv", "docs")
message("National county map complete: ", nrow(national_counties), " counties/equivalents; ", retained, " colored.")

# Update the gallery idempotently, including when this script runs on its own.
gallery_path <- file.path("outputs", "graphics", "README.md")
gallery <- if (file.exists(gallery_path)) readLines(gallery_path) else c("# Review graphics", "")
gallery <- gallery[!grepl("us_county_caregiving_map_", gallery, fixed = TRUE)]
writeLines(c(gallery, paste0("![U.S. county caregiving map](us_county_caregiving_map_", acs_year, ".png)")), gallery_path)

# =========================================================
# STATE AND DC CHOROPLETH: use direct state estimates, never averages of county percentages.
# Dissolve the validated county boundaries into states; this preserves their documented vintage.
# =========================================================
state_path <- file.path("data_clean", "state_grandparent_caregiving.csv")
if (!file.exists(state_path)) stop("Run 02_states_and_dc.R before the state map.")
state_map_values <- readr::read_csv(state_path,
  col_types = cols(geoid = col_character(), .default = col_guess())) %>%
  mutate(map_pct_responsible = if_else(pct_responsible_exclusion == "Retained", pct_responsible, NA_real_))
stopifnot(nrow(state_map_values) == 51L, !anyDuplicated(state_map_values$geoid),
  setequal(state_map_values$geoid, state_scope), all(state_map_values$acs_year == acs_year))
state_geometries <- national_map_data %>% select(state_fips) %>%
  group_by(state_fips) %>% summarise(.groups = "drop") %>% rename(geoid = state_fips)
state_map_data <- state_geometries %>% left_join(state_map_values, by = "geoid", relationship = "one-to-one")
stopifnot(nrow(state_map_data) == 51L, !anyNA(state_map_data$name), all(sf::st_is_valid(state_map_data)))
state_projected <- sf::st_transform(state_map_data, 3857) %>% mutate(state_fips = geoid)
# Reuse the already wrapped Alaska county geometries solely for its display outline.
state_alaska <- alaska %>% select(state_fips) %>% group_by(state_fips) %>% summarise(.groups = "drop") %>%
  left_join(state_map_values, by = c("state_fips" = "geoid"), relationship = "one-to-one")
state_mainland_plot <- map_panel(state_projected %>% filter(!geoid %in% c("02", "15")), legend = TRUE)
state_alaska_plot <- map_panel(state_alaska, "Alaska")
state_hawaii_plot <- map_panel(state_projected %>% filter(geoid == "15"), "Hawaii")
# DC remains in the mainland map, and is enlarged below so its color can be read.
state_dc_plot <- map_panel(state_projected %>% filter(geoid == "11"), "District of Columbia")
state_caption <- stringr::str_wrap(paste0("Source: ", acs_period,
  " ACS five-year estimates, B10050. Direct estimates for 50 states and DC, not averages of county percentages. ",
  "Denominator: grandparents age 30+ living with their own grandchildren under 18. ",
  sum(state_map_values$pct_responsible_exclusion == "Retained"),
  " of 51 geographies colored. Gray = unavailable or fails the existing precision screen; not zero. ",
  "See state_map_data.csv for MOEs and exclusions. No significance claim. ",
  "Web Mercator (EPSG:3857); insets resized, Aleutians wrapped. Boundaries dissolved from ", acs_year,
  " Census cartographic counties. Plot: us_state_caregiving_map"), width = 165)
us_state_caregiving_map <- cowplot::ggdraw() +
  cowplot::draw_plot(state_mainland_plot, x = .02, y = .24, width = .96, height = .62) +
  cowplot::draw_plot(state_alaska_plot, x = .02, y = .10, width = .22, height = .27) +
  cowplot::draw_plot(state_hawaii_plot, x = .25, y = .11, width = .16, height = .15) +
  cowplot::draw_plot(state_dc_plot, x = .46, y = .11, width = .15, height = .15) +
  cowplot::draw_label("Grandparent caregiving across the states and DC", x = .025, y = .965,
    hjust = 0, vjust = 1, fontface = "bold", size = 21) +
  cowplot::draw_label(paste(acs_period, "| Share of co-resident grandparents responsible for grandchildren"),
    x = .025, y = .915, hjust = 0, vjust = 1, size = 13) +
  cowplot::draw_label(state_caption, x = .025, y = .025, hjust = 0, vjust = 0, size = 9, color = "gray35") +
  peeblestoolbox::add_peebles_watermark(size = 44, alpha = .16)
us_state_caregiving_map

peeblestoolbox::save_peebles_plot(us_state_caregiving_map, paste0("us_state_caregiving_map_", acs_year, ".png"),
  folder = file.path("outputs", "graphics"), width = 15, height = 10, dpi = 300, device = ragg::agg_png, bg = "white")
export_csv(state_map_values, "state_map_data.csv")
state_geojson <- peeblestoolbox::export_geojson(state_map_data, paste0("us_state_caregiving_", acs_year, ".geojson"),
  folder = "exports", overwrite = TRUE)
state_handoff <- sf::st_read(state_geojson, quiet = TRUE)
stopifnot(nrow(state_handoff) == 51L, setequal(state_handoff$geoid, state_scope),
  sf::st_crs(state_handoff)$epsg == 4326L, all(sf::st_is_valid(state_handoff)))
export_csv(tibble(geographies = nrow(state_map_data), unmatched = 0L, boundary_year = acs_year,
  boundary_method = "Dissolved matching-vintage Census cartographic county polygons",
  static_crs = sf::st_crs(state_projected)$Name, static_epsg = sf::st_crs(state_projected)$epsg,
  export_epsg = sf::st_crs(state_handoff)$epsg), "state_map_spatial_qa.csv", "docs")
gallery <- readLines(gallery_path)
gallery <- gallery[!grepl("us_state_caregiving_map_", gallery, fixed = TRUE)]
writeLines(c(gallery, paste0("![State and DC caregiving map](us_state_caregiving_map_", acs_year, ".png)")), gallery_path)
message("State choropleth complete. Display it again with: us_state_caregiving_map")
