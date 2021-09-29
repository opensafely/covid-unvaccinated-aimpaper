# # # # # # # # # # # # # # # # # # # # #
# This script:
# fits survival model where an event is vaccination after eligibility period
# time 0 is elig_date + 12 weeks
# stratified by group, specified in args (see below)
# plots cumulative incidence 
#
# The script should be run via an action in the project.yaml
# The script must be accompanied by one argument:
# 1. jcvi_group or elig_date, the strata for the survival model
# # # # # # # # # # # # # # # # # # # # #

cat("#### import command-line arguments ####\n")
args <- commandArgs(trailingOnly=TRUE)

if(length(args)==0){
  # use for interactive testing
  group <- "jcvi_group"
} else {
  group <- args[[1]]
}

## packages
library(tidyverse)
library(RColorBrewer)
library(glue)
library(survival)
library(survminer)

## Create output directory
dir.create(here::here("output", "models"), showWarnings = FALSE, recursive=TRUE)
dir.create(here::here("output", "figures"), showWarnings = FALSE, recursive=TRUE)

all_variables <- readr::read_rds(here::here("analysis", "lib", "all_variables.rds"))

cat("#### bind processed datasets ####\n")
data_survival <- bind_rows(
  read_rds(here::here("output", "data", glue("data_processed_02.rds"))),
  read_rds(here::here("output", "data", glue("data_processed_09.rds"))),
  read_rds(here::here("output", "data", glue("data_processed_11.rds")))
) %>%
  select(all_variables$id_vars, all_variables$survival_vars) %>%
  # time in weeks instead of days
  mutate(time = time/7)

cat("#### process args ####\n")  
get_strata <- function(g) {
  out <- data_survival %>%
    rename(var = g) %>%
    distinct(var) %>%
    arrange(var) %>%
    unlist() %>%
    unname()
  
  out <- str_remove(out, "^0")
  
  return(out)
}

strata <- get_strata(group)

cat("#### fit survival model ####\n")
fit <- survfit(as.formula(glue("Surv(time, status) ~ {group}")), 
               data = data_survival)

write_rds(fit, here::here("output", "models", glue("surv_model_{group}.rds")))

cat("#### generate plots ####\n")
# Plot cumulative events
survplots <- ggsurvplot(fit, 
                        break.time.by = 4,
                        xlim = c(0,max(data_survival$time)),
                        conf.int = TRUE,
                        palette = brewer.pal(n = length(strata), name = "Dark2"),
                        censor=FALSE, #don't show censor ticks on line
                        cumevents = TRUE, 
                        cumcensor = TRUE, 
                        risk.table.col = "strata",
                        fun = "event",
                        # aesthetics
                        xlab = "Time since end of eligibility period (weeks)",
                        legend.title = "JCVI Group",
                        legend.labs = strata,
                        ggtheme = theme_bw())

ggsave(filename=here::here("output", "figures", glue("cml_inc_plot_{group}.png")), 
       plot = survplots$plot, 
       width=14, height=12, units="cm")

ggsave(filename=here::here("output", "figures", glue("cml_inc_events_{group}.png")), 
       plot = survplots$cumevents, 
       width=14, height=8, units="cm")

ggsave(filename=here::here("output", "figures", glue("cml_inc_censor_{group}.png")), 
       plot = survplots$ncensor.plot, 
       width=14, height=8, units="cm")
