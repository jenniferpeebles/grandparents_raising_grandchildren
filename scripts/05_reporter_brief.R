# Purpose: create a deterministic reporter brief from the corrected current-run exports.
# Inputs: scripts 02-04 outputs. Outputs: reporter_brief.md and reporter_brief_summary.csv.
# Run after 04 places and before 06 charts and maps. Point-estimate rankings are exploratory, not tests of differences.
source(file.path("scripts", "00_setup.R"))
read_required <- function(filename, directory = "outputs") {
  path <- file.path(directory, filename)
  if (!file.exists(path)) stop("Missing ", path, ". Run scripts 02-04 first.")
  x <- read_analysis_csv(path)
  if (!"acs_year" %in% names(x) || any(x$acs_year != acs_year)) stop("Stale input: ", path)
  x
}
states <- read_required("state_grandparent_caregiving.csv", "data_clean")
counties <- read_required("ga_counties_grandparents.csv", "data_clean")
places <- read_required("ga_places_grandparents.csv", "data_clean")
georgia <- read_required("georgia_rank_summary.csv")
us <- read_required("us_grandparent_caregiving.csv", "data_clean")
top_counties <- read_required("top_counties_by_rate.csv") %>% slice_head(n = 10)
top_long_term_counties <- read_required("top_counties_long_term.csv") %>% slice_head(n = 10)
top_places <- read_required("place_rankings_story_scale.csv") %>% slice_head(n = 10)
stopifnot(nrow(georgia) == 1L, nrow(us) == 1L)
fmt <- function(x, digits = 1) ifelse(is.finite(x), format(round(x, digits), big.mark = ",", trim = TRUE), "unavailable")
entry_lines <- function(x, metric) {
  if (!nrow(x)) return("- No estimates pass the configured screens.")
  paste0("- ", x$name, ": ", fmt(x[[metric]]), "% +/- ", fmt(x[[paste0(metric, "_moe")]]),
         " percentage points (90% MOE).")
}
# One reporter-facing row per geography and duration, with the denominator spelled out.
duration_sources <- bind_rows(states %>% mutate(geography_type = "State/DC"),
  us %>% mutate(geography_type = "United States"), counties %>% mutate(geography_type = "Georgia county"),
  places %>% mutate(geography_type = "Georgia place"))
duration_composition <- purrr::map_dfr(names(duration_labels), function(duration) {
  metric <- paste0("percent_responsible_grandparents_", duration)
  duration_sources %>% transmute(geography_type, geoid, name, acs_period,
    source_variable = unname(variables[[duration]]), duration = unname(duration_labels[[duration]]),
    estimate_grandparents_in_duration = .data[[paste0("estimate_", duration)]],
    moe_grandparents_in_duration = .data[[paste0("moe_", duration)]],
    denominator_responsible_grandparents = estimate_responsible_total,
    denominator_moe = moe_responsible_total,
    percent_of_responsible_grandparents = .data[[metric]],
    percent_moe = .data[[paste0(metric, "_moe")]],
    percent_ci90_lower = .data[[paste0(metric, "_ci90_lower")]],
    percent_ci90_upper = .data[[paste0(metric, "_ci90_upper")]],
    precision_disposition = .data[[paste0(metric, "_exclusion")]], duration_reconciliation_status)
})
export_csv(duration_composition, "reporter_duration_composition.csv")
ga_durations <- duration_composition %>% filter(geography_type == "State/DC", geoid == "13")
duration_lines <- c("## Duration among Georgia grandparents responsible for grandchildren", "",
  "Every percentage below uses responsible grandparents as its denominator, not all co-resident grandparents.", "",
  paste0("- ", ga_durations$duration, ": ", fmt(ga_durations$percent_of_responsible_grandparents),
    "% +/- ", fmt(ga_durations$percent_moe), " percentage points (90% MOE; ", ga_durations$precision_disposition, ")."), "")
