# Purpose: draw review charts and county maps with uncertainty visible.
# Inputs: scripts 02-05 exports; Census cartographic county boundaries for acs_year.
# Outputs: four PNGs in outputs/graphics, plotting CSVs, WGS84 GeoJSON and spatial QA.
# Run after 05_reporter_brief.R and before 07_national_county_map.R. No imputation or significance claims.
source(file.path("scripts", "00_setup.R"))
for (package in c("sf", "tigris", "ragg")) {
  if (!requireNamespace(package, quietly = TRUE)) stop("Install graphics dependency: ", package)
}
graphics_dir <- file.path("outputs", "graphics")
dir.create(graphics_dir, showWarnings = FALSE, recursive = TRUE)
read_graphic_data <- function(filename) {
  path <- file.path("data_clean", filename)
  if (!file.exists(path)) stop("Missing ", path, "; run scripts 02-04 first.")
  x <- readr::read_csv(path, col_types = cols(geoid = col_character(), .default = col_guess()))
  stopifnot(!anyDuplicated(x$geoid), all(x$acs_year == acs_year))
  x
}
counties <- read_graphic_data("ga_counties_grandparents.csv")
states <- read_graphic_data("state_grandparent_caregiving.csv")
us <- read_graphic_data("us_grandparent_caregiving.csv")
source_note <- paste0("Source: ", acs_period, " ACS five-year estimates, table B10050. ",
                      "People age 30+ living with their own grandchildren under 18; responsibility is not legal custody.")
# Same explicit word-boundary wrapping approach inspected in the Iranian project.
plot_caption <- function(note, object_name) {
  stringr::str_wrap(paste(source_note, note, paste0("Plot: ", object_name)), width = 112)
}
chart_theme <- peeblestoolbox::theme_peebles_chart(base_size = 12, angle_x_labels = 0) +
  theme(plot.title.position = "plot", plot.caption.position = "plot",
        plot.margin = margin(18, 22, 16, 18), panel.grid.major.y = element_blank(),
        plot.caption = element_text(size = 9, hjust = 0, lineheight = 1.15))
review_mark <- function() peeblestoolbox::add_peebles_watermark(size = 36, alpha = 0.16)
save_graphic <- function(plot, stem, height = 7) {
  peeblestoolbox::save_peebles_plot(plot, paste0(stem, "_", acs_year, ".png"),
    folder = graphics_dir, width = 10, height = height, dpi = 300, device = ragg::agg_png, bg = "white")
}

# National context: full 0-100 scale and approximate 90% intervals.
context_data <- bind_rows(states %>% filter(geoid == "13"), us) %>%
  mutate(area = if_else(geoid == "13", "Georgia", "United States")) %>%
  select(geoid, area, pct_responsible, pct_responsible_moe,
         pct_responsible_ci90_lower, pct_responsible_ci90_upper, acs_period)
stopifnot(nrow(context_data) == 2L, !anyNA(context_data))
ga_us_caregiving_plot <- ggplot(context_data, aes(x = pct_responsible, y = area, color = area)) +
  geom_segment(aes(x = pct_responsible_ci90_lower, xend = pct_responsible_ci90_upper, yend = area), linewidth = 1.2) +
  geom_point(size = 2, shape = 21, fill = "white", stroke = 1) +
  geom_text(aes(label = sprintf("%.1f%% (+/- %.1f pp)", pct_responsible, pct_responsible_moe)), nudge_y = 0.20, size = 5, show.legend = FALSE) +
  scale_color_manual(values = c(Georgia = "#0057B8", `United States` = "#A04B18"), guide = "none") +
  scale_x_continuous(limits = c(0, 100), breaks = seq(0, 100, 20), labels = scales::label_percent(scale = 1)) +
  scale_y_discrete(limits = c("United States", "Georgia"), expand = expansion(add = 0.65)) +
  labs(title = "Grandparent caregiving in Georgia and the U.S.",
       subtitle = paste(acs_period, "| Share of co-resident grandparents responsible for grandchildren"),
       x = "Percent of co-resident grandparents", y = NULL,
       caption = plot_caption("Lines show 90% confidence intervals. Differences have not been tested for significance.", "ga_us_caregiving_plot")) +
  chart_theme + review_mark()
