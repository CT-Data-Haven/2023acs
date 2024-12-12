# reads utils/indicator_headings.txt, fetch_data/acs_basic_yr_fetch_all.rds
# writes output_data/acs_nhoods_by_city_yr.rds, to_distro/city_acs_basic_neighborhood_yr.csv
source("utils/pkgs_utils.R")
##################### VARIABLES ###############################################
out <- list()

params <- list(
    bridgeport = list(region = "Fairfield County", town = "Bridgeport"),
    hartford = list(region = "Greater Hartford", town = c("Hartford", "West Hartford")),
    stamford = list(region = "Fairfield County", town = "Stamford"),
    new_haven = list(region = "Greater New Haven", town = "New Haven")
)

nhoods <- list(
    bridgeport = cwi::bridgeport_tracts, 
    new_have   = cwi::new_haven_tracts, 
    hartford   = cwi::hartford_tracts, 
    stamford   = cwi::stamford_tracts
) |>
    bind_rows(.id = "city") |>
    distinct(city, town, name) |>
    mutate(city = clean_titles(city, cap_all = TRUE))


##################### READ STUFF ###############################################
# nhood names are in form Bridgeport_Black Rock
fetch <- readRDS(str_glue("fetch_data/acs_basic_{yr}_fetch_all.rds")) |>
    map(cwi::label_acs, year = yr) |>
    map(separate, name, into = c("city", "name"), sep = "_", fill = "left") |>
    map(group_by, level, city, name, year) |>
    map(\(x) replace_na(x, list(moe = 0)))

headings <- readr::read_csv(file.path("utils", "indicator_headings.txt"), show_col_types = FALSE) |>
    distinct(indicator, display)

##################### CALCULATE ################################################
# AGE
# pop under 18, 18+, 65+
out$age <- fetch$sex_by_age |>
    cwi::separate_acs(into = c("sex", "group"), drop_total = TRUE, fill = "right") |>
    filter(!is.na(group)) |>
    add_grps_moe(list(total_pop = 1:23, ages00_17 = 1:4, ages18plus = 5:23, ages65plus = 18:23)) |>
    calc_shares_moe()

# RACE / ETHNICITY
# white, black, latino, other
out$race <- fetch$race |>
    rename(group = label) |>
    add_grps_moe(list(total_pop = 1, white = 3, black = 4, latino = 12, other_race = 5:9)) |>
    calc_shares_moe()

# FOREIGN-BORN
out$foreign_born <- fetch$foreign_born |>
    rename(group = label) |>
    add_grps_moe(list(total_pop = 1, foreign_born = 5:6)) |>
    calc_shares_moe()

# TENURE
# owner-occupied
out$tenure <- fetch$tenure |>
    rename(group = label) |>
    add_grps_moe(list(total_households = 1, owner_occupied = 2)) |>
    calc_shares_moe(denom = "total_households")

# HOUSING COST
# cost-burdened (no tenure split)
out$housing_cost <- fetch$housing_cost |>
    cwi::separate_acs(into = c("tenure", "income", "group"), drop_total = TRUE, fill = "right") |>
    filter(!is.na(group)) |>
    add_grps_moe(list(total_households = 1:3, cost_burden = 3)) |>
    calc_shares_moe(denom = "total_households")


# POVERTY & LOW-INCOME
# poverty determined, below 1x fpl, below 2x fpl
out$poverty <- fetch$poverty |>
    cwi::separate_acs(into = "group", drop_total = TRUE, fill = "right") |>
    filter(!is.na(group)) |>
    add_grps_moe(list(poverty_status_determined = 1:7, poverty = 1:2, low_income = 1:6)) |>
    calc_shares_moe(denom = "poverty_status_determined")

# POVERTY & LOW INCOME BY AGE
# ages 0-17, ages 65+: poverty determined, below 1x, below 2x
out$pov_age <- fetch$pov_age |>
    cwi::separate_acs(into = c("age", "ratio"), drop_total = TRUE, fill = "right") |>
    filter(!is.na(ratio)) |>
    mutate(across(c(age, ratio), as_factor)) |>
    group_by(ratio, .add = TRUE) |>
    # show_uniq(age) |>
    add_grps_moe(list(ages00_17 = 1:3, ages65plus = 9:10), group = age) |>
    group_by(level, city, name, year, age) |>
    # show_uniq(ratio) |>
    add_grps_moe(list(poverty_status_determined = 1:12, poverty = 1:3, low_income = 1:8), group = ratio) |>
    calc_shares_moe(denom = "poverty_status_determined", group = ratio) |>
    unite(col = group, age, ratio)


##################### OUTPUT ##################################################
# BIND EVERYTHING
out_df <- bind_rows(out, .id = "topic") |>
    ungroup() |>
    left_join(nhoods, by = c("city", "name"))

# stash all--use for viz
out_by_city <- params |>
    set_names(clean_titles, cap_all = TRUE) |>
    imap(function(p, cty) {
        fltr <- c("Connecticut", unlist(p))
        filter(out_df, name %in% fltr | city == cty)
    }) |>
    map(select, topic, level, city, town, everything())


saveRDS(out_by_city, file.path("output_data", str_glue("acs_nhoods_by_city_{yr}.rds")))

# write each city to csv for distro
profs <- out_by_city |>
    map(select, -matches("moe$")) |>
    map(pivot_longer, estimate:share, names_to = "type") |>
    map(unite, col = indicator, type, group, sep = " ") |>
    map(filter, !is.na(value)) |>
    map(left_join, headings, by = c("indicator")) |>
    map(distinct, level, city, town, name, indicator, .keep_all = TRUE) |>
    map(pivot_wider, id_cols = c(level, city, town, name), names_from = display) |>
    map(arrange, level, town) |>
    map(janitor::remove_empty, "cols")


iwalk(profs, function(df, cty) {
    cty_name <- tolower(str_replace_all(cty, "\\s", "_"))
    fn <- str_glue("{cty_name}_acs_basic_neighborhood_{yr}.csv")
    readr::write_csv(df, file.path("to_distro", fn), na = "")
})
