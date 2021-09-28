######################################

# This script:
# - imports data extracted by the cohort extractor
# - cleans data
# - saves processed dataset output/data/data_processed.rds

######################################

## setup
library(tidyverse)
library(lubridate)
library(readr)

dates <- read_rds(here::here("analysis", "lib", "dates.rds"))

## Output processed data to rds
dir.create(here::here("output", "data"), showWarnings = FALSE, recursive=TRUE)

# Custom functions
fct_case_when <- function(...) {
  # uses dplyr::case_when but converts the output to a factor,
  # with factors ordered as they appear in the case_when's  ... argument
  args <- as.list(match.call())
  levels <- sapply(args[-1], function(f) f[[3]])  # extract RHS of formula
  levels <- levels[!is.na(levels)]
  factor(dplyr::case_when(...), levels=levels)
}

cat("#### print variable names ####\n")
read_csv(here::here("output", "input.csv"),
         n_max = 0,
         col_types = cols()) %>%
  names() %>%
  sort() %>%
  print()

cat("#### extract data ####\n")
data_extract0 <- read_csv(
    file = here::here("output", "input.csv"),
    col_types = cols_only(

      ## Identifier
      patient_id = col_integer(),

      elig_date = col_date(format="%Y-%m-%d"),

      ## Clinical/demographic variables
      sex = col_character(),
      # ethnicity
      ethnicity_6 = col_character(),
      ethnicity_6_sus = col_character(),
      # Index of multiple deprivation
      imd = col_integer(),
      # STP (regional grouping of practices)
      stp = col_character(),
      # region
      region = col_character(),
      # rural urban
      rural_urban = col_character(),
      # Smoking status
      smoking_status = col_character(),
      ## Varibles for deriving priority groups
      age_1 = col_integer(),
      age_2 = col_integer(),

      ## Clinical variables
      # Asthma diagnosis codes
      astdx = col_integer(),
      # BMI
      bmi = col_character(),
      # hypertension
      hypertension = col_integer(),
      # DMARDS
      dmard = col_integer(),
      # SSRI
      ssri = col_integer(),
      # pregnant while eligible
      preg_elig_group = col_integer(),

      # Variables for defining JCVI groups
      # asthma at risk group
      asthma_group = col_integer(),
      # Chronic Respiratory Disease
      resp_group = col_integer(),
      # Chronic heart disease codes
      chd_group = col_integer(),
      # Chronic kidney disease diagnostic codes
      ckd_group = col_integer(),
      # Chronic Liver disease codes
      cld_group = col_integer(),
      # Diabetes diagnosis codes
      diab_group = col_integer(),
      # Immunosuppressed group
      immuno_group = col_integer(),
      # Chronic Neurological Disease including Significant Learning Disorder
      cns_group = col_integer(),
      # Asplenia or Dysfunction of the Spleen codes
      spln_group = col_integer(),
      # # Severe Obesity group
      # sevobese_group = col_integer(),
      # Severe Mental Illness codes
      sevment_group = col_integer(),
      # Wider Learning Disability
      learndis_group = col_integer(),
      # Patients in long-stay nursing and residential care
      longres_group = col_integer(),
      # # Pregnancy group
      # preg_jcvi_group = col_integer(),
      # clinically extremely vulnerable group
      cev_group = col_integer(),
      # # at risk group
      # atrisk_group = col_character(),
      # jcvi group
      jcvi_group = col_character(),

      ## vaccination variables
      # First COVID vaccination date
      covid_vax_1_date = col_date(format="%Y-%m-%d"),

      ## covid variables
      # positive COVID test before start_dat
      covid_positive_test_before_group = col_integer(),
      # positive COVID test between start_dat and index_dat
      covid_positive_test_during_group = col_integer(),
      # covid-related hospitalisation before start_dat
      covid_hospital_admission_before_group = col_integer(),
      # covid-related hospitalisation between start_dat and index_date
      covid_hospital_admission_during_group = col_integer(),

      ## died or deregistered variables
      # COVID related death
      death_with_covid_on_the_death_certificate_date = col_date(format="%Y-%m-%d"),
      # Death within 28 days of a positive COVID test
      death_with_28_days_of_covid_positive_test = col_integer(),
      # Deregistration date
      dereg_date = col_date(format="%Y-%m-%d"),
      # Death of any cause
      death_date = col_date(format="%Y-%m-%d")
    ),
    na = character() # more stable to convert to missing later
    ) 
    ### REMOVE THESE LINES WHEN RUN ON TPP DATA
     # %>% mutate(jcvi_group %in% c("02", "09", "11"),
     #       age_2 = age_1,
     #       preg_elig_group = if_else(sex=="F", preg_elig_group, 0L))

