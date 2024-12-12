# read utils/yr_website_meta.rds, utils/indicator_headings.txt, output_data/acs_town_basic_profile_yr.rds, output_data/cws_basic_indicators_yr.rds
# writes website/5yearyrtown_profile_expanded_CWS.csv
source("utils/pkgs_utils.R")
##################### VARIABLES ###############################################
percent <- scales::label_percent(accuracy = 1)
comma <- scales::label_comma(accuracy = 1)
number <- scales::label_number(accuracy = 1, big.mark = "")
# need to combine:
# * ACS data (03_calc_acs_towns.R -> output_data/acs_town_basic_profile.rds)
# * DCWS data (02_calc_cws_data.R -> output_data/cws_basic_indicators)
# * metadata (00_make_meta.R -> utils/website_meta.rds)
meta <- readRDS(file.path("utils", str_glue("{yr}_website_meta.rds"))) |>
    mutate(across(`Maximum MoE on above estimates`, percent))

headings <- readr::read_csv(file.path("utils", "indicator_headings.txt"), show_col_types = FALSE) |>
    separate(indicator, into = c("type", "group"), sep = " ", remove = FALSE, fill = "left") |>
    filter(!is.na(website)) |>
    filter(!indicator %in% c("obesity")) |>
    distinct(indicator, .keep_all = TRUE)

# add MoE to each acs column
moe <- headings |>
    filter(topic != "wellbeing") |>
    mutate(
        type = recode(type, estimate = "moe", share = "sharemoe"),
        website = paste("MoE", website)
    ) |>
    unite(col = indicator, type, group, sep = " ", remove = FALSE)

headings_full <- bind_rows(headings, moe) |>
    mutate(across(topic:group, as_factor),
        topic = fct_relevel(topic, "wellbeing", "age", "sex", "race", "immigration", "housing", "vehicles", "education", "median_household_income", "income", "income_children", "income_seniors"),
        type = fct_relevel(type, "estimate", "moe", "share", "sharemoe")
    ) |>
    arrange(topic, group, type)

by_topic <- headings_full |>
    split(~topic) |>
    map(pull, website)

# data to stick together
acs <- readRDS(file.path("output_data", str_glue("acs_town_basic_profile_{yr}.rds"))) |>
    semi_join(meta, by = c("name" = "Town")) |>
    distinct(name, group, .keep_all = TRUE) |>
    mutate(
        across(c(topic, group), as_factor),
        across(where(is.factor), fct_drop)
    ) |>
    pivot_longer(estimate:sharemoe, names_to = "type") |>
    filter(!is.na(value)) |>
    mutate(value = ifelse(type %in% c("estimate", "moe"), number(value), percent(value))) |>
    unite(col = indicator, type, group, sep = " ") |>
    select(Town = name, indicator, value)

cws <- readRDS(file.path("output_data", str_glue("cws_basic_indicators_{cws_yr}.rds"))) |>
    bind_rows(.id = "indicator") |>
    mutate(value = percent(value)) |>
    select(Town = name, indicator, value)


# assemble
prof_df <- bind_rows(cws, acs) |>
    inner_join(headings_full, by = "indicator") |>
    pivot_wider(id_cols = Town, names_from = website, values_from = value)

if (any(map_lgl(prof_df, is.list))) {
    cli::cli_abort("List-cols present in prof_df")
}

prof_out <- meta |>
    inner_join(prof_df, by = "Town") |>
    mutate(
        Town = stringr::str_replace(Town, "(?<= County)$", ", Connecticut"),
        Definition = stringr::str_replace_all(Definition, "\\n", "\\\\n")
    ) |>
    select(
        Town, COG, `Key Facts`,
        starts_with("Wellbeing"), all_of(by_topic$wellbeing), starts_with("Maximum MoE"),
        starts_with("Demographic"), all_of(c(by_topic$age, by_topic$sex)),
        starts_with("Race and Ethnicity"), all_of(by_topic$race),
        starts_with("Place of Birth"), all_of(by_topic$immigration),
        Households, all_of(c(by_topic$housing, by_topic$vehicles)),
        starts_with("Educational"), all_of(by_topic$education),
        `Median Income`, all_of(by_topic$median_household_income),
        `Poverty and Low-Income, Total Population`, all_of(by_topic$income),
        `Poverty and Low-Income, Population 0 to 17 years`, all_of(by_topic$income_children),
        `Poverty and Low-Income, Population 65 years and over`, all_of(by_topic$income_seniors),
        Source:`Demographic Characteristics`
    )

readr::write_csv(prof_out, file.path("website", stringr::str_glue("5year{yr}town_profile_expanded_CWS.csv")), na = "", quote = "all")
