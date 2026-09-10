# Purpose: regenerate the full analysis in order, stopping on the first error.
# Inputs: configured Census access or cached raw responses. Outputs: all documented artifacts and session log.
# Run from the repository root. A successful run does not constitute editorial approval.
# Warnings must not masquerade as a complete run (including truncated source-file reads).
options(warn = 2)
steps <- c(
  "00_setup.R",
  "01_recon_b10050_grandparents.R",
  "02_states_and_dc.R",
  "03_georgia_counties.R",
  "04_georgia_places.R",
  "05_reporter_brief.R",
  "06_charts_and_maps.R",
  "07_national_county_map.R",
  "08_verify.R"
)
for (step in steps) {
  message("Running ", step)
  source(file.path("scripts", step), encoding = "UTF-8")
}
writeLines(capture.output(sessionInfo()),
           file.path("logs", "session_info.txt"))
message(
  "Pipeline complete. Read outputs/reporter_brief.md and docs/methodology.md before using results."
)
if (interactive() &&
    requireNamespace("beepr", quietly = TRUE))
  beepr::beep()