cat("#### parse NAs ####\n")
data_extract <- data_extract0 %>%
  mutate(across(
    .cols = where(is.character),
    .fns = ~na_if(.x, "")
  )) %>%
  mutate(patient_id = row_number()) %>% # create new ID variable, as duplicates after binding
  arrange(patient_id)

cat("#### define variable groups ####\n")
# variables used to define at risk group
all_variables <- list(
  id_vars = c(
    "patient_id",
    "jcvi_group"
  ),
  outcome = "vax_12",
  # age vars
  age = "age",
  ageband = "ageband",
  # demographic variables
  dem_vars = c(
    "sex",
    "ethnicity",
    "smoking_status",
    "imd",
    "rural_urban",
    "stp",
    "region"
  ),
  # clinical variables
  clinical_vars = c(
    "bmi",
    "hypertension",
    "ssri",
    "dmard",
    "astdx"),
  # jcvi grouping
  jcvi_vars = c(
    "asthma_group",
    "resp_group",
    "chd_group",
    "ckd_group",
    "cld_group",
    "cns_group",
    "diab_group",
    "immuno_group",
    "spln_group",
    "sevment_group",
    "learndis_group",
    "cev_group"),
  preg_vars = c(
    # "preg_jcvi_group",
    "preg_elig_group"
  ),
  longres_vars = c(
    "longres_group"
  ),
  # variables indicating covid infection
  covid_vars = c(
    "covid_positive_test_before_group",
    "covid_positive_test_during_group",
    "covid_hospital_admission_before_group",
    "covid_hospital_admission_during_group"
  ),
  # variables indicating death or deregistration during eligibility period
  # censor_vars = c(
  #   "death_with_covid_on_the_death_certificate_group",
  #   "death_with_28_days_of_covid_positive_test",
  #   "death_date",
  #   "dereg_date"
  # ),
  survival_vars = c(
    "baseline", "covid_vax_1_date_after", "event_date", "status", "time"
  )
)

readr::write_rds(all_variables, here::here("analysis", "lib", "all_variables.rds"))

# check format of elig_date
elig_date_test <- data_extract %>%
  select(elig_date) %>%
  filter(!is.na(elig_date) &
            str_detect(as.character(elig_date), "\\d{4}-\\d{2}-\\d{2}"))

if (nrow(elig_date_test) == 0) {
  
  # REMOVE ONCE ELIG_DATES FIXED
  elig_dates_tibble <- tribble(
    ~group, ~date,
    "02",  "2020-12-08",
    "09", "2021-03-19",
    "11, aged 38-39", "2021-05-13",
    "11, aged 36-37", "2021-05-19",
    "11, aged 34-35", "2021-05-21",
    "11, aged 32-33", "2021-05-25",
    "11, aged 30-31", "2021-05-26",
  )
  
  
  data_extract <- data_extract %>%
    mutate(
      
      age_1 = sample(c(30:39, 50:54, 80:100), size = nrow(data_extract), replace=TRUE),
      
      jcvi_group = case_when(age_1 < 50 ~ "11",
                             age_1 < 80 ~ "09",
                             TRUE ~ "02"),
      
      age_2 = age_1,
      preg_elig_group = if_else(sex=="F", preg_elig_group, 0L),

      elig_date = as_date(case_when(jcvi_group %in% "02"  ~  elig_dates_tibble$date[1],
                                    jcvi_group %in% "09"  ~ elig_dates_tibble$date[2],
                                    age_2 %in% c(38,39) ~ elig_dates_tibble$date[3],
                                    age_2 %in% c(36,37) ~ elig_dates_tibble$date[4],
                                    age_2 %in% c(34,35) ~ elig_dates_tibble$date[5],
                                    age_2 %in% c(32,33) ~ elig_dates_tibble$date[6],
                                    age_2 %in% c(30,31) ~ elig_dates_tibble$date[7],
                                    TRUE ~ NA_character_),
                          format = "%Y-%m-%d") 
    )
}