ga_us_caregiving_plot
save_graphic(ga_us_caregiving_plot, "georgia_us_caregiving", 5.5)
export_csv(context_data, "chart_georgia_us.csv")

# Count view retains noisy counts but distinguishes precision status.
count_data <- counties %>% filter(is.finite(estimate_responsible_total)) %>%
  arrange(desc(estimate_responsible_total), geoid) %>% slice_head(n = graphics_top_n) %>%
  mutate(county = str_remove(name, " County, Georgia$"),
         precision = case_when(is.na(moe_ratio) ~ "MOE unavailable", high_moe_flag ~ "MOE above 30% of count", TRUE ~ "MOE at most 30% of count"))
county_caregiver_count_plot <- ggplot(count_data,
  aes(x = estimate_responsible_total, y = reorder(county, estimate_responsible_total))) +
  geom_segment(data = count_data %>% filter(!is.na(moe_responsible_total)),
    aes(x = responsible_ci90_lower, xend = responsible_ci90_upper, yend = reorder(county, estimate_responsible_total)),
    color = "#596778", linewidth = 0.7) +
  geom_point(aes(color = precision), size = 3.3) +
  scale_color_manual(values = c("MOE at most 30% of count" = "#0057B8", "MOE above 30% of count" = "#A04B18", "MOE unavailable" = "#777777")) +
  scale_x_continuous(limits = c(0, NA), labels = scales::label_comma(), expand = expansion(mult = c(0, .04))) +
  labs(title = "Georgia counties with the most grandparent caregivers",
       subtitle = paste0(acs_period, " | Top ", nrow(count_data), " by estimated number responsible"),
       x = "Estimated grandparents responsible for grandchildren", y = NULL, color = NULL,
       caption = plot_caption(paste0("Lines show 90% confidence intervals. Order reflects point estimates, not proven differences. ",
         nrow(counties) - nrow(count_data), " counties are outside this top-count view."), "county_caregiver_count_plot")) +
  chart_theme + theme(legend.position = "bottom") + review_mark()
county_caregiver_count_plot
save_graphic(county_caregiver_count_plot, "georgia_county_caregiver_counts", 8)
export_csv(count_data, "chart_county_counts.csv")

# Cache exact boundary vintage and validate a one-to-one identifier join.
boundary_path <- file.path("data_raw", paste0("ga_counties_cb_", acs_year, "_500k.rds"))
if (!file.exists(boundary_path) || refresh_downloads) {
  boundaries <- peeblestoolbox::get_state_counties(state = "GA", year = acs_year,
    cb = TRUE, resolution = "500k", class = "sf", progress_bar = FALSE)
  saveRDS(list(layer = boundaries, retrieved_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)), boundary_path)
}
boundary_cache <- readRDS(boundary_path)
boundaries <- boundary_cache$layer %>% select(geoid = GEOID)
stopifnot(nrow(boundaries) == 159L, !anyDuplicated(boundaries$geoid), all(sf::st_is_valid(boundaries)),
          !any(sf::st_is_empty(boundaries)), setequal(boundaries$geoid, counties$geoid))
county_map_data <- boundaries %>% left_join(counties, by = "geoid", relationship = "one-to-one") %>%
  mutate(map_pct_responsible = if_else(pct_responsible_exclusion == "Retained", pct_responsible, NA_real_),
         map_percent_responsible_grandparents_five_plus_years = if_else(percent_responsible_grandparents_five_plus_years_exclusion == "Retained", percent_responsible_grandparents_five_plus_years, NA_real_)) %>%
  sf::st_transform(3857)
