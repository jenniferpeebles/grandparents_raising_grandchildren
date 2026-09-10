# Purpose: rank 50 states and DC and compare Georgia with the direct U.S. estimate.
# Inputs: 00_setup.R; Census B10050. Outputs: clean states, rankings and seed CSVs.
# Run after 01 reconnaissance and before 03 counties. Rankings describe point estimates, not significance.
source(file.path("scripts", "00_setup.R"))
state_raw <- get_source("state")
# Census state queries also return Puerto Rico; retain its exclusion in the audit.
export_csv(state_raw %>% filter(geoid == "72"),
           "state_scope_exclusions.csv")
state_raw <- state_raw %>% filter(geoid != "72")

state_raw

stopifnot(n_distinct(state_raw$geoid) == 51L)

state_wide <- calculate_metrics(state_raw)

state_raw

state_rankings <- state_wide %>% mutate(national_rank = min_rank(desc(pct_responsible))) %>%
  arrange(national_rank, geoid)

state_rankings

us <- calculate_metrics(get_source("us"))

us

stopifnot(nrow(us) == 1L)
export_csv(us, "us_grandparent_caregiving.csv", "data_clean")
georgia_summary <- state_rankings %>% filter(geoid == "13") %>% mutate(
  national_average_pct = us$pct_responsible,
  national_pct_moe = us$pct_responsible_moe,
  difference_from_average = pct_responsible - national_average_pct
)

georgia_summary

stopifnot(nrow(georgia_summary) == 1L)
write_qa(state_rankings, "state")
export_csv(state_rankings,
           "state_grandparent_caregiving.csv",
           "data_clean")
export_csv(georgia_summary, "georgia_rank_summary.csv")
export_csv(state_rankings %>% filter(!is.na(national_rank)) %>% slice_head(n = 10),
           "top_states_rankings.csv")
export_csv(
  state_rankings %>% filter(!is.na(national_rank)) %>% slice_tail(n = 10),
  "bottom_states_rankings.csv"
)
export_csv(
  state_rankings %>% rename(
    state = name,
    coresident_grandparents_total = estimate_coresident_grandparents_total,
    responsible_total = estimate_responsible_total
  ),
  "reporter_seed_state_rankings.csv"
)
print(
  georgia_summary %>% select(
    name,
    national_rank,
    pct_responsible,
    pct_responsible_moe,
    national_average_pct
  )
)
message("State analysis complete. Next: 03_georgia_counties.R")

