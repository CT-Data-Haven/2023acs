# 2023 ACS update & community profiles


<!-- README.md is generated from README.Rmd. Please edit that file -->

Distribution-ready files are in [`to_distro`](to_distro). CSV file for
populating website’s community profiles is in [`website`](website).

## Output

                                                levelName
    1  .                                                 
    2   ¦--fetch_data                                    
    3   ¦   °--acs_basic_2023_fetch_all.rds              
    4   ¦--output_data                                   
    5   ¦   ¦--acs_nhoods_by_city_2023.rds               
    6   ¦   ¦--acs_town_basic_profile_2023.csv           
    7   ¦   ¦--acs_town_basic_profile_2023.rds           
    8   ¦   °--cws_basic_indicators_2024.rds             
    9   ¦--to_distro                                     
    10  ¦   ¦--bridgeport_acs_basic_neighborhood_2023.csv
    11  ¦   ¦--hartford_acs_basic_neighborhood_2023.csv  
    12  ¦   ¦--new_haven_acs_basic_neighborhood_2023.csv 
    13  ¦   ¦--stamford_acs_basic_neighborhood_2023.csv  
    14  ¦   °--town_acs_basic_distro_2023.csv            
    15  °--website                                       
    16      °--5year2023town_profile_expanded_CWS.csv    

## Development

Several global functions and other objects are loaded when each script
sources `utils/pkgs_utils.R`, including all loaded libraries. There are
two global variables for years: `yr` and `cws_yr`, for the ACS endyear
and the CWS year, respectively. Those are both set within the snakefile,
and can be taken as positional arguments by `pkgs_utils.R`.

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
