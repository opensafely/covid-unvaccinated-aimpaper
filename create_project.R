library(tidyverse)
library(lubridate)
library(yaml)
library(glue)

jcvi_groups <- c("02","09","11")

model_types <- "unadj" #c("unadj", "padj", "fadj")

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
          "# # # # # # # # # # # # # # # # # # #"
  ),
  
  comment("# # # # # # # # # # # # # # # # # # #",
          "Metadata for study design",
          "# # # # # # # # # # # # # # # # # # #"),
  
  action(
    name = "design",
    run = "r:latest analysis/00_design.R",
    highly_sensitive = list(
      dates_json = "analysis/lib/dates.json",
      dates_rds = "analysis/lib/dates.rds"
    )
  ),
  
  comment("# # # # # # # # # # # # # # # # # # #",
          "Study definition",
          "# # # # # # # # # # # # # # # # # # #"),
  
  action(
    name = "study_definition",
    run = "cohortextractor:latest generate_cohort --study-definition study_definition",
    # dummy_data_file: "test-data/dummy-data.csv",
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
    needs = list("design", "study_definition"),
    highly_sensitive = list(
      data = "output/data/data_processed_*.rds",
      variables = "analysis/lib/all_variables.rds"
    ),
    moderately_sensitive = list(
      elig_dates = "output/tables/elig_dates_tibble.csv",
      death_counts = "output/tables/death_count_*.csv"
    )
    ),
  
  comment("# # # # # # # # # # # # # # # # # # #",
          "Summary tables for each jcvi_group",
          "# # # # # # # # # # # # # # # # # # #"),

  unlist(lapply(jcvi_groups,
                function(x)
                  action(
                    name = glue("summary_table_{x}"),
                    arguments = x,
                    run = "r:latest analysis/02_summary_tables.R",
                    needs = list("process_data"),
                    moderately_sensitive = list(
                      table = glue("output/tables/summary_table_{x}.csv")
                    )
                  )
  ),
  recursive = FALSE),
  
  comment("# # # # # # # # # # # # # # # # # # #",
          "Models for each jcvi_group and model_type",
          "# # # # # # # # # # # # # # # # # # #"),
  
  unlist(lapply(jcvi_groups,
                function(jcvi_group)
                  unlist(lapply(model_types,
                                function(model_type)
                                  action(
                                    name = glue("model_{jcvi_group}_{model_type}"),
                                    arguments = c(jcvi_group, model_type),
                                    run = "r:latest analysis/03_model.R",
                                    needs = list("process_data"),
                                    highly_sensitive = list(
                                      model = glue("output/models/model_{jcvi_group}_{model_type}_*.rds")
                                    ),
                                    moderately_sensitive = list(
                                      table = glue("output/tables/table_{jcvi_group}_{model_type}.csv")
                                    )
                                  )
                  ), recursive = FALSE)
  ),
  recursive = FALSE),
  
  comment("# # # # # # # # # # # # # # # # # # #",
          "Cumulative incidence analysis",
          "# # # # # # # # # # # # # # # # # # #"),
  
  unlist(lapply(c("jcvi_group", "elig_date"),
                function(x)
                  action(
                    name = glue("cml_inc_model_{x}"),
                    run = glue("r:latest analysis/04_cumulative_incidence.R"),
                    arguments = x,
                    needs = list("design", "study_definition", "process_data"),
                    highly_sensitive = list(
                      model = glue("output/models/surv_model_{x}.rds")
                    ),
                    moderately_sensitive = list(
                      cml_inc_plot = glue("output/figures/cml_inc_plot_{x}.png"),
                      survtable = glue("output/tables/survtable_{x}.csv")
                    )
                  )
  ),
  recursive = FALSE)
  
  # ,comment("# # # # # # # # # # # # # # # # # # #",
  #         "Generate PDF report",
  #         "# # # # # # # # # # # # # # # # # # #"),
  # 
  # action(
  #   name = "rmd_report",
  #   run = glue(
  #     "r:latest -e {q}",
  #     q = single_quote('rmarkdown::render("analysis/report.Rmd",  knit_root_dir = "/workspace",  output_dir = "/workspace/output/report", output_format = c("pdf_document")   )')
  #   ),
  #   needs = splice(
  #     "design", "process_data", 
  #     lapply(jcvi_groups, function(jcvi_group) glue("summary_table_{jcvi_group}")),
  #     unlist(lapply(model_types, function(model_type) lapply(jcvi_groups, function(jcvi_group) glue("model_{jcvi_group}_{model_type}"))), recursive = FALSE)
  #   ),
  #   moderately_sensitive = lst(
  #     pdf = "output/report/report.pdf"
  #   )
  # )
  
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