cat("#### process data ####\n")
data_processed <- data_extract %>%
  mutate(

    age = if_else(jcvi_group %in% "11", age_2, age_1),

    ageband = cut(
      age,
      breaks = c(seq(30,40,5), seq(50,55,5), seq(80,95,5), Inf),
      labels = c("30-34", "35-39", "40-49", "50-54", "55-79", "80-84", "85-89", "90-94", "95+"),
      right = FALSE
    ),

    # Ethnicity
    ethnicity = if_else(is.na(ethnicity_6), ethnicity_6_sus, ethnicity_6),
    ethnicity = fct_case_when(
      ethnicity == "1" ~ "White",
      ethnicity == "4" ~ "Black",
      ethnicity == "3" ~ "South Asian",
      ethnicity == "2" ~ "Mixed",
      ethnicity == "5" ~ "Other",
      TRUE ~ "Missing"
    ),

    # vaccinated within 12 weeks of elig_date
    vax_12 = if_else(
      !is.na(covid_vax_1_date) &
        covid_vax_1_date <= elig_date + weeks(12),
      1L, 0L
    ),

    # IMD **check this is best way to define IMD**
    imd = fct_case_when(
      between(imd, 1,6000) ~ "1 most deprived",
      between(imd, 6001,12000) ~ "2",
      between(imd, 12001, 18000) ~ "3",
      between(imd, 18001, 24000) ~ "4",
      between(imd, 24001, 30000) ~ "5 least deprived",
      TRUE ~ "Missing"
    ),

    sex = fct_case_when(sex %in% "F" ~ "F",
                        sex %in% "M" ~ "M",
                        TRUE ~ NA_character_),

    bmi = fct_case_when(
      bmi %in% "Not obese" ~ "Not obese",
      bmi %in% "Obese I (30-34.9)" ~ "Obese I (30-34.9)",
      bmi %in% "Obese II (35-39.9)" ~ "Obese II (35-39.9)",
      bmi %in% "Obese III (40+)" ~ "Obese III (40+)",
      bmi %in% "Missing" ~ "Missing",
      TRUE ~ NA_character_
    ),


    smoking_status = fct_case_when(
      smoking_status %in% "S" ~ "Current-smoker",
      smoking_status %in% "E" ~ "Ex-smoker",
      smoking_status %in% "N" ~ "Non-smoker",
      TRUE ~ "Missing"
    ),

    # Region
    region = fct_case_when(
      region == "London" ~ "London",
      region == "East" ~ "East of England",
      region == "East Midlands" ~ "East Midlands",
      region == "North East" ~ "North East",
      region == "North West" ~ "North West",
      region == "South East" ~ "South East",
      region == "South West" ~ "South West",
      region == "West Midlands" ~ "West Midlands",
      region == "Yorkshire and The Humber" ~ "Yorkshire and the Humber",
      TRUE ~ "Missing"),

    stp = factor(as.numeric(str_remove(stp, "STP")), levels = 1:10),
    
    
    #### variables for cumulative incidence
    # baseline is 12 weeks after eligibility date
    baseline = elig_date + weeks(12),
    
    # date of covid vaccine if occured after baseline
    covid_vax_1_date_after = if_else(
      !is.na(covid_vax_1_date) &
        covid_vax_1_date > baseline,
      covid_vax_1_date,
      NA_Date_
      ),
    
    # date of vaccine or censoring
    event_date = pmin(
      death_date, dereg_date, covid_vax_1_date_after, as.Date(dates$end_date), 
      na.rm=TRUE
      ),
    
    # time between baseline and event_date
    time = as.numeric(event_date - baseline),
    
    # status of event
    status = if_else(
      event_date == covid_vax_1_date_after & !is.na(covid_vax_1_date_after), 
      1L, 0L
      )

    # death_with_covid_on_the_death_certificate_group = if_else(
    #   !is.na(death_with_covid_on_the_death_certificate_date) &
    #     (death_with_covid_on_the_death_certificate_date <= elig_date + weeks(12)),
    #   1L, 0L),
    # 
    # death_with_28_days_of_covid_positive_test = if_else(
    #   (death_with_28_days_of_covid_positive_test == 1) &
    #     !is.na(death_date) &
    #     (death_date <= elig_date + weeks(12)),
    #   1L, 0L),
    # 
    # death_date = if_else(
    #   !is.na(death_date) &
    #     (death_date <= elig_date + weeks(12)),
    #   1L, 0L),
    # 
    # dereg_date = if_else(
    #   !is.na(dereg_date) &
    #     (dereg_date <= elig_date + weeks(12)),
    #   1L, 0L)


  ) %>%
  select(jcvi_group, all_of(unname(unlist(all_variables)))) %>%
  mutate(across(-c(age, patient_id, all_variables$survival_vars), as.factor)) %>%
  ## Exclusion criteria
  filter(!is.na(sex), !is.na(ageband))

