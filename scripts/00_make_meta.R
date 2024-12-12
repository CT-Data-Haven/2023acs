# reads nothing local
# writes utils/yr_website_meta.rds, utils/reg_puma_list.rds
source("utils/pkgs_utils.R")
######################################## ACS METADATA ##########################----
# get census profile table codes
dps <- httr::GET(str_glue("https://api.census.gov/data/{yr}/acs/acs5/profile/variables.json")) |>
    httr::content(as = "parsed") |>
    purrr::flatten() |>
    bind_rows(.id = "variable") |>
    filter(grepl("^DP\\d{2}$", group)) |>
    distinct(group, concept) |>
    mutate(concept = concept |>
        str_remove_all("(^SELECTED|IN THE UNITED STATES|^ACS)") |>
        trimws() |>
        str_to_title() |>
        recode(`Demographic And Housing Estimates` = "Demographic Characteristics")) |>
    arrange(group)

# get geoids with geography levels
geos <- openxlsx::read.xlsx(str_glue("https://www2.census.gov/programs-surveys/popest/geographies/{yr}/all-geocodes-v{yr}.xlsx"), startRow = 5) |>
    as_tibble() |>
    rename_with(\(x) str_remove(x, "\\(.*$")) |>
    janitor::clean_names() |>
    rename_with(\(x) str_remove(x, "_fips_code$")) |>
    filter(
        state == "09",
        summary_level %in% c("040", "050", "061")
    ) |>
    mutate(
        area_name = str_remove(area_name, " town"),
        summary_level = str_sub(summary_level, 1, 2) |> str_pad(7, "right", "0")
    ) |>
    mutate(area_name = stringr::str_replace(area_name, "Planning Region", "COG")) |>
    select(summary_level:county_subdivision, name = area_name) |>
    mutate(us = "US") |>
    select(summary_level, us, everything()) |>
    tidyr::pivot_longer(-name, names_to = "variable") |>
    filter(!str_detect(value, "^0+$")) |>
    group_by(name) |>
    summarise(code = paste(value, collapse = ""))

# get url for each geo x table combination
base_url <- "https://data.census.gov/cedsci/table"
# add g = geo code, table = DP02, tid ACSDP5Y2018.DP03
base_q <- list(vintage = yr, d = "ACS 5-Year Estimates Data Profiles")

urls <- cross_join(geos, dps) |>
    mutate(tid = str_glue("ACSDP5Y{yr}.{group}")) |>
    mutate(
        q = purrr::pmap(list(table = group, g = code, tid = tid), c, base_q),
        url = purrr::map_chr(q, \(x) httr::modify_url(base_url, query = x))
    ) |>
    select(Town = name, concept, url) |>
    tidyr::pivot_wider(id_cols = Town, names_from = concept, values_from = url)

######################################## CWS METADATA ##########################----
moe <- dcws::cws_max_moe |>
    filter(span == as.character(cws_yr)) |>
    select(Town = name, `Maximum MoE on above estimates` = moe)

######################################## HEADINGS ##############################----
# copy over from 2019 instead of rewriting
old_prof <- readr::read_csv("https://raw.githubusercontent.com/CT-Data-Haven/2019acs/main/output_data/5year2019town_profile_expanded_CWS.csv", show_col_types = FALSE) |>
    filter(!is.na(`Key Facts`))

sections <- old_prof |>
    select(where(not_digits), -matches("Characteristics")) |>
    mutate(
        Source = stringr::str_replace(Source, "\\d{4}(?= DataHaven Community Wellbeing Survey)", as.character(cws_yr)),
        Definition = stringr::str_replace_all(Definition, "http(?=\\:)", "https")
    ) |>
    select(-Town, -County) |>
    distinct()

# binding geographies here to make sure larger regions get retained (GNH, Valley)
# but drop ones that are identical to COGs (Greater Bridgeport)
meta <- tibble(Town = unique(c(urls$Town, old_prof$Town))) |>
    filter(!Town %in% c("Greater Bridgeport", "Greater Hartford")) |>
    left_join(moe, by = "Town") |>
    cross_join(sections) |>
    left_join(distinct(cwi::xwalk, town, cog), by = c("Town" = "town")) |>
    select(Town,
        COG = cog, `Key Facts`, `Wellbeing, Population 18 years and over`,
        matches("Maximum MoE"),
        everything()
    ) |>
    left_join(urls, by = "Town")

saveRDS(meta, file.path("utils", str_glue("{yr}_website_meta.rds")))



######################################## DOWNLOADS #############################----
# get from town equity repo: reg_puma_list
# town_meta <- gh::gh("/repos/{owner}/{repo}/releases/tags/metadata", owner = "CT-Data-Haven", repo = "towns2023") |>
#   pluck("assets") |>
#   map(~.[c("url", "name")]) |>
#   rlang::set_names(purrr::map_chr(., "name"))

# gh::gh(town_meta$reg_puma_list.rds$url, .accept = "application/octet-stream", .destfile = "utils/reg_puma_list.rds", .overwrite = TRUE)
