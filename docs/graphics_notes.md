# Charts and maps for review

Run `source("run_all.R")` from the repository root, or run `scripts/06_charts_and_maps.R` after steps 02-05. Final verification is now step 08, after the national map. Additional packages are sf, tigris and ragg. The first map run requires network access to Census cartographic boundaries; later runs use the ignored raw cache unless refresh_downloads is TRUE.

The [graphics gallery](../outputs/graphics/README.md) contains five 300-dpi PNGs. Each plot has a named R object, appears when run interactively, and uses PeeblesToolbox themes, watermark and save helpers. All are INTERNAL REVIEW, NOT FOR PUBLICATION.

- `ga_us_caregiving_plot`: Georgia and the direct U.S. estimate, with 90% intervals and percentage-point MOEs in labels. The axis is 0-100%. No significance test is implied.
- `county_caregiver_count_plot`: top 15 county counts (configurable via graphics_top_n in setup), with 90% intervals. Counts remain visible despite uncertainty; orange points flag count MOEs above 30%. Missing MOEs, if present, receive a separate category and no fabricated interval.
- `county_caregiving_map`: percentage responsible among co-resident grandparents.
- `county_long_term_map`: percentage responsible for five years or more among responsible grandparents. This denominator differs from the first map.

Both county maps use a continuous 0-100% magma color scale. Gray explicitly means unavailable or excluded by the existing per-metric precision screen, not zero. Each mapped column (`map_pct_responsible`, `map_percent_responsible_grandparents_five_plus_years`) is NA for excluded rows; original estimates, MOEs, intervals and reasons remain alongside it for audit. These colors do not establish a statistically significant geographic pattern. Counties are not labeled individually on these statewide overview maps; identify them using the named, GEOID-keyed handoff data before local reporting.

Boundary vintage matches the configured ACS release, at 1:500,000 cartographic resolution. PeeblesToolbox retrieves county polygons. The script rejects duplicate keys, invalid/empty geometries and unmatched identifiers before a one-to-one join across all 159 counties. It does not calculate areas or distances. Static projection is Web Mercator (EPSG:3857). The GeoJSON handoff is WGS84 (EPSG:4326), verified after writing; actual CRS notes and source retrieval metadata are saved in docs/graphics_crs.txt and docs/graphics_spatial_qa.csv.

`outputs/chart_georgia_us.csv`, `outputs/chart_county_counts.csv` and `outputs/map_county_data.csv` are the plotted data. For Pete/Datawrapper, use `exports/ga_county_caregiving_2024.geojson` with the screened `map_*` fields. Keep excluded values gray and include the ACS period, denominator and uncertainty caveats. Geometry is generalized for statewide display, not parcel-scale analysis.

Caption wrapping follows the inspected Iranian population project's stringr::str_wrap approach. No project ajc_design.md was present. Typography, colors and watermark use the available Toolbox helpers. The first render exposed a metadata-column name collision; it was fixed before accepting the spatial QA output. Four exports were visually inspected for clipping, caption wrapping, legends and watermark placement; the national chart was revised to print MOEs because small intervals were hard to see.

#peeblestoolbox: a reusable caption wrapper remains a candidate; the explicit wrapping here follows the existing Iranian project implementation. No new general-purpose plotting system was introduced.

Validation: the complete root run_all.R pipeline passed during PR-readiness review on 2026-09-07, regenerating all five graphics and passing step 08 verification. An earlier attempt encountered a locked CSV; the subsequent full run completed without that file-write error.

## National county map

Step 07 adds `us_county_caregiving_map`, a single 15-by-10-inch, 300-dpi PNG for all counties and county equivalents in the 50 states and DC. It uses the same B10050 caregiving percentage, 0-100% magma palette and per-metric precision screen as the Georgia caregiving map. Gray means unavailable or excluded, never zero. Territories are outside this 50-state/DC scope; retrieved out-of-scope data are recorded in the scope-exclusions CSV.

The national estimates use a separate cache and a national tidycensus request; Georgia's original cache is preserved. National county polygons use the same release year and 1:500,000 cartographic resolution. Missing identifiers on either side of the one-to-one join cause a stop and produce audit tables. County equivalents include Alaska boroughs/census areas, independent cities, DC and Connecticut planning regions as supplied by the release.

The mainland and inset panels use Web Mercator (EPSG:3857). Alaska and Hawaii are resized insets, not at a common scale. Alaska's eastern-dateline polygon fragments move one Web Mercator world-width west for display only, keeping the Aleutian islands together without dropping county records. The WGS84 (EPSG:4326) GeoJSON retains original, unshifted locations. No area comparisons should be inferred from the insets.

Review `data_clean/us_counties_grandparents.csv`, `outputs/national_county_map_audit.csv`, `outputs/national_county_map_summary.csv` and `docs/national_map_spatial_qa.csv`. Handoff: `exports/us_county_caregiving_2024.geojson`, using `map_pct_responsible` for colors. National data are checked against the Georgia data and the exported GeoJSON. Verification is now step 08 and runs last. Cowplot arranges the ggplot panels; install it with the other graphics dependencies.

## State and DC choropleth

Step 07 also creates `us_state_caregiving_map`, displayed by its own standalone object-name line and saved as `outputs/graphics/us_state_caregiving_map_2024.png`. Its 51 percentages come directly from the state analysis, not from averaging county values. It uses the same 0-100 magma scale and caregiving precision screen. The denominator is co-resident grandparents age 30+ with their own grandchildren under 18.

State outlines dissolve the already validated, matching-vintage county polygons; no estimates are summed in this process. The map uses Web Mercator with Alaska and Hawaii insets and an enlarged DC inset so DC's fill can be read. DC also remains in its true location on the mainland. Insets are not at a common scale. The unshifted WGS84 export contains exactly 51 records. Data and audits: `outputs/state_map_data.csv`, `docs/state_map_spatial_qa.csv`, and `exports/us_state_caregiving_2024.geojson`. Use `map_pct_responsible` for handoff colors.
