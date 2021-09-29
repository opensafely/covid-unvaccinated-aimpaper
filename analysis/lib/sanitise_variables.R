sanitise_variables <- function(.data, var) {
  .data %>%
    mutate(across({{var}}, ~ case_when(. %in% c("sex", "region", "ethnicity", "hypertension")
                                       ~ str_to_sentence(.),
                                       . %in% "flu_vaccine"
                                       ~ "Flu vaccine in 2019/2020 period",
                                       . %in% "gp_consultation_rate"
                                       ~ "GP consultations in 2019",
                                       . %in% "endoflife"
                                       ~ "End of life care while eligible",
                                       . %in% "admitted_unplanned"
                                       ~ "Unplanned hosp. admission while eligible",
                                       . %in% "covid_probable_before_group"
                                       ~ "Probable COVID before eligible",
                                       . %in% "covid_probable_during_group"
                                       ~ "Probable COVID while eligible",
                                       . %in% "ageband"
                                       ~ "Age group",
                                       . %in% "longres_group"
                                       ~ "Long-term residential home",
                                       . %in% "rural_urban"
                                       ~ "Rural urban classification",
                                       . %in% c("smoking_status") 
                                       ~ str_to_sentence(str_replace(., "_", " ")),
                                       . %in% c("imd", "bmi", "stp", "ssri", "dmard")
                                       ~ toupper(.),
                                       . %in% "asthma_group"
                                       ~ "Severe asthma",
                                       . %in% "astdx"
                                       ~ "Any asthma",
                                       . %in% "diab_group"
                                       ~ "Diabetes",
                                       . %in% "immuno_group"
                                       ~ "Immunosuppressed",
                                       . %in% "learndis_group"
                                       ~ "Learning disability",
                                       . %in% "resp_group"
                                       ~ "Chronic respiratory disease",
                                       . %in% "sevment_group"
                                       ~ "Severe mental illness",
                                       . %in% "spln_group"
                                       ~ "Asplenia/dysfunction of spleen",
                                       . %in% "cev_group"
                                       ~ "Clinically extremely vulnerable",
                                       . %in% "chd_group"
                                       ~ "Chronic heart disease",
                                       . %in% "ckd_group"
                                       ~ "Chronic kidney disease",
                                       . %in% "cld_group"
                                       ~ "Chronic liver disease",
                                       . %in% "cns_group"
                                       ~ "Chronic neurological disease",
                                       . %in% "covid_positive_test_before_group"
                                       ~ "COVID +ve test before eligible",
                                       . %in% "covid_positive_test_during_group"
                                       ~ "COVID +ve test while eligible",
                                       . %in% "covid_hospital_admission_before_group"
                                       ~ "COVID hosp. before eligible",
                                       . %in% "covid_hospital_admission_during_group"
                                       ~ "COVID hosp. while eligible",
                                       . %in% "death_with_covid_on_the_death_certificate_group"
                                       ~ "Death while eligible (COVID on cert.)",
                                       . %in% "death_with_28_days_of_covid_positive_test"
                                       ~ "Death while eligible (COVID +ve 28 days)",
                                       . %in% "death_date"
                                       ~ "Death while eligible (any cause)",
                                       . %in% "dereg_date"
                                       ~ "Deregistered while eligible",
                                       . %in% "preg_jcvi_group"
                                       ~ "Pregnant when JCVI group calculated",
                                       . %in% "preg_elig_group"
                                       ~ "Pregnant on eligibility date",
                                       TRUE ~ .)))
}
