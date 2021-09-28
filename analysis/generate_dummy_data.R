library(tidyverse)
library(lubridate)

n <- 100000

# input_old <- read_csv("output/input.csv")
# 
# input_old %>% select_if(is.character)
# input_old %>% select_if(is.Date)
# input_old %>% select_if(is.numeric) %>% summary()
# banary_vars <- input_old %>% select_if(is.numeric) %>% select(preg_elig_group:hypertension) %>% names()
# cat(str_c("bind_cols(\nlist(\n",str_c(str_c(banary_vars, "=as.numeric(sample(0:1, size=n, replace=TRUE))"),collapse = ",\n"), "\n)\n) %>%"))
# 
# 
ints <- list(imd = as.numeric(sample(1:32000, size=n, replace=TRUE)),
            ethnicity_6 = as.numeric(sample(1:5, size=n, replace=TRUE)),
            ethnicity_6_sus = as.numeric(sample(1:5, size=n, replace=TRUE)),
            rural_urban = as.numeric(sample(1:8, size=n, replace=TRUE))
            )

cats <- list(jcvi_group = c("02", "09", "11"),
             sex = c("F", "M"),
             smoking_status = c("S", "E", "N", "M"),
             stp = str_c("STP",1:10),
             region = c("East", "East Midlands", "South East", "West Midlands", 'Yorkshire and The Humber', "London", "South West", "North East", "North West"),
             bmi = c("Not obese", "Missing, Obese III (40+)", "Obese II (35-39.9)", "Obese I (30-34.9)")
             )

dates <- list(death_with_covid_on_the_death_certificate_date = seq(as.Date("2020-12-08"), today(), by = "day"),
              death_date = seq(as.Date("2020-12-08"), today(), by = "day"),
              dereg_date = seq(as.Date("2020-12-08"), today(), by = "day"),
              covid_vax_1_date = seq(as.Date("2020-12-08"), today(), by = "day")
              )

dummy_data <- tibble(
  
  elig_date = as.Date(
    sample(c("2020-12-08",
             "2021-01-19",
             "2021-05-13"),
           size = n, 
           replace=TRUE
    )
  ),
  
  age_1 = sample(c(30:39, 50:54, 80:100), size=n, replace=TRUE),
  age_2 = floor(age_1 + abs(rnorm(n, mean=0, sd=0.2)))
  
) %>%
  bind_cols(ints) %>%
  bind_cols(
    lapply(
      cats,
      sample,
      replace=TRUE,
      size=n
    )
  ) %>%
  bind_cols(
    lapply(
      dates,
      sample,
      replace=TRUE,
      size=n
    )
  ) %>%
  bind_cols(
    list(
      preg_elig_group=as.numeric(sample(0:1, size=n, replace=TRUE)),
      covid_positive_test_before_group=as.numeric(sample(0:1, size=n, replace=TRUE)),
      covid_positive_test_during_group=as.numeric(sample(0:1, size=n, replace=TRUE)),
      covid_hospital_admission_before_group=as.numeric(sample(0:1, size=n, replace=TRUE)),
      covid_hospital_admission_during_group=as.numeric(sample(0:1, size=n, replace=TRUE)),
      death_with_28_days_of_covid_positive_test=as.numeric(sample(0:1, size=n, replace=TRUE)),
      cev_ever=as.numeric(sample(0:1, size=n, replace=TRUE)),
      cev_group=as.numeric(sample(0:1, size=n, replace=TRUE)),
      astdx=as.numeric(sample(0:1, size=n, replace=TRUE)),
      asthma_group=as.numeric(sample(0:1, size=n, replace=TRUE)),
      resp_group=as.numeric(sample(0:1, size=n, replace=TRUE)),
      cns_group=as.numeric(sample(0:1, size=n, replace=TRUE)),
      diab_group=as.numeric(sample(0:1, size=n, replace=TRUE)),
      sevment_group=as.numeric(sample(0:1, size=n, replace=TRUE)),
      chd_group=as.numeric(sample(0:1, size=n, replace=TRUE)),
      ckd_group=as.numeric(sample(0:1, size=n, replace=TRUE)),
      cld_group=as.numeric(sample(0:1, size=n, replace=TRUE)),
      immuno_group=as.numeric(sample(0:1, size=n, replace=TRUE)),
      spln_group=as.numeric(sample(0:1, size=n, replace=TRUE)),
      learndis_group=as.numeric(sample(0:1, size=n, replace=TRUE)),
      longres_group=as.numeric(sample(0:1, size=n, replace=TRUE)),
      dmard=as.numeric(sample(0:1, size=n, replace=TRUE)),
      ssri=as.numeric(sample(0:1, size=n, replace=TRUE)),
      hypertension=as.numeric(sample(0:1, size=n, replace=TRUE))
    )
  ) %>%
  mutate(patient_id = row_number()) %>%
  mutate(across(where(is.integer), as.double))

dir.create(here::here("test-data"), showWarnings = FALSE, recursive=TRUE)
readr::write_csv(dummy_data, here::here("test-data", "dummy_data.csv"))


# #  checks
# # all names there and the same?
# all(sort(names(input)) == sort(names(input_old)))
# # any different types
# sort(names(input))[sapply(sort(names(input_old)), function(x) class(input_old[[x]])) != sapply(sort(names(input)), function(x) class(input[[x]]))]
# # only elig_date should be different (that is the point of doing this)