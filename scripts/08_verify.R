# Purpose: verify analytical edge cases and regenerated outputs; run after 07_national_county_map.R (the root runner runs this step last).
# Inputs: shared helpers and all clean/ranking exports. Outputs: docs/verification.txt.
# Assumptions: independent arithmetic checks use the configured source variable IDs.
source(file.path("scripts", "00_setup.R"))

stopifnot(identical(unname(variables), sprintf("B10050_%03d", 2:9)))
stopifnot(is.na(safe_divide(1, 0)),
          is.na(safe_divide(NA_real_, 10)),
          safe_divide(0, 10) == 0)
# Hand-calculated proportion MOE: 100 * sqrt(5^2 - .25^2 * 10^2) / 100.
stopifnot(isTRUE(all.equal(percent_moe(25, 100, 5, 10), sqrt(18.75))))
stopifnot(is.na(percent_moe(1, 0, 1, 1)), is.na(percent_moe(1, 10, NA_real_, 1)))
# Independent composition example and missingness/mismatch checks.
fixture <- tibble(
  geoid = "01",
  name = "Alabama",
  variable = names(variables),
  estimate = c(110944, 52977, 3203, 3522, 9991, 9066, 27195, 57967),
  moe = c(3125, 2341, 542, 594, 1216, 856, 1518, 2206)
)

fixture_metrics <- calculate_metrics(fixture)

stopifnot(
  fixture_metrics$duration_reconciliation_status == "Pass",
  fixture_metrics$coresident_reconciliation_status == "Pass",
  abs(
    fixture_metrics$percent_responsible_grandparents_five_plus_years - 100 * 27195 / 52977
  ) < 1e-10
)

missing_fixture <- fixture %>% mutate(estimate = if_else(variable == "less_than_six_months", NA_real_, estimate))

stopifnot(
  reconcile_counts(missing_fixture)$duration_reconciliation_status == "Unable to verify",
  is.na(
    calculate_metrics(missing_fixture)$percent_responsible_grandparents_less_than_six_months
  )
)


missing_total <- fixture %>% mutate(estimate = if_else(
  variable == "coresident_grandparents_total",
  NA_real_,
  estimate
))
stopifnot(
  reconcile_counts(missing_total)$coresident_reconciliation_status == "Unable to verify"
)
bad_fixture <- fixture %>% mutate(estimate = if_else(variable == "five_plus_years", estimate + 1, estimate))
stopifnot(
  reconcile_counts(bad_fixture)$duration_reconciliation_status == "Mismatch",
  inherits(tryCatch(
    calculate_metrics(bad_fixture),
    error = identity
  ), "error")
)
zero_fixture <- fixture %>% mutate(estimate = 0)
stopifnot(all(is.na(calculate_metrics(zero_fixture)[duration_metrics])))
ties <- tibble(geoid = c("01", "02", "03", "04"),
               score = c(8, 8, 2, NA_real_))
tie_ranks <- rank_metric(ties, "score", "rank", FALSE)
stopifnot(identical(tie_ranks$rank, c(1L, 1L, 3L)), nrow(tie_ranks) == 3L)

read_table <- function(path)
  read_analysis_csv(path)
