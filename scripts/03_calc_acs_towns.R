# reads fetch_data/acs_basic_yr_fetch_all.rds, utils/indicator_headings.txt
# writes output_data/acs_town_basic_profile_yr.csv, output_data/acs_town_basic_profile_yr.rds, to_distro/town_acs_basic_distro_yr.csv
source("utils/pkgs_utils.R")
##################### VARIABLES ###############################################
out <- list()

##################### READ STUFF ###############################################
fetch <- readRDS(str_glue("fetch_data/acs_basic_{yr}_fetch_all.rds")) |>
    map(filter, !str_detect(level, "(neighborhood|tract)")) |>
    map(cwi::label_acs, year = yr) |>
    map(group_by, level, name, year) |>
    map(\(x) replace_na(x, list(moe = 0)))

headings <- readr::read_csv(file.path("utils", "indicator_headings.txt"), show_col_types = FALSE) |>
    distinct(indicator, display)

##################### CALCULATE ################################################
# TOTAL POPULATION
out$total_pop <- fetch$total_pop |>
    mutate(group = "total_pop") |>
    select(level, name, year, group, estimate, moe)

# SEX & AGE
# pop under 18, 65+, male, female, 18+ got lost somewhere
# age
out$age <- fetch$sex_by_age |>
    cwi::separate_acs(into = c("sex", "group"), drop_total = TRUE, fill = "right") |>
    filter(!is.na(group)) |>
    # show_uniq(group) |>
    add_grps_moe(list(total_pop = 1:23, ages00_17 = 1:4, ages18plus = 5:23, ages65plus = 18:23)) |>
    calc_shares_moe()

# sex
out$sex <- fetch$sex_by_age |>
    cwi::separate_acs(into = c("group", "age"), drop_total = TRUE, fill = "right") |>
    filter(!is.na(group) & is.na(age)) |>
    add_grps_moe(list(total_pop = 1:2, male = 1, female = 2)) |>
    calc_shares_moe()

# RACE / ETHNICITY
# latino, white, black, other
out$race <- fetch$race |>
    # show_uniq(label) |>
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

# VEHICLES
# households with 1+ car
out$vehicles <- fetch$vehicles |>
    rename(group = label) |>
    add_grps_moe(list(total_households = 1, has_vehicle = 3:6)) |>
    calc_shares_moe(denom = "total_households")

# EDUCATIONAL ATTAINMENT
# ages 25+: less than high school, bachelors plus
out$education <- fetch$education |>
    rename(group = label) |>
    add_grps_moe(list(ages25plus = 1, less_than_high_school = 2, bachelors_plus = 5:6)) |>
    calc_shares_moe(denom = "ages25plus")

# MEDIAN HOUSEHOLD INCOME
# double check regions & neighborhoods aren't here
out$median_household_income <- fetch$median_income |>
    filter(!is.na(estimate)) |>
    mutate(group = "median_household_income") |>
    select(level, name, year, group, estimate, moe)

# POVERTY & LOW INCOME
# poverty determined, below 1x, below 2x
out$poverty <- fetch$poverty |>
    cwi::separate_acs(into = "group", drop_total = TRUE, fill = "right") |>
    filter(!is.na(group)) |>
    add_grps_moe(list(poverty_status_determined = 1:7, poverty = 1:2, low_income = 1:6)) |>
    calc_shares_moe(denom = "poverty_status_determined")

# POVERTY & LOW INCOME BY AGE
# ages 0-17, ages 65+: poverty determined, below 1x, below 2x
pov_age <- fetch$pov_age |>
    cwi::separate_acs(into = c("age", "ratio"), drop_total = TRUE, fill = "right") |>
    filter(!is.na(ratio)) |>
    mutate(across(c(age, ratio), as_factor)) |>
    group_by(ratio, .add = TRUE) |>
    # show_uniq(age) |>
    add_grps_moe(list(ages00_17 = 1:3, ages65plus = 9:10), group = age) |>
    group_by(level, name, year, age) |>
    # show_uniq(ratio) |>
    add_grps_moe(list(poverty_status_determined = 1:12, poverty = 1:3, low_income = 1:8), group = ratio) |>
    calc_shares_moe(denom = "poverty_status_determined", group = ratio) |>
    unite(col = group, age, ratio)

out$income_children <- pov_age |> filter(str_detect(group, "^ages00_17"))
out$income_seniors <- pov_age |> filter(str_detect(group, "^ages65plus"))

##################### OUTPUT ##################################################
# BIND EVERYTHING
out_df <- bind_rows(out, .id = "topic") |>
    ungroup()
fn <- paste("acs_town_basic_profile", yr, sep = "_")

# stash for general use
saveRDS(out_df, file.path("output_data", xfun::with_ext(fn, "rds")))

# csv
out_df |>
    filter(!grepl("puma", level) & !grepl("(Health|HSA)", name)) |>
    readr::write_csv(file.path("output_data", xfun::with_ext(fn, "csv")))

out_df |>
    select(level, name, group, estimate, share) |>
    filter(grepl("(state|county|region|town)", level)) |>
    pivot_longer(estimate:share, names_to = "type") |>
    unite(col = indicator, type, group, sep = " ") |>
    filter(!is.na(value)) |>
    left_join(headings, by = "indicator") |>
    distinct(level, name, indicator, .keep_all = TRUE) |>
    pivot_wider(id_cols = c(level, name), names_from = display) |>
    readr::write_csv(file.path("to_distro", str_glue("town_acs_basic_distro_{yr}.csv")))
