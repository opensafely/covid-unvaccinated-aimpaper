library(tidyverse)
library(lubridate)
library(yaml)
library(glue)

jcvi_groups <- c("02","09","11")

# create action functions ----

## create comment function ----
comment <- function(...){
  list_comments <- list(...)
  comments <- map(list_comments, ~paste0("## ", ., " ##"))
  comments
}


## create function to convert comment "actions" in a yaml string into proper comments
convert_comment_actions <-function(yaml.txt){
  yaml.txt %>%
    str_replace_all("\\\n(\\s*)\\'\\'\\:(\\s*)\\'", "\n\\1")  %>%
    #str_replace_all("\\\n(\\s*)\\'", "\n\\1") %>%
    str_replace_all("([^\\'])\\\n(\\s*)\\#\\#", "\\1\n\n\\2\\#\\#") %>%
    str_replace_all("\\#\\#\\'\\\n", "\n")
}
as.yaml(splice(a="c", b="'c'", comment("fff")))
convert_comment_actions(as.yaml(splice(a="c", b="'c'", comment("fff"))))


## generic action function ----
action <- function(
  name,
  run,
  arguments=NULL,
  needs=NULL,
  highly_sensitive=NULL,
  moderately_sensitive=NULL
){
  
  outputs <- list(
    highly_sensitive = highly_sensitive,
    moderately_sensitive = moderately_sensitive
  )
  outputs[sapply(outputs, is.null)] <- NULL
  
  action <- list(
    run = paste(c(run, arguments), collapse=" "),
    needs = needs,
    outputs = outputs
  )
  action[sapply(action, is.null)] <- NULL
  
  action_list <- list(name = action)
  names(action_list) <- name
  
  action_list
}

## report action function ----
action_report <- function(
  outcome, timescale, censor_seconddose, modeltype
){
  action(
    name = glue("report_{outcome}_{timescale}_{censor_seconddose}_{modeltype}"),
    run = glue("r:latest analysis/models/report_{modeltype}.R"),
    arguments = c(outcome, timescale, censor_seconddose),
    needs = list("design", glue("model_{outcome}_{timescale}_{censor_seconddose}_{modeltype}")),
    highly_sensitive = list(
      rds = glue("output/models/{outcome}/{timescale}/{censor_seconddose}/report{modeltype}_*.rds")
    ),
    moderately_sensitive = list(
      csv = glue("output/models/{outcome}/{timescale}/{censor_seconddose}/report{modeltype}_*.csv"),
      svg = glue("output/models/{outcome}/{timescale}/{censor_seconddose}/report{modeltype}_*.svg"),
      png = glue("output/models/{outcome}/{timescale}/{censor_seconddose}/report{modeltype}_*.png")
    )
  )
}

# specify project ----

## defaults ----
defaults_list <- list(
  version = "3.0",
  expectations= list(population_size=100000L)
)

## actions ----

actions_list <- splice(
  
  comment("# # # # # # # # # # # # # # # # # # #",
          "DO NOT EDIT project.yaml DIRECTLY",
          "This file is created by create_project.R",
          "Edit and run create_project.R to update the project.yaml",
          "# # # # # # # # # # # # # # # # # # #\n"
  ),
  
  comment("# # # # # # # # # # # # # # # # # # #",
          "Metadata for study design",
          "# # # # # # # # # # # # # # # # # # #"),
  
  action(
    name = "design",
    run = "r:latest analysis/00_design.R",
    moderately_sensitive = list(
      dates = "analysis/lib/dates.json"
    )
  ),
  
  comment("# # # # # # # # # # # # # # # # # # #",
          "Study definition",
          "# # # # # # # # # # # # # # # # # # #"),
  
  action(
    name = "study_definition",
    run = "cohortextractor:latest generate_cohort --study-definition study_definition",
    needs = list("design"),
    highly_sensitive = list(
      cohort = "output/input.csv"
      )
    ),
  
  comment("# # # # # # # # # # # # # # # # # # #",
          "Process the data",
          "# # # # # # # # # # # # # # # # # # #"),
  
  action(
    name = "process_data",
    run = glue("r:latest analysis/01_data_process.R"),
    needs = list("study_definition"),
    highly_sensitive = list(
      data = glue("output/data/data_processed_*.rds")
    )
    ),
  
  comment("# # # # # # # # # # # # # # # # # # #",
          "Summary tables for each elig_group",
          "# # # # # # # # # # # # # # # # # # #"),

  unlist(lapply(jcvi_groups,
                function(x)
                  action(
                    name = glue("summary_tables_{x}"),
                    run = glue("r:latest analysis/02_summary_tables.R {x}"),
                    needs = list("process_data"),
                    moderately_sensitive = list(
                      data = glue("output/data/summary_table_{x}.rds")
                    )
                  )
  ),
  recursive = FALSE)
)

project_list <- splice(
  defaults_list,
  list(actions = actions_list)
)


## convert list to yaml, reformat comments and whitespace,and output ----
as.yaml(project_list, indent=2) %>%
  # convert comment actions to comments
  convert_comment_actions() %>%
  # add one blank line before level 1 and level 2 keys
  str_replace_all("\\\n(\\w)", "\n\n\\1") %>%
  str_replace_all("\\\n\\s\\s(\\w)", "\n\n  \\1") %>%
  writeLines(here::here("project.yaml"))

#yaml::write_yaml(project_list, file =here("project.yaml"))


## grab all action names and send to a txt file

names(actions_list) %>% tibble(action=.) %>%
  mutate(
    model = action==""  & lag(action!="", 1, TRUE),
    model_number = cumsum(model),
  ) %>%
  group_by(model_number) %>%
  summarise(
    sets = str_trim(paste(action, collapse=" "))
  ) %>% pull(sets) %>%
  paste(collapse="\n") %>%
  writeLines(here::here("actions.txt"))
