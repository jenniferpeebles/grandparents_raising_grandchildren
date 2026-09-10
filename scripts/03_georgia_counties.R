# Purpose: compare caregiving counts, percentages and duration across all U.S. counties, then locate Georgia within those national comparisons.
# Inputs: 00_setup.R; Census B10050. Outputs: clean counties, all legacy rankings, QA and seeds.
# Run after 02 states and before 04 places. Screen each percentage using its own uncertainty.
source(file.path("scripts", "00_setup.R"))


county_raw <- get_source("us_county")

county_raw

export_csv(
  county_raw %>% filter(!substr(geoid, 1, 2) %in% us_state_fips),
  "national_county_scope_exclusions.csv"
)
county_raw <- county_raw %>% filter(substr(geoid, 1, 2) %in% us_state_fips)
county_raw

county_wide <- calculate_metrics(county_raw) %>% mutate(
  state_fips = substr(geoid, 1, 2),
  map_pct_responsible = if_else(
    pct_responsible_exclusion == "Retained",
    pct_responsible,
    NA_real_
  ),
  five_core_county = geoid %in% c("13063", "13067", "13089", "13121", "13135")
)

county_wide

stopifnot(setequal(unique(county_wide$state_fips), us_state_fips),
          !anyDuplicated(county_wide$geoid))

county_national_rankings <- add_national_comparisons(county_wide, "county")

county_national_rankings
export_csv(county_national_rankings,
           "us_counties_grandparents.csv",
           "data_clean")
georgia_county_national_comparison <- county_national_rankings %>% filter(state_fips == "13")
georgia_county_national_comparison
stopifnot(nrow(georgia_county_national_comparison) == 159L)
export_csv(georgia_county_national_comparison,
           "georgia_county_national_comparison.csv")
ga_county_wide <- georgia_county_national_comparison
write_qa(ga_county_wide, "county")
top_counties_by_count <- rank_metric(ga_county_wide,
                                     "estimate_responsible_total",
                                     "rank_by_count",
                                     FALSE)

top_counties_by_count

top_counties_by_rate <- rank_metric(ga_county_wide, "pct_responsible", "rank_by_rate")

top_counties_by_rate

top_counties_long_term <- rank_metric(
  ga_county_wide,
  "percent_responsible_grandparents_five_plus_years",
  "rank_long_term"
)

top_counties_long_term

export_csv(ga_county_wide, "ga_counties_grandparents.csv", "data_clean")
export_csv(top_counties_by_count, "top_counties_by_count.csv")
export_csv(top_counties_by_rate, "top_counties_by_rate.csv")
export_csv(top_counties_long_term, "top_counties_long_term.csv")
export_csv(
  ga_county_wide %>% arrange(desc(pct_responsible)) %>% rename(
    county = name,
    coresident_grandparents_total = estimate_coresident_grandparents_total,
    responsible_total = estimate_responsible_total
  ),
  "reporter_brief_seed_counties.csv"
)

message("County analysis complete. Next: 04_georgia_places.R")
