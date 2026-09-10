# Purpose: common retrieval, calculations and auditable exports.
# Inputs: settings from 00_setup.R and Census estimates/MOEs.
# Outputs: cached source tables, per-geography QA and analysis tables.
# Assumptions: 90% ACS MOEs; numerators are subsets of their denominators.
# Sourced by setup; not a standalone workflow step.

export_csv <- function(x, filename, directory = "outputs") {
  path <- file.path(directory, filename)
  # Brief file locks can occur in synced folders, even after Excel closes.
  # Retry only file-open errors; other failures still stop immediately.
  for (attempt in seq_len(4L)) {
    result <- tryCatch({
      readr::write_csv(x, path, na = "NA")
      NULL
    }, error = function(e) e)
    if (is.null(result)) return(invisible(x))
    if (!grepl("Cannot open file for writing", conditionMessage(result), fixed = TRUE)) stop(result)
    if (attempt == 4L) {
      stop("Cannot write ", path, " after four attempts. Close any app using this file; ",
           "if it is already closed, check sync activity and folder permissions.\n",
           conditionMessage(result), call. = FALSE)
    }
    message("File temporarily unavailable: ", path, "; retrying in ", attempt, " seconds.")
    Sys.sleep(attempt)
  }
}

get_source <- function(geography, vars = variables) {
  path <- file.path("data_raw", paste0(acs_survey, "_", acs_year, "_", geography, ".rds"))
  if (file.exists(path) && !refresh_downloads) {
    cached <- readRDS(path)
    if (!identical(cached$variables, vars) || !identical(cached$year, acs_year)) {
      stop("Cache settings differ. Set refresh_downloads <- TRUE in 00_setup.R.")
    }
  } else {
    if (!nzchar(Sys.getenv("CENSUS_API_KEY"))) {
      stop("Fresh Census downloads require CENSUS_API_KEY in your user .Renviron; restart R after saving it.")
    }
    message("Downloading ", geography, ": ", acs_period, " ACS five-year estimates.")
    # Toolbox supplies the verified state-specific retrieval helper.
    fetched <- if (geography %in% c("county", "place")) {
      peeblestoolbox::get_state_acs(geography, vars, state = "GA", year = acs_year,
                                  survey = acs_survey, output = "tidy", geometry = FALSE)
    } else {
      tidycensus::get_acs(if (geography == "us_county") "county" else if (geography == "us_place") "place" else geography, vars, year = acs_year, survey = acs_survey,
                         output = "tidy", geometry = FALSE)
    }
    cached <- list(data = janitor::clean_names(fetched), variables = vars, year = acs_year,
                   retrieved_utc = format(Sys.time(), tz = "UTC", usetz = TRUE))
    saveRDS(cached, path)
  }
  x <- cached$data
  if (anyDuplicated(x[c("geoid", "variable")])) stop("Duplicate Census geography-variable keys.")
  if (!setequal(unique(x$variable), names(vars))) stop("Unexpected Census variables.")
  if (any(table(x$geoid) != length(vars))) stop("Incomplete variable coverage.")
  export_csv(tibble(geography, year = acs_year, period = acs_period, survey = acs_survey,
                    retrieved_utc = cached$retrieved_utc,
                    source = paste0("https://api.census.gov/data/", acs_year, "/acs/acs5"),
                    variables = paste(vars, collapse = ";"),
                    raw_md5 = unname(tools::md5sum(path))),
             paste0("source_", geography, ".csv"), "docs")
  # Keep the raw response intact; make unavailable values explicit in an audit.
  unavailable <- x %>% filter(is.na(estimate) | is.na(moe) | estimate < 0 | moe < 0)
  export_csv(unavailable, paste0(geography, "_unavailable_inputs.csv"))
  cleaned <- x %>% mutate(estimate = if_else(estimate < 0, NA_real_, estimate),
                          moe = if_else(moe < 0, NA_real_, moe))
  reconciliation <- reconcile_counts(cleaned)
  export_csv(reconciliation, paste0(geography, "_reconciliation.csv"))
  statuses <- reconciliation %>% select(ends_with("_status")) %>%
    pivot_longer(everything(), names_to = "check", values_to = "status") %>% count(check, status)
  export_csv(statuses, paste0(geography, "_reconciliation_summary.csv"))
  if (any(statuses$status == "Mismatch")) stop("Count reconciliation failed; see ", geography, "_reconciliation.csv")
  message(geography, ": count reconciliations checked; ", sum(statuses$n[statuses$status == "Unable to verify"]), " unable to verify.")
  cleaned
}

safe_divide <- function(num, denom) {
  if_else(is.finite(num) & is.finite(denom) & denom > 0, num / denom, NA_real_)
}

