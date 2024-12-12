# reads nothing local
# writes output_data/cws_basic_indicators_2021.rds
source("utils/pkgs_utils.R")
out <- list()

lookup <- dcws::fetch_cws(.year = cws_yr, .category = "Total") |>
    distinct(code, question)

# q1 yes -- satisfied with area
# q17f disagree -- safe to walk at night
# q19 excellent / very good -- excellent / very good health
# bmir -- obese
# q39 & q40 -- current smoking
# q62 yes -- food insecure
# q64 yes -- housing insecure
# q65 yes -- transportation insecure
# q47, q49, q50 -- underemployed
# switch to regex matches on questions so it's not confined to single survey run
fetch <- list(
    satisfied_w_area = "Are you satisfied with the city",
    safe_to_walk_at_night = "I do not feel safe to go on walks",
    self_rated_health = "rate your overall health",
    smoke100 = "^Have you smoked",
    smoke_freq = "Do you currently smoke",
    food_insecure = "^Have there been times .+ buy food",
    housing_insecure = "adequate shelter",
    transportation_insecure = "^In the past 12 months, did you stay home",
    employed = "^Have you had a paid job",
    part_time = "has your job been full time",
    pref_full_time = "rather have a full-time job"
) |>
    map(\(x) dcws::fetch_cws(grepl(x, question), .year = cws_yr, .unnest = TRUE, .category = "Total")) |>
    map(function(df) {
        df |>
            mutate(response = as_factor(response)) |>
            complete(nesting(year, span, name, code, question, category, group), response, fill = list(value = 0))
    })
# fetch <- list(satisfied_w_area = "Q1",
#               safe_to_walk_at_night = "Q17F",
#               self_rated_health = "Q19",
#               obesity = "BMIR",
#               smoke100 = "Q39", smoke_freq = "Q40",
#               food_insecure = "Q62",
#               housing_insecure = "Q64",
#               transportation_insecure = "Q65",
#               employed = "Q47", part_time = "Q49", pref_full_time = "Q50") |>
#   map(function(x) dcws::fetch_cws(code == x, .year = cws_yr, .unnest = TRUE, .category = "Total"))

# keep yes
yeses <- fetch[c("satisfied_w_area", "food_insecure", "housing_insecure", "transportation_insecure")] |>
    map(cwi::sub_nonanswers) |>
    map(filter, response == "Yes")

out[names(yeses)] <- yeses

# keep disagree
out[["safe_to_walk_at_night"]] <- fetch$safe_to_walk_at_night |>
    collapse_response(list(safe = c("Strongly disagree", "Somewhat disagree")))

# keep excellent, very good
out[["self_rated_health"]] <- fetch$self_rated_health |>
    collapse_response(list(excellent_vgood = c("Excellent", "Very good")))

# keep obese--nonanswers already removed
# out[["obesity"]] <- fetch$obesity |>
#   filter(response == "Obese")

# smoke100: keep yes; smoke_freq: keep every day, some days
smoke100 <- fetch$smoke100 |>
    cwi::sub_nonanswers() |>
    filter(response == "Yes")
current_smoke <- fetch$smoke_freq |>
    collapse_response(list(current = c("Every day", "Some days")))
out[["smoking"]] <- lst(smoke100, current_smoke) |>
    map(select, -question, -response, -code) |>
    bind_rows(.id = "response") |>
    tidyr::pivot_wider(names_from = response) |>
    mutate(value = smoke100 * current_smoke)

# employed: keep Yes; No, but would like to work
# part time: keep Part time
# pref full time: Rather have a full time job
# let me not mess this up like usual: underemployed = (unemployed + employed * part time * prefer full time) / (unemployed + employed)
unemployed <- fetch$employed |>
    cwi::sub_nonanswers(nons = "Refused") |>
    filter(response == "No, but would like to work")
employed <- fetch$employed |>
    cwi::sub_nonanswers(nons = "Refused") |>
    filter(response == "Yes")
part_time <- fetch$part_time |>
    cwi::sub_nonanswers(nons = "Refused") |>
    filter(response == "Part time")
pref_full_time <- fetch$pref_full_time |>
    cwi::sub_nonanswers(nons = "Refused") |>
    filter(response == "Rather have a full time job")
out[["underemployment"]] <- lst(unemployed, employed, part_time, pref_full_time) |>
    map(select, -question, -response, -code) |>
    bind_rows(.id = "response") |>
    tidyr::pivot_wider(names_from = response) |>
    mutate(
        labor_force = unemployed + employed,
        value = (unemployed + employed * part_time * pref_full_time) / labor_force
    )

out <- out |>
    map(select, year, name, category, group, value)

out <- out[c("satisfied_w_area", "safe_to_walk_at_night", "self_rated_health", "smoking", "food_insecure", "housing_insecure", "transportation_insecure", "underemployment")]

saveRDS(out, file.path("output_data", str_glue("cws_basic_indicators_{cws_yr}.rds")))