files <- c(
  state = "state_grandparent_caregiving.csv",
  county = "ga_counties_grandparents.csv",
  place = "ga_places_grandparents.csv",
  us = "us_grandparent_caregiving.csv"
)
checks <- character()
for (geography in names(files)) {
  x <- read_table(file.path("data_clean", files[[geography]]))
  raw <- readRDS(file.path(
    "data_raw",
    paste0(
      acs_survey,
      "_",
      acs_year,
      "_",
      if (geography %in% c("county", "place"))
        paste0("us_", geography)
      else
        geography,
      ".rds"
    )
  ))$data
  if (geography == "state")
    raw <- raw %>% filter(geoid != "72")
  if (geography %in% c("county", "place"))
    raw <- raw %>% filter(substr(geoid, 1, 2) == "13")
  stopifnot(!anyDuplicated(x$geoid), all(x$acs_period == acs_period))
  for (metric in names(variables)) {
    input <- raw %>% filter(variable == metric) %>% arrange(geoid)
    actual <- x %>% arrange(geoid)
    stopifnot(identical(input$geoid, actual$geoid))
    stopifnot(isTRUE(all.equal(input$estimate, actual[[paste0("estimate_", metric)]])))
  }
  stopifnot(all(
    is.na(x$pct_responsible) |
      (x$pct_responsible >= 0 & x$pct_responsible <= 100)
  ))
  stopifnot(!any(vapply(x %>% select(where(is.numeric)), function(z)
    any(is.infinite(z)), logical(1))))
  stopifnot(isTRUE(all.equal(
    x$pct_responsible,
    100 * safe_divide(
      x$estimate_responsible_total,
      x$estimate_coresident_grandparents_total
    )
  )))
  for (duration in names(duration_labels)) {
    metric <- paste0("percent_responsible_grandparents_", duration)
    expected_duration <- 100 * safe_divide(x[[paste0("estimate_", duration)]], x$estimate_responsible_total)
    stopifnot(isTRUE(all.equal(x[[metric]], expected_duration)))
  }
  duration_sums <- rowSums(x[duration_metrics], na.rm = FALSE)
  stopifnot(
    all(abs(duration_sums[!is.na(duration_sums)] - 100) < 1e-8),!any(x$duration_reconciliation_status == "Mismatch"),
    !any(x$coresident_reconciliation_status == "Mismatch")
  )
  if (geography != "us") {
    audit <- read_table(file.path("outputs", paste0(geography, "_ranking_audit.csv")))
    stopifnot(all((audit %>% count(metric))$n == nrow(x)))
  }
  checks <- c(
    checks,
    paste(
      geography,
      nrow(x),
      "unique geographies: values reconcile to cached sources; percentages and audit counts checked."
    )
  )
}
rank_files <- c(
  "top_counties_by_rate.csv",
  "top_counties_long_term.csv",
  "place_rankings_by_rate.csv",
  "place_rankings_long_term.csv",
  "place_rankings_story_scale.csv"
)
for (filename in rank_files) {
  x <- read_table(file.path("outputs", filename))
  metric <- if (grepl("long_term", filename))
    "percent_responsible_grandparents_five_plus_years"
  else
    "pct_responsible"
  stopifnot(all(x[[paste0(metric, "_exclusion")]] == "Retained"))
  stopifnot(all(diff(x[[metric]]) <= 0))
}
brief_before <- tools::md5sum(file.path("outputs", "reporter_brief.md"))
source(file.path("scripts", "05_reporter_brief.R"))
stopifnot(identical(unname(brief_before), unname(tools::md5sum(
  file.path("outputs", "reporter_brief.md")
))))
brief <- readLines(file.path("outputs", "reporter_brief.md"))
stopifnot(any(grepl(acs_period, brief, fixed = TRUE)), any(grepl("INTERNAL REVIEW", brief)))
# Explicit output contract: works in a fresh repository or downloaded ZIP,
# without Git or any commits from the private development repository.
required_outputs <- c(
  file.path("data_clean", c(
    "state_grandparent_caregiving.csv", "us_grandparent_caregiving.csv",
    "ga_counties_grandparents.csv", "ga_places_grandparents.csv",
    "us_counties_grandparents.csv", "us_places_grandparents.csv"
  )),
  file.path("docs", paste0("b10050_variable_dictionary.", c("csv", "md", "xlsx"))),
  file.path("outputs", c(
    "top_states_rankings.csv", "bottom_states_rankings.csv",
    "georgia_rank_summary.csv", "reporter_seed_state_rankings.csv",
    "top_counties_by_count.csv", "top_counties_by_rate.csv", "top_counties_long_term.csv",
    "place_rankings_by_count.csv", "place_rankings_by_rate.csv",
    "place_rankings_long_term.csv", "place_rankings_story_scale.csv",
    "consolidated_government_check.csv", "consolidated_county_comparison.csv",
    "reporter_brief.md", "reporter_brief_summary.csv",
    "reporter_brief_seed_counties.csv", "reporter_brief_places.csv",
    "reporter_duration_composition.csv", "georgia_national_comparison_brief.md",
    "georgia_county_national_comparison.csv", "georgia_place_national_comparison.csv"
  ))
)
missing_outputs <- required_outputs[!file.exists(required_outputs)]
if (length(missing_outputs)) {
  stop("Required outputs are missing:\n", paste(missing_outputs, collapse = "\n"), call. = FALSE)
}
# Graphics must reflect the same current estimates and exclusions, including GeoJSON nulls.
map_csv <- read_table(file.path("outputs", "map_county_data.csv"))
county_source <- read_table(file.path("data_clean", "ga_counties_grandparents.csv")) %>% arrange(geoid)
map_csv <- map_csv %>% arrange(geoid)
stopifnot(identical(map_csv$geoid, county_source$geoid))
for (metric in c("pct_responsible",
                 "percent_responsible_grandparents_five_plus_years")) {
  expected <- if_else(county_source[[paste0(metric, "_exclusion")]] == "Retained", county_source[[metric]], NA_real_)
  stopifnot(isTRUE(all.equal(map_csv[[paste0("map_", metric)]], expected)))
}
exported_map <- sf::st_read(file.path(
  "exports",
  paste0("ga_county_caregiving_", acs_year, ".geojson")
), quiet = TRUE) %>% arrange(geoid)
stopifnot(
  nrow(exported_map) == nrow(map_csv),
  sf::st_crs(exported_map)$epsg == 4326L,
  all(sf::st_is_valid(exported_map)),
  identical(exported_map$geoid, map_csv$geoid)
)
stopifnot(isTRUE(
  all.equal(
    exported_map$map_pct_responsible,
    map_csv$map_pct_responsible
  )
))
stopifnot(isTRUE(
  all.equal(
    exported_map$map_percent_responsible_grandparents_five_plus_years,
    map_csv$map_percent_responsible_grandparents_five_plus_years
  )
))
spatial_qa <- readr::read_csv(file.path("docs", "graphics_spatial_qa.csv"),
                              show_col_types = FALSE)