percent_moe <- function(num, denom, mn, md) {
  valid <- is.finite(num) & is.finite(denom) & denom > 0 &
    is.finite(mn) & is.finite(md) & num >= 0 & num <= denom
  answer <- rep(NA_real_, length(num))
  answer[valid] <- suppressWarnings(tidycensus::moe_prop(
    num[valid], denom[valid], mn[valid], md[valid])) * 100
  answer
}

# Reconcile estimates only: MOEs do not add arithmetically. Missing inputs stay missing.
reconcile_counts <- function(raw) {
  wide <- raw %>% select(geoid, name, variable, estimate) %>%
    pivot_wider(names_from = variable, values_from = estimate)
  wide %>% mutate(
    duration_sum = rowSums(pick(all_of(names(duration_labels))), na.rm = FALSE),
    duration_difference = duration_sum - responsible_total,
    duration_reconciliation_status = case_when(
      is.na(duration_difference) ~ "Unable to verify",
      duration_difference == 0 ~ "Pass", TRUE ~ "Mismatch"),
    coresident_components_sum = responsible_total + not_responsible,
    coresident_difference = coresident_components_sum - coresident_grandparents_total,
    coresident_reconciliation_status = case_when(
      is.na(coresident_difference) ~ "Unable to verify",
      coresident_difference == 0 ~ "Pass", TRUE ~ "Mismatch")) %>%
    select(geoid, name, duration_sum, duration_difference, duration_reconciliation_status,
           coresident_components_sum, coresident_difference, coresident_reconciliation_status)
}

calculate_metrics <- function(raw) {
  reconciliation <- reconcile_counts(raw)
  if (any(reconciliation$duration_reconciliation_status == "Mismatch" |
          reconciliation$coresident_reconciliation_status == "Mismatch")) {
    stop("B10050 component counts do not reconcile; inspect the reconciliation audit.")
  }
  x <- raw %>% pivot_wider(id_cols = c(geoid, name), names_from = variable,
                           values_from = c(estimate, moe)) %>%
    left_join(reconciliation, by = c("geoid", "name"), relationship = "one-to-one")
  x <- x %>% mutate(
    pct_responsible = 100 * safe_divide(estimate_responsible_total, estimate_coresident_grandparents_total),
    moe_ratio = safe_divide(moe_responsible_total, estimate_responsible_total),
    moe_exceeds_estimate = moe_responsible_total > estimate_responsible_total,
    high_moe_flag = moe_ratio > high_moe_threshold,
    severe_moe_flag = moe_ratio > severe_moe_threshold,
    cv_responsible_percent = 100 * moe_ratio / qnorm(0.95),
    responsible_ci90_lower = pmax(0, estimate_responsible_total - moe_responsible_total),
    responsible_ci90_upper = estimate_responsible_total + moe_responsible_total,
    pct_responsible_moe = percent_moe(estimate_responsible_total, estimate_coresident_grandparents_total,
                                     moe_responsible_total, moe_coresident_grandparents_total))
  for (duration in names(duration_labels)) {
    metric <- paste0("percent_responsible_grandparents_", duration)
    x[[metric]] <- 100 * safe_divide(x[[paste0("estimate_", duration)]], x$estimate_responsible_total)
    x[[paste0(metric, "_moe")]] <- percent_moe(x[[paste0("estimate_", duration)]],
      x$estimate_responsible_total, x[[paste0("moe_", duration)]], x$moe_responsible_total)
  }
  for (metric in c("pct_responsible", duration_metrics)) {
    x[[paste0(metric, "_ci90_lower")]] <- pmax(0, x[[metric]] - x[[paste0(metric, "_moe")]])
    x[[paste0(metric, "_ci90_upper")]] <- pmin(100, x[[metric]] + x[[paste0(metric, "_moe")]])
    relative <- safe_divide(x[[paste0(metric, "_moe")]], x[[metric]])
    x[[paste0(metric, "_cv_percent")]] <- 100 * relative / qnorm(0.95)
    x[[paste0(metric, "_exclusion")]] <- case_when(
      !is.finite(x[[metric]]) ~ "Missing input or nonpositive denominator",
      !is.finite(relative) ~ "Unavailable MOE or zero percentage",
      relative > severe_moe_threshold ~ "Percentage MOE exceeds 50% of estimate",
      is.na(x$severe_moe_flag) ~ "Unavailable caregiver count precision",
      x$severe_moe_flag ~ "Caregiver count MOE exceeds 50% of estimate",
      TRUE ~ "Retained")
  }
  x %>% mutate(acs_year = acs_year, acs_period = acs_period, acs_product = "ACS five-year")
}