cat("#### define sample_and_weight function ####\n")
# sample and weight from each level of outcome
sample_and_weight <- function(.data, prob_0 = 1, prob_1 = 0.1) {

  split_data <- .data %>%
    group_split(vax_12)

  bind_rows(
    split_data[[1]] %>%
      sample_frac(size = prob_0) %>%
      mutate(weight = 1/prob_0),
    split_data[[2]] %>%
      sample_frac(size = prob_1) %>%
      mutate(weight = 1/prob_1)
  )

}

cat("#### create data_processed_02 ####\n")
data_processed_02 <- data_processed %>%
  filter(jcvi_group == "02") %>%
  select(all_of(unname(unlist(all_variables[c("outcome",
                                              "age",
                                              "ageband",
                                              "dem_vars",
                                              "clinical_vars",
                                              "jcvi_vars",
                                              "longres_vars",
                                              "covid_vars",
                                              "survival_vars")])))) %>%
  mutate(across(-c(age), as.factor)) %>%
  sample_and_weight() %>%
  droplevels()

cat("#### create data_processed_09 ####\n")
data_processed_09 <- data_processed %>%
  filter(jcvi_group == "09") %>%
  # filter out patients who would have become eligible between the at risk
  # eligibility date and their age-related eligibility date
  # filter(if_all(all_of(unname(unlist(all_variables[c("jcvi_vars",
  #                                                    "longres_vars")]))),
  #               ~ . == "0")) %>%
  # if_all not found because not available in version dplyr_1.0.2
  filter_at(all_of(unname(unlist(all_variables[c("jcvi_vars","longres_vars")]))),
            all_vars(. == "0")) %>%
  filter(!(bmi %in% "Obese III (40+)")) %>%
  select(all_of(unname(unlist(all_variables[c("outcome",
                                              "age",
                                              "ageband",
                                              "dem_vars",
                                              "clinical_vars",
                                              "covid_vars",
                                              "censor_vars",
                                              "survival_vars")])))) %>%
  sample_and_weight() %>%
  droplevels()

cat("#### create data_processed_11 ####\n")
data_processed_11 <- data_processed %>%
  filter(jcvi_group == "11") %>%
  # filter out patients who would have become eligible between the at risk
  filter_at(all_of(unname(unlist(all_variables[c("jcvi_vars","longres_vars")]))),
            all_vars(. == "0")) %>%
  filter(!(bmi %in% "Obese III (40+)")) %>%
  select(all_of(unname(unlist(all_variables[c("outcome",
                                              "age",
                                              "ageband",
                                              "dem_vars",
                                              "clinical_vars",
                                              "preg_vars",
                                              "covid_vars",
                                              "survival_vars")])))) %>%
  sample_and_weight() %>%
  droplevels()

cat("#### create elig_dates_tibble ####\n")
elig_dates_tibble <- data_processed %>%
  mutate(ageband = fct_case_when(between(age, 30, 31) ~ "30-31",
                                 between(age, 32, 33) ~ "32-33",
                                 between(age, 34, 35) ~ "34-35",
                                 between(age, 36, 37) ~ "36-37",
                                 between(age, 38, 39) ~ "38-39",
                                 between(age, 50, 54) ~ "50-55",
                                 between(age, 80, 120) ~ "80+",
                                 TRUE ~ NA_character_)) %>%
  distinct(jcvi_group, ageband, elig_date) %>%
  select(jcvi_group, ageband, elig_date) %>%
  arrange(jcvi_group, ageband, elig_date)
readr::write_rds(elig_dates_tibble, here::here("output", "data", "elig_dates_tibble.rds"))

# split by vax_12 and select 10% of samples with vax_12 = "1!
# create weight column

cat("#### save datasets as .rds files ####\n")
write_rds(data_processed_02, here::here("output", "data", "data_processed_02.rds"), compress = "gz")
write_rds(data_processed_09, here::here("output", "data", "data_processed_09.rds"), compress = "gz")
write_rds(data_processed_11, here::here("output", "data", "data_processed_11.rds"), compress = "gz")
