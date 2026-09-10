# Purpose: generate the B10050 variable dictionary and assert the analytical meanings.
# Inputs: Census metadata for configured year. Outputs: CSV, XLSX and Markdown dictionary.
# Run first after setup; no analytical findings are generated here.
source(file.path("scripts", "00_setup.R"))
b10050_dictionary <- tidycensus::load_variables(acs_year, acs_survey, cache = TRUE) %>%
  janitor::clean_names() %>% filter(str_detect(name, "^B10050_"))

if (interactive()) View(b10050_dictionary)

expected <- c(B10050_002 = "Living with own grandchildren under 18 years:$",
              B10050_003 = "Grandparent responsible for own grandchildren under 18 years:$",
              B10050_004 = "Grandparent responsible less than 6 months$",
              B10050_005 = "Grandparent responsible 6 to 11 months$",
              B10050_006 = "Grandparent responsible 1 or 2 years$",
              B10050_007 = "Grandparent responsible 3 or 4 years$",
              B10050_008 = "Grandparent responsible 5 years or more$",
              B10050_009 = "Grandparent not responsible for own grandchildren under 18 years$")
stopifnot(setequal(names(expected), unname(variables)))
for (code in names(expected)) {
  label <- b10050_dictionary$label[b10050_dictionary$name == code]
  if (length(label) != 1L || !str_detect(label, expected[[code]])) {
    stop("Variable definition changed or missing: ",
         code,
         ". Review before analysis.")
  }
}
export_csv(b10050_dictionary, "b10050_variable_dictionary.csv", "docs")
writexl::write_xlsx(b10050_dictionary,
                    file.path("docs", "b10050_variable_dictionary.xlsx"))
lines <- c(
  "# ACS B10050 variable dictionary",
  "",
  paste(acs_period, "ACS five-year estimates."),
  "",
  "| Variable | Label | Concept |",
  "|---|---|---|"
)
lines <- c(lines, with(
  b10050_dictionary,
  paste0("| ", name, " | ", label, " | ", concept, " |")
))
writeLines(lines, file.path("docs", "b10050_variable_dictionary.md"))
message("Variable definitions verified. Next: 02_states_and_dc.R")