brief_lines <- c(
  "# Reporter brief", "", "**INTERNAL REVIEW -- NOT FOR PUBLICATION**", "",
  paste0("Source: ", acs_period, " ACS five-year estimates, B10050; B01003 for place population."), "",
  "## Georgia in national context", "",
  paste0("- An estimated ", fmt(georgia$estimate_responsible_total, 0), " +/- ",
         fmt(georgia$moe_responsible_total, 0), " Georgia grandparents age 30 or older were responsible for their own co-resident grandchildren under 18 (90% MOE)."),
  paste0("- Among grandparents age 30 or older living with their own grandchildren under 18, ",
         fmt(georgia$pct_responsible), "% +/- ", fmt(georgia$pct_responsible_moe), " percentage points were responsible for them."),
  paste0("- Georgia's point-estimate rank: ", fmt(georgia$national_rank, 0), " among ", nrow(states),
         " states and DC. Rank differences have not been tested for statistical significance."),
  paste0("- Direct U.S. estimate: ", fmt(us$pct_responsible), "% +/- ", fmt(us$pct_responsible_moe),
         " percentage points. Georgia-minus-U.S. difference: ", fmt(georgia$difference_from_average),
         " percentage points; no significance claim."),
  paste0("- Among Georgia's responsible grandparents, ", fmt(georgia$percent_responsible_grandparents_five_plus_years), "% +/- ",
         fmt(georgia$percent_responsible_grandparents_five_plus_years_moe), " percentage points had been responsible for five years or more."), "",
  duration_lines, "## Highest county caregiving percentages passing the screens", "",
  entry_lines(top_counties, "pct_responsible"), "",
  "## Highest county long-term percentages passing the screens", "",
  "Among grandparents responsible for their grandchildren, the share responsible for five years or more:", "",
  entry_lines(top_long_term_counties, "percent_responsible_grandparents_five_plus_years"), "",
  "## Georgia places for follow-up", "",
  paste0("Places require at least ", story_scale_threshold, " co-resident grandparents and must pass the precision screens."), "",
  entry_lines(top_places, "pct_responsible"), "",
  "## QA and do-not-overstate notes", "",
  paste0("- County caregiving rankings retain ", sum(counties$pct_responsible_exclusion == "Retained"),
         " of ", nrow(counties), "; long-term rankings retain ", sum(counties$percent_responsible_grandparents_five_plus_years_exclusion == "Retained"), "."),
  paste0("- Place story-scale rankings retain ", sum(places$story_scale_exclusion == "Retained"), " of ", nrow(places), "."),
  "- Each ranking has a saved audit of retained and excluded records. See the QA CSVs for specific reasons.",
  "- These estimates count people, not grandchildren, families or households. Two grandparents may be in one household.",
  "- Responsibility is not equivalent to legal custody, nor does it mean parents are absent.",
  "- This is one 60-month period estimate, not a count for a single year or a time trend.",
  "- County and place rows overlap. Do not add them together. Consolidated-government balances are not entire counties.",
  "- Screens are editorial review rules, not Census designations of reliability. Remaining estimates still have uncertainty.", "",
  "## Reporting questions", "",
  "- What financial, school-enrollment and legal-support barriers do caregivers describe?",
  "- Do local service providers see needs consistent with these estimates?",
  "- Are apparent differences still compelling after reviewing uncertainty and geography?", "",
  "## Useful next graphics", "",
  "- Compare Georgia and the U.S. with percentage-point error bars.",
  "- Use a county count chart with margins of error to identify places for reporting.")
writeLines(brief_lines, file.path("outputs", "reporter_brief.md"))
export_csv(bind_rows(top_counties %>% mutate(section = "Top counties"),
  top_long_term_counties %>% mutate(section = "Long-term counties"),
  top_places %>% mutate(section = "Places")), "reporter_brief_summary.csv")
message("Reporter brief complete: outputs/reporter_brief.md")

# National positions are computed before the Georgia filter in scripts 03-04.
national_county_context <- read_required("georgia_county_national_comparison.csv")
national_place_context <- read_required("georgia_place_national_comparison.csv")
position_lines <- function(x, metric) {
  rank_column <- paste0("national_rank_", metric)
  candidates <- x %>% filter(!is.na(.data[[rank_column]])) %>% arrange(.data[[rank_column]], geoid) %>% slice_head(n = 10)
  if (!nrow(candidates)) return("- No Georgia observations meet this comparison's eligibility rules.")
  paste0("- ", candidates$name, ": ", fmt(candidates$pct_responsible), "% +/- ", fmt(candidates$pct_responsible_moe),
    " percentage points; national rank ", fmt(candidates[[rank_column]], 0), " of ",
    fmt(candidates[[paste0("eligible_n_", metric)]], 0), " eligible; percentile ",
    fmt(candidates[[paste0("national_percentile_", metric)]], 2), "; decile ",
    fmt(candidates[[paste0("national_decile_", metric)]], 0), ".")
}
writeLines(c("# Georgia in national county and place comparisons", "", "**INTERNAL REVIEW -- NOT FOR PUBLICATION**", "",
  paste0(acs_period, " ACS five-year estimates, B10050. Percentage responsible among co-resident grandparents age 30+."), "",
  "Rank 1 is highest. Higher percentiles and decile 10 mean higher estimates, not better outcomes. Ties share positions; differences are not significance tests.", "",
  "## Highest nationally ranked Georgia counties by caregiving percentage", "",
  paste0(sum(!is.na(national_county_context$national_rank_caregiving_percent)), " of ", nrow(national_county_context),
    " Georgia counties pass the national caregiving comparison's precision screens."), "",
  position_lines(national_county_context, "caregiving_percent"), "",
  "## Highest nationally ranked Georgia places in the minimum-size comparison", "",
  paste0("At least ", story_scale_threshold, " co-resident grandparents plus the precision screens; ",
    sum(!is.na(national_place_context$national_rank_story_scale_caregiving_percent)), " of ", nrow(national_place_context), " Georgia places eligible."), "",
  position_lines(national_place_context, "story_scale_caregiving_percent"), "",
  "Full CSVs retain every Georgia observation, including unranked observations and their exclusion reasons. Percentiles use the number below plus half the tied group, divided by eligible N. See docs/national_comparisons.md."),
  file.path("outputs", "georgia_national_comparison_brief.md"))