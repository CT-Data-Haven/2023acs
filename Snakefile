from pathlib import Path
import os
from dotenv import load_dotenv

load_dotenv()
CENSUS_API_KEY = os.getenv('CENSUS_API_KEY')

#### SETUP ------
year = 2023
cws_year = 2024
cities = ["bridgeport", "hartford", "new_haven", "stamford"]
fetch_data = f"fetch_data/acs_basic_{year}_fetch_all.rds"

envvars:
    'CENSUS_API_KEY',

rule testvars:
    params:
        year = year,
        cws_year = cws_year,
    shell:
        'Rscript utils/pkgs_utils.R --testrun'

#### DATA PREP ------
rule download_meta:
    output:
        reg_puma = 'utils/reg_puma_list.rds',
    script:
        'scripts/00a_download_meta.sh'

rule meta:
    params:
        year = year,
        cws_year = cws_year,
    input:
        utils = 'utils/pkgs_utils.R',
        reg_puma = rules.download_meta.output.reg_puma,
    output:
        web = f'utils/{year}_website_meta.rds',
    script:
        'scripts/00_make_meta.R'

rule fetch:
    params:
        year = year,
    input:
        utils = 'utils/pkgs_utils.R',
        reg_puma = rules.download_meta.output.reg_puma,
    output:
        acs = f'fetch_data/acs_basic_{year}_fetch_all.rds',
    script:
        'scripts/01_fetch_acs_data.R'

rule calc_cws:
    params:
        cws_year = cws_year,
    input:
        utils = 'utils/pkgs_utils.R',
    output:
        cws_basic = f'output_data/cws_basic_indicators_{cws_year}.rds',
    script:
        'scripts/02_calc_cws_data.R'

rule calc_acs_towns:
    params:
        year = year,
    input:
        utils = 'utils/pkgs_utils.R',
        acs = rules.fetch.output.acs,
    output:
        acs_csv = f'output_data/acs_town_basic_profile_{year}.csv',
        acs_town = f'output_data/acs_town_basic_profile_{year}.rds',
        town_distro = f'to_distro/town_acs_basic_distro_{year}.csv',
    script:
        'scripts/03_calc_acs_towns.R'

rule calc_acs_nhoods:
    params:
        year = year,
    input:
        utils = 'utils/pkgs_utils.R',
        acs = rules.fetch.output.acs,
        hdrs = 'utils/indicator_headings.txt',
    output:
        acs_city = f'output_data/acs_nhoods_by_city_{year}.rds',
        cities_distro = expand(
            'to_distro/{city}_acs_basic_neighborhood_{yr}.csv',
            city = cities, yr = year
        ),
    script:
        'scripts/04_calc_acs_nhoods.R'

rule prep_distro:
    params:
        year = year,
        cws_year = cws_year,
    input:
        utils = 'utils/pkgs_utils.R',
        hdrs = 'utils/indicator_headings.txt',
        web = rules.meta.output.web,
        acs = rules.calc_acs_towns.output.acs_town,
        cws = rules.calc_cws.output.cws_basic,
    output:
        website_csv = f'website/5year{year}town_profile_expanded_CWS.csv',
    script:
        'scripts/05_assemble_for_distro.R'

rule release:
    input:
        town = rules.calc_acs_towns.output.acs_town,
        nhood = rules.calc_acs_nhoods.output.acs_city,
    output:
        flag = '.uploaded.json',
    shell:
        'bash scripts/upload_gh_release.sh {input.town} {input.nhood}'

#### FINAL OUTPUT ------
rule distro:
    input:
        rules.calc_acs_nhoods.output.acs_city,
        rules.prep_distro.output,

rule readme:
    input:
        smk = 'Snakefile',
        qmd = 'README.qmd',
    output:
        md = "README.md",
    shell:
        'quarto render {input.qmd}'

rule all:
    default_target: True
    input:
        rules.readme.output.md,
        rules.distro.input,

rule all_plus_release:
    input:
        rules.all.input,
        rules.release.output.flag

rule clean:
    shell:
        '''
        rm -f output_data/* \
            to_distro/* \
            fetch_data/* \
            website/* \
            utils/*.rds
        '''