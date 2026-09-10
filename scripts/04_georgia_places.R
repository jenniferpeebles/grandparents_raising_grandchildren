# Purpose: compare all U.S. places nationally, retaining Georgia views and preserving count, rate, duration and story-scale outputs.
# Inputs: 00_setup.R; B10050 and B01003. Outputs: clean places, rankings, QA and seed CSVs.
# Run after 03 counties and before 05 reporter brief. Places include CDPs and consolidated-government balances.
source(file.path("scripts", "00_setup.R"))
place_raw <- get_source("us_place", c(population = "B01003_001", variables))

place_raw

export_csv(place_raw %>% filter(!substr(geoid, 1, 2) %in% us_state_fips), "national_place_scope_exclusions.csv")
place_raw <- place_raw %>% filter(substr(geoid, 1, 2) %in% us_state_fips)

place_wide <- calculate_metrics(place_raw) %>% mutate(state_fips = substr(geoid, 1, 2),
  caregivers_per_1000_population = 1000 * safe_divide(estimate_responsible_total, estimate_population),
  caregivers_per_1000_population_moe = 10 * percent_moe(estimate_responsible_total,
    estimate_population, moe_responsible_total, moe_population),
  story_scale_exclusion = case_when(
    is.na(estimate_coresident_grandparents_total) ~ "Unavailable denominator",
    estimate_coresident_grandparents_total < story_scale_threshold ~ "Denominator below story-scale threshold",
    TRUE ~ pct_responsible_exclusion))

stopifnot(setequal(unique(place_wide$state_fips), us_state_fips), !anyDuplicated(place_wide$geoid))
place_national_rankings <- add_national_comparisons(place_wide, "place")
place_national_rankings
export_csv(place_national_rankings, "us_places_grandparents.csv", "data_clean")
georgia_place_national_comparison <- place_national_rankings %>% filter(state_fips == "13")
georgia_place_national_comparison
export_csv(georgia_place_national_comparison, "georgia_place_national_comparison.csv")
ga_place_wide <- georgia_place_national_comparison

write_qa(ga_place_wide, "place")
export_csv(ga_place_wide %>% select(geoid, name, story_scale_exclusion), "place_story_scale_audit.csv")
place_by_count <- rank_metric(ga_place_wide, "estimate_responsible_total", "rank_by_count", FALSE)

place_by_count

place_by_rate <- rank_metric(ga_place_wide, "pct_responsible", "rank_by_rate")

place_by_rate

place_by_long_term <- rank_metric(ga_place_wide, "percent_responsible_grandparents_five_plus_years", "rank_long_term")

place_by_long_term

story_scale_rankings <- rank_metric(ga_place_wide %>% filter(story_scale_exclusion == "Retained"),
                                   "pct_responsible", "story_rank")

story_scale_rankings

consolidated_governments <- ga_place_wide %>%
  filter(str_detect(name, regex("Athens|Augusta|Columbus|Macon", ignore_case = TRUE))) %>%
  mutate(geography_note = "Census place or balance; not interchangeable with the full county. See docs/methodology.md.")

story_scale_rankings

stopifnot(nrow(consolidated_governments) == 4L)
export_csv(ga_place_wide, "ga_places_grandparents.csv", "data_clean")
export_csv(place_by_count, "place_rankings_by_count.csv")
export_csv(place_by_rate, "place_rankings_by_rate.csv")
export_csv(place_by_long_term, "place_rankings_long_term.csv")
export_csv(story_scale_rankings, "place_rankings_story_scale.csv")
export_csv(consolidated_governments, "consolidated_government_check.csv")
export_csv(story_scale_rankings %>% rename(place = name, population = estimate_population,
  coresident_grandparents_total = estimate_coresident_grandparents_total, responsible_total = estimate_responsible_total),
  "reporter_brief_places.csv")
message("Place analysis complete. Next: 05_reporter_brief.R")

# Explicit one-to-one place/county review; never infer county identity from a place name.
county_check <- readr::read_csv(file.path("data_clean", "ga_counties_grandparents.csv"),
  col_types = cols(geoid = col_character(), .default = col_guess()))
consolidated_crosswalk <- tribble(
  ~geoid, ~county_geoid,
  "1303440", "13059",
  "1304204", "13245",
  "1319000", "13215",
  "1349008", "13021")
stopifnot(!anyDuplicated(consolidated_crosswalk$geoid), !anyDuplicated(county_check$geoid),
          setequal(consolidated_governments$geoid, consolidated_crosswalk$geoid),
          all(consolidated_crosswalk$county_geoid %in% county_check$geoid))
consolidated_comparison <- consolidated_governments %>%
  select(geoid, name, estimate_responsible_total, pct_responsible, geography_note) %>%
  left_join(consolidated_crosswalk, by = "geoid", relationship = "one-to-one") %>%
  left_join(county_check %>% select(county_geoid = geoid, county_name = name,
    county_responsible_total = estimate_responsible_total, county_pct_responsible = pct_responsible),
    by = "county_geoid", relationship = "one-to-one")

county_check

stopifnot(nrow(consolidated_comparison) == 4L, !anyNA(consolidated_comparison$county_name))
export_csv(consolidated_comparison, "consolidated_county_comparison.csv")
