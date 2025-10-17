# reads utils/reg_puma_list.rds
# writes fetch_data/acs_basic_yr_fetch_all.rds
source("utils/pkgs_utils.R")
######################################## LOOKUPS ###############################----
# include pumas that aren't counties, all tracts, neighborhoods, us, msas
# nhood profiles have state, region, cities, neighborhoods
nhood_lookup <- list(
    bridgeport = cwi::bridgeport_tracts,
    hartford = cwi::hartford_tracts,
    new_haven = cwi::new_haven_tracts,
    stamford = cwi::stamford_tracts
) |>
    rlang::set_names(stringr::str_remove, "_tracts") |>
    bind_rows(.id = "city") |>
    mutate(city = camiller::clean_titles(city, cap_all = TRUE)) |>
    tidyr::unite(name, city, name) |>
    select(name, geoid_cog, weight)

# no longer need PUMAs as regions--cwi can call them
# also keep out COGs
reg_puma_list <- readRDS("utils/reg_puma_list.rds")
# pumas <- names(reg_puma_list[grepl("^\\d+$", names(reg_puma_list))])
pumas <- cwi::xwalk |>
    distinct(town, puma_fips_cog) |>
    group_by(puma_fips_cog) |>
    filter(n() > 1) |>
    pull(puma_fips_cog) |>
    unique()
# regions <- reg_puma_list[!names(reg_puma_list) %in% pumas & !grepl("COG", names(reg_puma_list))]
regions <- reg_puma_list[grepl("\\D", names(reg_puma_list)) & !grepl("COG", names(reg_puma_list))]

######################################## FETCH #################################----
# drop medians for aggregated regions
fetch_main <- purrr::map(cwi::basic_table_nums, cwi::multi_geo_acs,
    year = yr, survey = "acs5",
    towns = "all",
    regions = regions,
    pumas = pumas,
    neighborhoods = nhood_lookup,
    nhood_geoid = "geoid_cog",
    tracts = "all",
    us = TRUE,
    sleep = 1
) |>
    purrr::modify_at(
        "median_income", mutate,
        across(estimate:moe, ~ if_else(grepl("(region|neighborhood)", level), NA_real_, .))
    )
# adding in legislative districts
fetch_legis <- list(upper_legis = "upper", lower_legis = "lower") |>
    purrr::map(\(x) sprintf("state legislative district (%s chamber)", x)) |>
    purrr::map(function(lvl) {
        purrr::map(cwi::basic_table_nums, function(num) {
            tidycensus::get_acs(lvl,
                table = num,
                year = yr,
                survey = "acs5",
                state = "09"
            )
        })
    }) |>
    purrr::map_depth(2, janitor::clean_names) |>
    purrr::map_depth(2, dplyr::filter, !grepl("not defined", name)) |>
    purrr::map_depth(2, dplyr::mutate, name = stringr::str_remove(name, " \\(\\d{4}\\), .+$")) |>
    purrr::transpose() |>
    purrr::map(bind_rows, .id = "level")

fetch <- list(fetch_main, fetch_legis) |>
    purrr::transpose() |>
    purrr::map(bind_rows) |>
    purrr::map(dplyr::mutate, level = forcats::as_factor(level))

######################################## OUTPUT ###############################----

saveRDS(fetch, file.path("fetch_data", stringr::str_glue("acs_basic_{yr}_fetch_all.rds")))