stopifnot(
  spatial_qa$static_epsg == 3857L,
  spatial_qa$unmatched == 0L,
  spatial_qa$boundary_year == acs_year
)
chart_counts <- read_table(file.path("outputs", "chart_county_counts.csv"))
expected_counts <- county_source %>% filter(is.finite(estimate_responsible_total)) %>%
  arrange(desc(estimate_responsible_total), geoid) %>% slice_head(n = graphics_top_n)
stopifnot(identical(chart_counts$geoid, expected_counts$geoid),
          isTRUE(
            all.equal(
              chart_counts$estimate_responsible_total,
              expected_counts$estimate_responsible_total
            )
          ))
for (stem in c(
  "georgia_us_caregiving",
  "georgia_county_caregiver_counts",
  "georgia_county_caregiving_map",
  "georgia_county_long_term_map"
)) {
  path <- file.path("outputs", "graphics", paste0(stem, "_", acs_year, ".png"))
  stopifnot(file.exists(path), file.info(path)$size > 10000)
}
checks <- c(
  checks,
  "PASS: graphics count selection, screened map values, 159-county join, PNG exports and WGS84 GeoJSON round-trip."
)
# National map must reconcile with Georgia and preserve all scoped county identifiers.
national <- read_table(file.path("data_clean", "us_counties_grandparents.csv")) %>% arrange(geoid)
stopifnot(
  !anyDuplicated(national$geoid),
  n_distinct(national$state_fips) == 51L,
  all(national$acs_year == acs_year)
)
for (duration in names(duration_labels)) {
  expected_duration <- 100 * safe_divide(national[[paste0("estimate_", duration)]], national$estimate_responsible_total)
  stopifnot(isTRUE(all.equal(national[[paste0("percent_responsible_grandparents_", duration)]], expected_duration)))
}
stopifnot(
  !any(national$duration_reconciliation_status == "Mismatch"),!any(national$coresident_reconciliation_status == "Mismatch")
)
national_ga <- national %>% filter(state_fips == "13")
stopifnot(
  identical(national_ga$geoid, county_source$geoid),
  isTRUE(
    all.equal(national_ga$pct_responsible, county_source$pct_responsible)
  ),
  identical(
    national_ga$pct_responsible_exclusion,
    county_source$pct_responsible_exclusion
  )
)
expected <- if_else(
  national$pct_responsible_exclusion == "Retained",
  national$pct_responsible,
  NA_real_
)
stopifnot(isTRUE(all.equal(national$map_pct_responsible, expected)))
national_export <- sf::st_read(file.path(
  "exports",
  paste0("us_county_caregiving_", acs_year, ".geojson")
), quiet = TRUE) %>% arrange(geoid)
stopifnot(
  identical(national_export$geoid, national$geoid),
  sf::st_crs(national_export)$epsg == 4326L,
  all(sf::st_is_valid(national_export)),
  isTRUE(all.equal(
    national_export$map_pct_responsible, expected
  ))
)
national_qa <- readr::read_csv(file.path("docs", "national_map_spatial_qa.csv"),
                               show_col_types = FALSE)