stopifnot(nrow(county_map_data) == nrow(counties), all(sf::st_is_valid(county_map_data)))
map_crs <- sf::st_crs(county_map_data)
map_note <- paste0("Static map: ", map_crs$Name, " (EPSG:", map_crs$epsg, ").")
map_plot <- function(metric, disposition, title, subtitle, legend_title, object_name) {
  retained <- sum(county_map_data[[disposition]] == "Retained")
  ggplot(county_map_data) + geom_sf(aes(fill = .data[[metric]]), color = "white", linewidth = 0.16) +
    scale_fill_viridis_c(option = "magma", begin = .15, end = .90, limits = c(0, 100),
      breaks = seq(0, 100, 25), labels = scales::label_percent(scale = 1), na.value = "#D4D6D8", name = legend_title) +
    coord_sf(crs = map_crs, datum = NA) +
    labs(title = title, subtitle = stringr::str_wrap(paste(acs_period, "|", subtitle), 85),
      caption = plot_caption(paste0(retained, " of ", nrow(county_map_data), " counties colored. Gray = unavailable or fails precision screen; not zero. ",
        "Screen: count and mapped-percentage MOEs at most ", severe_moe_threshold * 100,
        "% of their estimates. See map_county_data.csv for MOEs and exclusion reasons. ", map_note), object_name)) +
    peeblestoolbox::theme_peebles_map(base_size = 12, legend_position = "right") +
    theme(plot.title.position = "plot", plot.caption.position = "plot", plot.margin = margin(18, 20, 16, 18),
      plot.caption = element_text(size = 9, hjust = 0, lineheight = 1.15), legend.title = element_text(size = 11)) + review_mark()
}
county_caregiving_map <- map_plot("map_pct_responsible", "pct_responsible_exclusion",
  "Grandparent caregiving across Georgia", "Share of co-resident grandparents responsible for grandchildren",
  "Responsible\n(%)", "county_caregiving_map")
county_caregiving_map
save_graphic(county_caregiving_map, "georgia_county_caregiving_map", 9)
county_long_term_map <- map_plot("map_percent_responsible_grandparents_five_plus_years", "percent_responsible_grandparents_five_plus_years_exclusion",
  "Long-term grandparent caregiving across Georgia", "Among grandparents responsible for grandchildren: share responsible for five years or more",
  "Five years\nor more (%)", "county_long_term_map")
county_long_term_map
save_graphic(county_long_term_map, "georgia_county_long_term_map", 9)
export_csv(sf::st_drop_geometry(county_map_data), "map_county_data.csv")
geojson_path <- peeblestoolbox::export_geojson(county_map_data, paste0("ga_county_caregiving_", acs_year, ".geojson"),
  folder = "exports", overwrite = TRUE)
handoff <- sf::st_read(geojson_path, quiet = TRUE)
stopifnot(sf::st_crs(handoff)$epsg == 4326L, nrow(handoff) == 159L,
          setequal(handoff$geoid, counties$geoid), all(sf::st_is_valid(handoff)))
export_csv(tibble(boundary_year = acs_year, resolution = "1:500,000 cartographic boundaries",
  retrieved_utc = boundary_cache$retrieved_utc,
  source = paste0("https://www2.census.gov/geo/tiger/GENZ", acs_year, "/shp/cb_", acs_year, "_13_county_500k.zip"),
  input_rows = nrow(boundaries), joined_rows = nrow(county_map_data), unmatched = 0L,
  static_crs = map_crs$Name, static_epsg = map_crs$epsg,
  export_crs = sf::st_crs(handoff)$Name, export_epsg = sf::st_crs(handoff)$epsg), "graphics_spatial_qa.csv", "docs")
writeLines(c(map_note, paste0("Datawrapper GeoJSON exported in ", sf::st_crs(handoff)$Name,
  " (EPSG:", sf::st_crs(handoff)$epsg, "). Verified after export.")), file.path("docs", "graphics_crs.txt"))
message("Four review graphics and WGS84 handoff complete. Next: 07_national_county_map.R")


stems <- c("georgia_us_caregiving", "georgia_county_caregiver_counts",
           "georgia_county_caregiving_map", "georgia_county_long_term_map")
gallery <- c("# Grandparent caregiving: review graphics", "", "**NOT FOR PUBLICATION**", "",
  paste(acs_period, "ACS five-year estimates. Charts show uncertainty; gray map counties are excluded, not zero."), "",
  "See [graphics notes](../../docs/graphics_notes.md) for definitions, uncertainty and handoff instructions.", "")
for (stem in stems) gallery <- c(gallery, paste0("![", gsub("_", " ", stem), "](", stem, "_", acs_year, ".png)"), "")
writeLines(gallery, file.path(graphics_dir, "README.md"))