rank_metric <- function(x, metric, rank_name, screen = TRUE) {
  x <- x %>% filter(is.finite(.data[[metric]]))
  if (screen) x <- x %>% filter(.data[[paste0(metric, "_exclusion")]] == "Retained")
  x %>% mutate(!!rank_name := min_rank(desc(.data[[metric]]))) %>%
    arrange(.data[[rank_name]], geoid)
}

write_qa <- function(x, geography) {
  flags <- x %>% filter(is.na(high_moe_flag) | high_moe_flag |
    if_any(all_of(paste0(c("pct_responsible", duration_metrics), "_exclusion")), ~ .x != "Retained"))
  filename <- switch(geography, county = "georgia_county_qa_flags.csv",
                     place = "place_qa_flags.csv", state = "state_qa_flags.csv")
  export_csv(flags, filename)
  audit <- x %>% select(geoid, name, ends_with("_exclusion")) %>%
    pivot_longer(ends_with("_exclusion"), names_to = "metric", values_to = "reason")
  export_csv(audit, paste0(geography, "_ranking_audit.csv"))
  counts <- audit %>% count(metric, reason, name = "records") %>% mutate(received = nrow(x))
  export_csv(counts, paste0(geography, "_qa_summary.csv"))
  message(geography, ": ", nrow(x), " geographies; ", nrow(flags), " flagged. See QA outputs.")
  invisible(flags)
}

# National comparisons: competition rank descending; midrank percentile ascending.
# Percentile = 100 * (number below + half the tied group) / eligible N.
# Ties stay together; decile 10 is highest. Excluded records never receive a position.
national_positions <- function(value, reason) {
  eligible <- !is.na(reason) & reason == "Retained" & is.finite(value)
  n <- sum(eligible)
  position <- tibble(national_rank = rep(NA_integer_, length(value)),
    national_percentile = rep(NA_real_, length(value)), national_decile = rep(NA_integer_, length(value)),
    eligible_n = n, exclusion_reason = reason)
  position$exclusion_reason[!is.na(reason) & reason == "Retained" & !is.finite(value)] <- "Unavailable value"
  if (n > 0L) {
    position$national_rank[eligible] <- min_rank(desc(value[eligible]))
    position$national_percentile[eligible] <- 100 * (rank(value[eligible], ties.method = "average") - .5) / n
    position$national_decile[eligible] <- as.integer(pmin(10, pmax(1, ceiling(position$national_percentile[eligible] / 10))))
  }
  position
}

add_national_comparisons <- function(x, geography) {
  metric_settings <- tibble(
    metric = c("caregiver_count", "caregiving_percent", names(duration_labels)),
    value_column = c("estimate_responsible_total", "pct_responsible", duration_metrics),
    screen_column = c(NA_character_, "pct_responsible_exclusion", paste0(duration_metrics, "_exclusion")))
  if (geography == "place") metric_settings <- bind_rows(metric_settings,
    tibble(metric = "story_scale_caregiving_percent", value_column = "pct_responsible", screen_column = "story_scale_exclusion"))
  audits <- vector("list", nrow(metric_settings))
  for (i in seq_len(nrow(metric_settings))) {
    metric <- metric_settings$metric[i]
    value <- x[[metric_settings$value_column[i]]]
    reason <- if (is.na(metric_settings$screen_column[i])) {
      if_else(is.finite(value), "Retained", "Unavailable caregiver count")
    } else x[[metric_settings$screen_column[i]]]
    positions <- national_positions(value, reason)
    audits[[i]] <- bind_cols(x %>% select(geoid, name, state_fips, acs_period),
      tibble(metric = metric, value = value), positions)
    for (field in c("national_rank", "national_percentile", "national_decile", "eligible_n", "exclusion_reason")) {
      x[[paste0(field, "_", metric)]] <- positions[[field]]
    }
  }
  audit <- bind_rows(audits)
  export_csv(audit, paste0("national_", geography, "_ranking_audit.csv"))
  export_csv(audit %>% count(metric, exclusion_reason, name = "records") %>% mutate(received = nrow(x)),
    paste0("national_", geography, "_ranking_summary.csv"))
  x %>% arrange(national_rank_caregiving_percent, geoid)
}

# Read identifiers as text when present, without warnings about optional absent fields.
read_analysis_csv <- function(path) {
  header <- names(readr::read_csv(path, n_max = 0, col_types = cols(.default = col_character())))
  types <- cols(.default = col_guess())
  for (field in intersect(c("geoid", "state_fips", "county_geoid"), header)) types$cols[[field]] <- col_character()
  readr::read_csv(path, col_types = types)
}
