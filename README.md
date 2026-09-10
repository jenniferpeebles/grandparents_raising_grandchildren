# Grandparents raising grandchildren

Grandparents are special people. Where in Georgia are the most grandparents responsible for their grandchildren? Where does Georgia rate among the 50 states and D.C. for the frequency with which grandparents are responsible for their grandchildren? How many multigenerational homes are there where kids live with both their parents and grandparents? Let's find out using Census data. 

This R project uses the **2020–2024 American Community Survey five-year estimates** to examine states and D/C., U.S. counties and Census places, with Georgia comparisons. We'll be looking at ACS Table B10050 [see table on Census.gov](https://data.census.gov/table/ACSDT1Y2024.B10050) or [see more on CensusReporter.org](https://censusreporter.org/tables/B10050/).

**Important note.** Current rankings are reporting leads, not proof that places differ statistically. 

## How to get started

1. Clone the repository and open `grandparents_raising_grandchildren.Rproj` in RStudio.
2. Install the packages below once. PeeblesToolbox supplies the Georgia Census retrieval helper.
3. Obtain a [free Census API key](https://api.census.gov/data/key_signup.html). Store `CENSUS_API_KEY=your_key` in your **user-level** `.Renviron`, then restart R. Don't paste your API key directly into a script or commit it; that risks it winding up in git and possibly on GitHub. 4. Review the ordinary settings at the top of `scripts/00_setup.R`, then run:

```r
install.packages(c("tidyverse", "tidycensus", "janitor", "glue", "writexl", "remotes", "sf", "tigris", "ragg", "cowplot"))
remotes::install_github("jenniferpeebles/peeblestoolbox")
source("run_all.R", encoding = "UTF-8")
```

The script stops on errors and reports the next output to review. After the first download, raw response caches in `data_raw/` support reruns. Set `refresh_downloads <- TRUE` in setup to fetch again. Raw caches and credentials are ignored by Git; a fresh clone therefore needs network access and a key. Committed CSVs and the brief can be read without R or a key.

The `run_all` script automatically runs all the scripts in the proper order. If you are running scripts individually, run them in numeric order, 00 through 08. Verification checks the calculations and regenerated outputs; `helpers.R` is loaded by setup and is not a separate step. Installed package versions and R session details are recorded in `logs/session_info.txt`; source vintages, retrieval times and cache checksums are saved in `docs/source_*.csv`. This is a documented package setup, not an isolated dependency lockfile.

Once all the scripts have run, you can start looking for findings with [the reporter brief](outputs/reporter_brief.md). But be sure to read [the methodology](docs/methodology.md) before using a number. Use the links above for more background material on Census.gov and CensusReporter.org. 

## Where things live

| Location | Contents |
|---|---|
| `run_all.R` | Runs every numbered step, including final verification |
| `scripts/00_setup.R` | Year, thresholds, download settings and dependencies |
| `scripts/01_recon_b10050_grandparents.R` | Census variable dictionary and meaning checks |
| `scripts/02_states_and_dc.R` | State rankings and direct U.S. comparison |
| `scripts/03_georgia_counties.R` | National counties, positions and the 159-county Georgia subset |
| `scripts/04_georgia_places.R` | National place positions, Georgia rankings and consolidated-government review |
| `scripts/05_reporter_brief.R` | Brief generated from current exports |
| `scripts/06_charts_and_maps.R` | Two ggplot charts, two county maps and WGS84 handoff |
| `scripts/07_national_county_map.R` | National county and state/D.C. choropleths with insets |
| `scripts/08_verify.R` | Final analytical and output checks |
| `data_clean/` | Estimates, margins of errors, percentages, confidence intervals and flags |
| `outputs/` | Reporter brief, rankings and record-level exclusion audits |
| `docs/` | Methods, variable dictionary, source notes and release review |

The percentage responsible uses **grandparents age 30 or older living with their own grandchildren under 18** as the denominator. It is not the percentage of all grandparents, households or children. Note that responsibility for a child does not establish legal custody or tell us whether parents live in the home. Five-year ACS data describe a 60-month collection period.

Be careful because this can really trip you up: The five duration percentage variables describe **grandparents responsible for their grandchildren**. They do not use all co-resident grandparents as the denominator. See [duration definitions and renamed columns](docs/duration_denominators.md) and the [duration composition table](outputs/reporter_duration_composition.csv).

For Georgia's position among U.S. counties and places, start with the [national comparison brief](outputs/georgia_national_comparison_brief.md) and [rank/percentile/decile definitions](docs/national_comparisons.md).

The code also creates [six review graphics](outputs/graphics/README.md): Georgia versus the U.S., top county counts, a county caregiving-percentage map a county long-term-percentage map, a national county caregiving map, and a 50-state/DC choropleth. All carry review watermarks. The charts show 90 percent uncertainty; the maps gray out estimates failing the existing precision rules. See [graphics notes](docs/graphics_notes.md).

## Special thanks
This project uses a number of R packages, including the [tidyverse family of packages](https://tidyverse.tidyverse.org/index.html) created by [Hadley Wickham](https://hadley.nz/) et al and the [tidycensus](https://walker-data.com/tidycensus/) and [tigris](https://cran.r-project.org/web/packages/tigris/index.html) packages created by [Kyle Walker](https://walker-data.com/) that downloads and works with U.S. Census Bureau data and geographic files. I am also very grateful for packages including [janitor](https://cran.r-project.org/web/packages/janitor/index.html) and [sf](https://cran.r-project.org/web/packages/sf/index.html), among others. Thank you to the brilliant people behind these packages who wrote all that code and keep it maintained. Also, thank you to the many people behind CensusReporter.org. 

## Authorship

[Jennifer Peebles](https://www.ajc.com/staff/jennifer-peebles/) / [Atlanta Journal-Constitution](https://www.ajc.com/)

>A note from JP: I built this project with help from ChatGPT/Codex, which drafted this README from the project's code, outputs and my instructions. I want to be transparent about the help I received.

