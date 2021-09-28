# # # # # # # # # # # # # # # # # # # # #
# This script:
# generates a summary table of all variables for each of the jcvi groups included
#
# The script should be run via an action in the project.yaml
# The script must be accompanied by one argument:
# 1. JCVI group: 02, 09 or 11
# # # # # # # # # # # # # # # # # # # # #

cat("#### import command-line arguments ####\n")
args <- commandArgs(trailingOnly=TRUE)

if(length(args)==0){
  # use for interactive testing
  jcvi_group <- "02"
} else {
  jcvi_group <- args[[1]]
}

# libraries
library(tidyverse)
library(readr)
library(scales)
library(glue)

dir.create(here::here("output", "tables"), showWarnings = FALSE, recursive=TRUE)

cat("#### import custom functions ####\n")
source(here::here("analysis", "lib", "sanitise_variables.R"))
source(here::here("analysis", "lib", "mask.R"))

all_variables <- readr::read_rds(here::here("analysis", "lib", "all_variables.rds"))

cat("#### load data for jcvi_group ####\n")
data <- read_rds(here::here("output", "data", glue("data_processed_{jcvi_group}.rds")))

cat("#### get names of variable with levels 0 and 1 ####\n")
levs2 <- sapply(names(data),
                function(x) if_else(all(levels(data[,x][[1]]) %in% c("0","1")),
                                    TRUE, FALSE))

cat("#### generate summary table ####\n")
summary_table <- bind_rows(
  
  data %>%
    group_by(weight, vax_12) %>%
    count() %>%
    # mask values < 5 (probably unnecessary but just in case occurs due to error in code upstream)
    mask(n) %>%
    # use inverse probability weighting to correct for random sampling
    mutate(across(n, ~weight*n)) %>%
    ungroup() %>%
    mutate(value = str_c(comma(n, accuracy = 1), " (", round(100*n/sum(n),1), ")")) %>%
    select(-weight, -n) %>%
    pivot_wider(names_from = vax_12, values_from = value) %>%
    mutate(variable = "n (% of sample)"),
  
  # summarise age (only continuous variable)
  # don't need to use inverse probability weighting to correct for random sampling
  # here as the weights are all the same in each group, so cancel out when calculating mean and sd
  data %>% 
    group_by(vax_12) %>%
    summarise(mean = mean(age), sd = sd(age)) %>%
    ungroup() %>%
    mutate(value = str_c(round(mean,1), " (", round(sd,1), ")")) %>%
    select(vax_12, value) %>%
    pivot_wider(names_from = vax_12, values_from = value) %>%
    mutate(variable = "Age"),
  
  # summarise all categorical variables
  lapply(
    names(data)[!(names(data) %in% c("vax_12", "age", "weight", 
                                     all_variables$survival_vars,
                                     all_variables$id_vars
                                     ))], 
    function(x)
      data %>% 
      group_by(weight, vax_12, .data[[x]]) %>%
      count() %>%
      ungroup(weight, .data[[x]]) %>%
      # mask values < 5
      mask(n) %>%
      # use inverse probability weighting to correct for random sampling
      mutate(across(n, ~weight*n)) %>%
      select(-weight) %>%
      mutate(value = str_c(comma(n, accuracy = 1), " (", round(100*n/sum(n),1), ")")) %>%
      ungroup() %>%
      select(vax_12, .data[[x]], value) %>%
      pivot_wider(names_from = vax_12, values_from = value) %>%
      # replace NA with 0
      mutate(across(c(`0`, `1`), ~if_else(is.na(.), "0 (0)", .))) %>%
      mutate(variable = x,
             category = as.character(.data[[x]])) %>%
      select(variable, category, `0`, `1`)
  )
)  %>%
  select(variable, category, unvaccinated = `0`, vaccinated = `1`) %>%
  # keep only one level if binary
  mutate(across(category,
                ~case_when(
                  variable %in% names(data)[levs2]
                  & . %in% "0"
                  ~ "REMOVE",
                  variable %in% names(data)[levs2]
                  & . %in% "1"
                  ~ "",
                  TRUE ~ .))) %>%
  filter(!(category %in% "REMOVE")) %>%
  # clean text in columns
  sanitise_variables(variable) %>%
  mutate(characteristic = case_when(
    category %in% "" | is.na(category)
    ~ variable,
    TRUE
    ~ str_c(variable, category, sep = ": "))) %>%
  select(characteristic, unvaccinated, vaccinated) %>% 
  # filter(characteristic != "Sex: M") %>%
  rename_with(str_to_sentence) 

cat("#### save summary_table ####\n")
write_rds(summary_table, here::here("output", "tables", glue("summary_table_{jcvi_group}.rds")))
