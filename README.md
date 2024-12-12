# 2023 ACS update & community profiles


<!-- README.md is generated from README.Rmd. Please edit that file -->

Distribution-ready files are in [`to_distro`](to_distro). CSV file for
populating website’s community profiles is in [`website`](website).

## Output

                              levelName

1 .  
2 °–output_data  
3 °–cws_basic_indicators_2024.rds

## Development

Several global functions and other objects are loaded when each script
sources `utils/pkgs_utils.R`, including all loaded libraries. There are
two global variables for years: `yr` and `cws_yr`, for the ACS endyear
and the CWS year, respectively. Those are both taken as positional
arguments by `pkgs_utils.R` and passed down to whatever script you want
to run.

For example, on the command line run:

``` bash
Rscript scripts/03_calc_acs_towns.R 2022 2021
```

to execute that script for ACS year 2022 & CWS year 2021. Similarly,
those 2 variables are saved in the snakefile and passed to scripts from
there.

To build the full project in the proper order, on the command line run:

``` bash
snakemake all
```

or rebuild just once piece of it, e.g. `snakemake prep_distro`.

Calling `snakemake testvars` will verify what years are being used by
sourcing just `utils/pkgs_utils.R`.

Additionally, this repo has a release of data in order to have a single
source of the year’s ACS data for other projects. To create and upload
the release, run:

``` bash
snakemake release
```

    Building DAG of jobs...

![snakefile](dag.png)