stopifnot(
  national_qa$counties == nrow(national),
  national_qa$colored + national_qa$gray == nrow(national),
  national_qa$unmatched == 0L,
  national_qa$static_epsg == 3857L
)
stopifnot(file.info(file.path(
  "outputs",
  "graphics",
  paste0("us_county_caregiving_map_", acs_year, ".png")
))$size > 10000)
checks <- c(
  checks,
  "PASS: national county coverage, Georgia reconciliation, precision screen and unshifted WGS84 export."
)
state_plot_values <- read_table(file.path("outputs", "state_map_data.csv")) %>% arrange(geoid)
state_source <- read_table(file.path("data_clean", "state_grandparent_caregiving.csv")) %>% arrange(geoid)
stopifnot(
  nrow(state_plot_values) == 51L,
  identical(state_plot_values$geoid, state_source$geoid),
  isTRUE(
    all.equal(
      state_plot_values$pct_responsible,
      state_source$pct_responsible
    )
  )
)
state_expected <- if_else(
  state_source$pct_responsible_exclusion == "Retained",
  state_source$pct_responsible,
  NA_real_
)
stopifnot(isTRUE(
  all.equal(state_plot_values$map_pct_responsible, state_expected)
))
state_handoff_check <- sf::st_read(file.path(
  "exports",
  paste0("us_state_caregiving_", acs_year, ".geojson")
), quiet = TRUE) %>% arrange(geoid)
stopifnot(
  identical(state_handoff_check$geoid, state_source$geoid),
  sf::st_crs(state_handoff_check)$epsg == 4326L,
  all(sf::st_is_valid(state_handoff_check)),
  isTRUE(
    all.equal(state_handoff_check$map_pct_responsible, state_expected)
  ),
  file.info(file.path(
    "outputs",
    "graphics",
    paste0("us_state_caregiving_map_", acs_year, ".png")
  ))$size > 10000
)
checks <- c(
  checks,
  "PASS: 51-state/DC map values match direct state estimates; screened fills and WGS84 export reconcile."
)
# Ranking conventions: hand-calculated ties, all-equal, singleton and empty eligibility.
position_fixture <- national_positions(c(10, 20, 20, 30, NA_real_), c(rep("Retained", 4), "Unavailable"))
stopifnot(
  identical(position_fixture$national_rank, c(4L, 2L, 2L, 1L, NA_integer_)),
  identical(
    position_fixture$national_percentile,
    c(12.5, 50, 50, 87.5, NA_real_)
  ),
  identical(
    position_fixture$national_decile,
    c(2L, 5L, 5L, 9L, NA_integer_)
  )
)

stopifnot(
  national_positions(7, "Retained")$national_percentile == 50,
  all(national_positions(c(7, 7), c(
    "Retained", "Retained"
  ))$national_percentile == 50),
  all(is.na(
    national_positions(c(1, 2), c("Excluded", "Excluded"))$national_rank
  ))
)

for (geography in c("county", "place")) {
  nationwide <- read_table(
    file.path(
      "data_clean",
      if (geography == "county")
        "us_counties_grandparents.csv"
      else
        "us_places_grandparents.csv"
    )
  )
  
  georgia <- read_table(file.path(
    "outputs",
    paste0("georgia_", geography, "_national_comparison.csv")
  ))
  stopifnot(!anyDuplicated(nationwide$geoid),
            setequal(unique(nationwide$state_fips), us_state_fips))
  national_ga <- nationwide %>% filter(state_fips == "13") %>% arrange(geoid)
  georgia <- georgia %>% arrange(geoid)
  stopifnot(
    identical(georgia$geoid, national_ga$geoid),
    identical(
      georgia$national_rank_caregiving_percent,
      national_ga$national_rank_caregiving_percent
    ),
    identical(
      georgia$national_percentile_caregiving_percent,
      national_ga$national_percentile_caregiving_percent
    )
  )
  audit <- read_table(file.path(
    "outputs",
    paste0("national_", geography, "_ranking_audit.csv")
  ))
  stopifnot(!anyDuplicated(audit[c("geoid", "metric")]), all((audit %>% count(metric))$n == nrow(nationwide)))
  for (metric_name in unique(audit$metric)) {
    comparison <- audit %>% filter(metric == metric_name)
    retained <- comparison$exclusion_reason == "Retained"
    stopifnot(
      all(comparison$eligible_n == sum(retained)),
      all(is.na(comparison$national_rank[!retained])),
      all(is.na(comparison$national_percentile[!retained])),
      all(is.na(comparison$national_decile[!retained])),
      all(
        comparison$national_percentile[retained] > 0 &
          comparison$national_percentile[retained] < 100
      ),
      all(
        comparison$national_decile[retained] >= 1 &
          comparison$national_decile[retained] <= 10
      )
    )
    stopifnot(isTRUE(all.equal(
      as.numeric(comparison$national_rank[retained]),
      rank(-comparison$value[retained], ties.method = "min")
    )))
  }
  sums <- read_table(file.path(
    "outputs",
    paste0("national_", geography, "_ranking_summary.csv")
  ))
  stopifnot(all((
    sums %>% group_by(metric) %>% summarise(n = sum(records), .groups = "drop")
  )$n == nrow(nationwide)))
}

checks <- c(
  checks,
  "PASS: national county/place ranks, tied percentiles, deciles, exclusions, universe counts and Georgia positions."
)

writeLines(
  c(
    "PASS: analytical and output verification",
    checks,
    "PASS: five duration denominators, additive counts, missing-input status, mismatches, zero denominators, missing MOE and rank cases.",
    "PASS: eligible rankings, required artifact paths, period labeling and deterministic brief rerun.",
    "No significance tests or editorial publication approval are implied."
  ),
  file.path("docs", "verification.txt")
)

message("Verification passed. See docs/verification.txt")
