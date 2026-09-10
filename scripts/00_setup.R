# Purpose: configure and initialize the grandparents analysis from the repo root.
# Inputs: installed packages; Census key for fresh downloads, or verified raw caches.
# Outputs: project directories and shared settings. Run first (00), before 01 reconnaissance; later steps reload setup for standalone use.
# Assumptions: one 60-month ACS period; no imputation; no geographic aggregation.

# Windows launchers may inherit a Unix locale that R cannot use. Repair only non-UTF-8 Windows sessions.
if (.Platform$OS.type == "windows" &&
    !isTRUE(l10n_info()[["UTF-8"]])) {
  locale_result <- Sys.setlocale("LC_CTYPE", "English_United States.utf8")
  if (!nzchar(locale_result))
    stop("R needs a UTF-8 locale; restart R with a supported Windows locale.")
}

graphics_top_n <- 15L
acs_year <- 2024L
acs_survey <- "acs5"
story_scale_threshold <- 100
refresh_downloads <- FALSE
high_moe_threshold <- 0.30
severe_moe_threshold <- 0.50
acs_period <- paste0(acs_year - 4L, "-", acs_year)

if (!file.exists("grandparents_raising_grandchildren.Rproj")) {
  stop("Open grandparents_raising_grandchildren.Rproj and run from the repository root.")
}
for (directory in c("data_raw", "data_clean", "outputs", "exports", "docs", "logs")) {
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
}
packages <- c("tidyverse",
              "tidycensus",
              "janitor",
              "glue",
              "writexl",
              "peeblestoolbox")
missing_packages <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages))
  stop("Install required packages: ",
       paste(missing_packages, collapse = ", "))
suppressPackageStartupMessages(library(tidyverse))

# B10050 universe: population age 30 and over. These are PEOPLE, not households.
variables <- c(
  coresident_grandparents_total = "B10050_002",
  responsible_total = "B10050_003",
  less_than_six_months = "B10050_004",
  six_to_eleven_months = "B10050_005",
  one_or_two_years = "B10050_006",
  three_or_four_years = "B10050_007",
  five_plus_years = "B10050_008",
  not_responsible = "B10050_009"
)
# Duration categories partition responsible_total, not all co-resident grandparents.
duration_labels <- c(
  less_than_six_months = "Less than six months",
  six_to_eleven_months = "Six to eleven months",
  one_or_two_years = "One or two years",
  three_or_four_years = "Three or four years",
  five_plus_years = "Five years or more"
)
duration_metrics <- paste0("percent_responsible_grandparents_", names(duration_labels))
us_state_fips <- c("01", "02", "04", "05", "06", "08", "09", "10", "11", "12", "13", "15", "16",
  "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "31", "32",
  "33", "34", "35", "36", "37", "38", "39", "40", "41", "42", "44", "45", "46", "47", "48",
  "49", "50", "51", "53", "54", "55", "56")
source(file.path("scripts", "helpers.R"))
