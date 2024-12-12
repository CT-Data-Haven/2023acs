default_yr <- 2023
default_cws_yr <- 2024

# if (interactive()) {
#   yr <- default_yr
#   cws_yr <- default_cws_yr
# } else {
#   prsr <- argparse::ArgumentParser()
#   prsr$add_argument("yr", help = "Main profile year")
#   prsr$add_argument("cws_yr", help = "CWS year")

#   args <- prsr$parse_args()
#   yr <- as.numeric(args$yr)
#   cws_yr <- as.numeric(args$cws_yr)
# }

snake_or <- function(id, type = c("params", "input", "output", "wildcards"), default = NULL) {
    if (exists("snakemake")) {
        val <- slot(snakemake, type)[[id]]
    } else {
        val <- default
    }
    val
}

library(dplyr, warn.conflicts = FALSE)
library(purrr)
library(tidyr)
library(forcats)
library(stringr)
# library(cwi)
library(dcws)
library(camiller)
options(dplyr.summarise.inform = FALSE)

yr <- snake_or("year", "params", default_yr)
cws_yr <- snake_or("cws_year", "params", default_cws_yr)

##########  PRINT YEARS  ################################################## ----
print_yrs <- function(y, cy) {
    # yr <- snake_or("year", "params")
    # cws_yr <- snake_or("cws_year", "params")
    cli::cli_h1(cli::col_magenta("YEARS INCLUDED"))
    cli::cli_ul(c(
        paste(cli::style_bold("Main year:"), y),
        paste(cli::style_bold("CWS year:"), cy)
    ))
    cat("\n")
}
# print_yrs()
if (!interactive()) {
    prsr <- argparse::ArgumentParser()
    prsr$add_argument("-t", "--testrun",
        help = "Flag for test run",
        dest = "testrun", action = "store_true", default = FALSE
    )
    args <- prsr$parse_args()
    if (args[["testrun"]]) {
        print_yrs(yr, cws_yr)
    }
}

##########  FUNCTIONS  ################################################## ----
has_digits <- function(x) all((str_detect(x, "^\\d")), na.rm = TRUE)
not_digits <- function(x) !has_digits(x)

collapse_response <- function(data, categories, nons = c("Don't know", "Refused")) {
    keeps <- names(categories)
    data <- dplyr::mutate(data, response = forcats::fct_collapse(response, !!!categories))
    data <- dplyr::group_by(data, dplyr::across(-value))
    data <- dplyr::summarise(data, value = sum(value))
    data <- dplyr::ungroup(data)

    if (!is.null(nons)) {
        data <- cwi::sub_nonanswers(data, nons = nons)
    }
    dplyr::filter(data, response %in% keeps)
}

calc_shares_moe <- function(...) calc_shares(..., moe = moe, digits = 2)
add_grps_moe <- function(...) add_grps(..., moe = moe)
