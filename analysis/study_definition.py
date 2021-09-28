from datetime import date

from cohortextractor import (
    StudyDefinition, 
    patients, 
    filter_codes_by_category
)

# Import codelists.py script
import codelists

# import json module
import json

# import the vairables for deriving JCVI groups
from jcvi_variables import (
    jcvi_variables, 
    studydates,
    start_date,
    end_date,
    pandemic_start,
    ref_cev,
    ref_ar,
)

# Eligibility date for JCVI group
# elig_date= studydates["%placeholder_elig_date%"] # date at which group became eligible for vaccination

# Notes:
# for inequalities in the study definition, an extra expression is added to align with the comparison definitions in https://github.com/opensafely/covid19-vaccine-coverage-tpp-emis/blob/master/analysis/comparisons.py
# variables that define JCVI group membership MUST NOT be dependent on elig_date (index_date), this is for selecting the population based on registration dates and for deriving descriptive covariates
# JCVI groups are derived using ref_age_1, ref_age_2, ref_cev and ref_ar

study = StudyDefinition(

    default_expectations={
        "date": {"earliest": start_date, "latest": end_date},
        "rate": "uniform",
        "incidence": 0.05,
    },

    population=patients.satisfying(
        """
        registered
        AND
        has_follow_up = 1
        AND
        (age_1 >= 16 AND age_1 < 120)
        AND
        NOT died
        AND 
        jcvi_group = '02' OR jcvi_group = '09' OR jcvi_group = '11'
        """,
        registered=patients.registered_as_of(
            "elig_date + 84 days",
        ),
        died=patients.died_from_any_cause(
            on_or_before="elig_date + 84 days",
            returning="binary_flag",
        ),
        has_follow_up=patients.registered_with_one_practice_between(
            start_date="elig_date - 1 year",
            end_date="elig_date",
            return_expectations={"incidence": 0.90},
            ),
    ),
        
    **jcvi_variables,

    elig_date=patients.categorised_as(
        {
            "2020-12-08": "jcvi_group = '02'",
            "2021-03-19": "jcvi_group = '09'",
            "2021-05-13": "jcvi_group = '11' AND age_2 >= 38",
            "2021-05-19": "jcvi_group = '11' AND age_2 >= 36 AND age_2 < 38",
            "2021-05-21": "jcvi_group = '11' AND age_2 >= 34 AND age_2 < 36",
            "2021-05-25": "jcvi_group = '11' AND age_2 >= 32 AND age_2 < 34",
            "2021-05-26": "jcvi_group = '11' AND age_2 >= 30 AND age_2 < 32",
            "2021-12-31": "DEFAULT",
        },
        return_expectations={
            "category": {"ratios": 
            {
                "2020-12-08": 0.125,
                "2021-03-19": 0.125,
                "2021-05-13": 0.125,
                "2021-05-19": 0.125,
                "2021-05-21": 0.125,
                "2021-05-25": 0.125,
                "2021-05-26": 0.125,
                "2021-12-31": 0.125,
            }},
            "incidence": 1,
        },
    ),

    #### patient demographics
    # ethnicity
    ethnicity_6=patients.with_these_clinical_events(
        codelists.eth2001,
        returning="category",
        find_last_match_in_period=True,
        on_or_before="elig_date - 1 day",
        return_expectations={
            "category": {"ratios": {"1": 0.2, "2": 0.2, "3": 0.2, "4": 0.2, "5": 0.2}},
            "incidence": 0.75,
        },
    ),

    ethnicity_6_sus = patients.with_ethnicity_from_sus(
        returning = "group_6",  
        use_most_frequent_code = True,
        return_expectations = {
            "category": {"ratios": {"1": 0.2, "2": 0.2, "3": 0.2, "4": 0.2, "5": 0.2}},
            "incidence": 0.8,
        },
    ),

    # Smoking
    smoking_status = patients.categorised_as(
        {
            "S": "most_recent_smoking_code = 'S'",
            "E": """
                 most_recent_smoking_code = 'E' OR (
                   most_recent_smoking_code = 'N' AND ever_smoked
                 )
            """,
            "N": "most_recent_smoking_code = 'N' AND NOT ever_smoked",
            "M": "DEFAULT",
        },
    
        return_expectations = {
            "rate": "universal",
            "category": {"ratios": {"S": 0.6, "E": 0.1, "N": 0.2, "M": 0.1}},
            "incidence": 1,
        },
    
        most_recent_smoking_code = patients.with_these_clinical_events(
            codelists.clear_smoking_codes,
            find_last_match_in_period = True,
            on_or_before = "elig_date - 1 day",
            returning="category",
        ),
    
        ever_smoked=patients.with_these_clinical_events(
            filter_codes_by_category(codelists.clear_smoking_codes, include=["S", "E"]),
            on_or_before = "elig_date - 1 day",
        ),
    ),

    #### practice and patient address variables
    # IMD - quintile
    imd=patients.address_as_of(
        "elig_date - 1 day",
        returning="index_of_multiple_deprivation",
        round_to_nearest=100,
        return_expectations={
            "rate": "universal",
            "category": {"ratios": {c: 1/320 for c in range(100, 32100, 100)}},
            "incidence": 1,
            }    
    ),

    # rurality
    rural_urban=patients.address_as_of(
        "elig_date - 1 day",
        returning="rural_urban_classification",
        return_expectations={
            "rate": "universal",
            "category": {"ratios": {1: 0.125, 2: 0.125, 3: 0.125, 4: 0.125, 5: 0.125, 6: 0.125, 7: 0.125, 8: 0.125}},
            "incidence": 1,
        },
    ),

    # STP (regional grouping of practices)
    stp=patients.registered_practice_as_of(
        "elig_date - 1 day",
        returning="stp_code",
        return_expectations={
            "rate": "universal",
            "category": {
                "ratios": {
                    "STP1": 0.1,
                    "STP2": 0.1,
                    "STP3": 0.1,
                    "STP4": 0.1,
                    "STP5": 0.1,
                    "STP6": 0.1,
                    "STP7": 0.1,
                    "STP8": 0.1,
                    "STP9": 0.1,
                    "STP10": 0.1,
                },
                "incidence": 1,
            },
        },
    ),

    # region - NHS England 9 regions
    region=patients.registered_practice_as_of(
        "elig_date - 1 day",
        returning = "nuts1_region_name",
        return_expectations = {
            "rate": "universal",
            "category": {
                "ratios": {
                    "North East": 0.1,
                    "North West": 0.1,
                    "Yorkshire and The Humber": 0.1,
                    "East Midlands": 0.1,
                    "West Midlands": 0.1,
                    "East": 0.1,
                    "London": 0.2,
                    "South West": 0.1,
                    "South East": 0.1
                },
            },
        },
    ),

    ### covid vaccine
    covid_vax_1_date=patients.minimum_of(
        # any covid vaccination based on disease target (first in record)
        covid_vax_disease_1_date=patients.with_tpp_vaccination_record(
            target_disease_matches="SARS-2 CORONAVIRUS",
            on_or_after=start_date,
            find_first_match_in_period=True,
            returning="date",
            date_format="YYYY-MM-DD",
            return_expectations={
                "date": {"earliest": start_date, "latest": end_date,},
                "incidence": 0.7
            },
        ),
        # # pfizer vaccine
        covid_vax_pfizer_1_date=patients.with_tpp_vaccination_record(
            product_name_matches="COVID-19 mRNA Vaccine Comirnaty 30micrograms/0.3ml dose conc for susp for inj MDV (Pfizer)",
            on_or_after=start_date,
            find_first_match_in_period=True,
            returning="date",
            date_format="YYYY-MM-DD",
            return_expectations={
                "date": {"earliest": start_date, "latest": end_date,},
                "incidence": 0.7
            },
        ),
        # astrazeneca vaccine
        covid_vax_az_1_date=patients.with_tpp_vaccination_record(
            product_name_matches="COVID-19 Vac AstraZeneca (ChAdOx1 S recomb) 5x10000000000 viral particles/0.5ml dose sol for inj MDV",
            on_or_after=start_date,
            find_first_match_in_period=True,
            returning="date",
            date_format="YYYY-MM-DD",
            return_expectations={
                "date": {"earliest": start_date, "latest": end_date,},
                "incidence": 0.3
            },
        ),
        # moderna vaccine
        covid_vax_moderna_1_date=patients.with_tpp_vaccination_record(
            product_name_matches="COVID-19 mRNA (nucleoside modified) Vaccine Moderna 0.1mg/0.5mL dose dispersion for inj MDV",
            on_or_after=start_date,
            find_first_match_in_period=True,
            returning="date",
            date_format="YYYY-MM-DD",
            return_expectations={
                "date": {"earliest": start_date, "latest": end_date,},
                "incidence": 0.2
            },
        ),
    ),

    #### Pregnancy or Delivery codes recorded (for covariate, NOT used in deriving JCVI group)
    # date of last pregnancy code in 36 weeks before elig_date
    preg_elig_group=patients.satisfying(
        """
        (preg_36wks_date AND sex = 'F' AND age_1 < 50) AND
        (pregdel_pre_elig_date <= preg_36wks_date OR NOT pregdel_pre_elig_date)
        """,
        preg_36wks_date=patients.with_these_clinical_events(
            codelists.preg,
            returning="date",
            find_last_match_in_period=True,
            between=["elig_date - 252 days", "elig_date - 1 day"],
            date_format="YYYY-MM-DD",
        ),
        # date of last delivery code recorded in 36 weeks before elig_date
        pregdel_pre_elig_date=patients.with_these_clinical_events(
            codelists.pregdel,
            returning="date",
            find_last_match_in_period=True,
            between=["elig_date - 252 days", "elig_date - 1 day"],
            date_format="YYYY-MM-DD",
        ),
    ),

    #### COVID infection variables
    # extra variables amended from COVID-19-vaccine-breakthrough project
    # positive COVID test before elig_date
    covid_positive_test_before_group=patients.with_test_result_in_sgss(
        pathogen="SARS-CoV-2",
        test_result="positive",
        returning="binary_flag",
        on_or_before="elig_date - 1 day",
        restrict_to_earliest_specimen_date=False,
    ),

    # positive COVID test in 12 weeks after elig_date
    covid_positive_test_during_group=patients.with_test_result_in_sgss(
        pathogen="SARS-CoV-2",
        test_result="positive",
        returning="binary_flag",
        between=["elig_date","elig_date + 84 days"],
        restrict_to_earliest_specimen_date=False,
    ),
    # probable COVID before elig_date
    covid_probable_before_group=patients.with_these_clinical_events(
        codelists.covid_primary_care_probable_combined,
        returning="binary_flag",
        on_or_before="elig_date - 1 day",
    ),

    # probable COVID 12 weeks after elig_date
    covid_probable_during_group=patients.with_these_clinical_events(
       codelists.covid_primary_care_probable_combined,
        returning="binary_flag",
        between=["elig_date","elig_date + 84 days"],
    ),

    # covid-related hospitalisation before elig_date
    covid_hospital_admission_before_group=patients.admitted_to_hospital(
        returning="binary_flag",
        with_these_diagnoses=codelists.covid_codes,
        on_or_before="elig_date - 1 day",
        date_format="YYYY-MM-DD",
    ),

    # covid-related hospitalisation in 12 weeks after elig_date
    covid_hospital_admission_during_group=patients.admitted_to_hospital(
        returning="binary_flag",
        with_these_diagnoses=codelists.covid_codes,
        between=["elig_date","elig_date + 84 days"],
    ),

    #### censoring variables for cumulative incidence analysis - events after elig_date + 12 weeks
    # COVID related death
    death_with_covid_on_the_death_certificate_date=patients.with_these_codes_on_death_certificate(
        codelists.covid_codes,
        returning="date_of_death",
        date_format="YYYY-MM-DD",
        between=["elig_date + 85 days", end_date],
        # return_expectations={ # this generates an error (also in the following variables where I have commented out "return expectations")
        #     "date": {"earliest": "elig_date","latest": end_date},
        #     "rate": "uniform",
        #     "incidence": 0.01},
    ),

    # Death of any cause
    death_date=patients.died_from_any_cause(
        returning="date_of_death",
        date_format="YYYY-MM-DD",
        between=["elig_date + 85 days", end_date],
        # return_expectations={
        # "date": {"earliest":"elig_date", "latest":end_date},
        # "rate": "uniform",
        # "incidence": 0.1
        # },
    ),

    # Death within 28 days of a positive COVID test
    death_with_28_days_of_covid_positive_test=patients.satisfying(
        """
            death_date
            AND 
            positive_covid_test_prior_28_days
        """, 
        return_expectations={
            "incidence": 0.05,
        },
        positive_covid_test_prior_28_days=patients.with_test_result_in_sgss(
            pathogen="SARS-CoV-2",
            test_result="positive",
            returning="binary_flag",
            between=["death_date - 28 days", "death_date"],
            find_first_match_in_period=True,
            restrict_to_earliest_specimen_date=False,
        ),
    ),

    # De-registration
    dereg_date=patients.date_deregistered_from_all_supported_practices(
        between=["elig_date + 85 days", end_date],
        date_format="YYYY-MM-DD",
        # return_expectations={
        #     "date": {"earliest": "elig_date", "latest": end_date,},
        #     "incidence": 0.001
        # }
    ),

    #### possible contraindications for vaccination
    # on end of life care (maybe too sick for vaccination)
    # 2 weeks before to 12 weeks after
    endoflife=patients.satisfying(
        """
        midazolam OR
        endoflife_coding
        """,
        midazolam=patients.with_these_medications(
            codelists.midazolam_codes,
            returning="binary_flag",
            between=["elig_date - 14 days", "elig_date + 84 days"]
        ),
        endoflife_coding=patients.with_these_clinical_events(
            codelists.eol_codes,
            returning="binary_flag",
            between=["elig_date - 14 days", "elig_date + 84 days"]
        ),

        return_expectations={"incidence": 0.001},
    ),
    # unplanned hospital admission
    admitted_unplanned=patients.admitted_to_hospital(
        returning="binary_flag",
        between=["elig_date - 14 days", "elig_date + 84 days"],
        with_admission_method=["21", "22", "23", "24", "25", "2A", "2B", "2C", "2D", "28"],
        with_patient_classification=["1"],
    ),



    #### clinically extremely vulnerable group variables
    # clinically extremely vulnerable since ref_cev
    cev_ever=patients.with_these_clinical_events(
        codelists.shield,
        returning="binary_flag",
        between=[ref_cev, "elig_date - 1 day"],
        find_last_match_in_period=True,
        # return_expectations={ 
        #     "date": {"earliest": ref_cev, "latest": "elig_date - 1 day"},
        #     "incidence": 0.02
        #     },
    ),

    cev_group=patients.satisfying(
        "severely_clinically_vulnerable AND NOT less_vulnerable",

        # SHIELDED GROUP - first flag all patients with "high risk" codes
        severely_clinically_vulnerable=patients.with_these_clinical_events(
            codelists.shield,
            returning="binary_flag",
            between=[ref_cev, "elig_date - 1 day"],
            find_last_match_in_period=True,
        ),

        # find date at which the high risk code was added
        severely_clinically_vulnerable_date=patients.date_of(
            "severely_clinically_vulnerable",
            date_format="YYYY-MM-DD",
        ),

        # NOT SHIELDED GROUP (medium and low risk) - only flag if later than 'shielded'
        less_vulnerable=patients.with_these_clinical_events(
            codelists.nonshield,
            between=["severely_clinically_vulnerable_date + 1 day", "elig_date - 1 day"],
        ),
        return_expectations={"incidence": 0.01},
    ),

    #### at-risk group variables
    # Asthma Diagnosis code
    astdx = patients.with_these_clinical_events(
        codelists.ast,
        returning="binary_flag",
        on_or_before="elig_date - 1 day",
    ),
            
    # asthma
    asthma_group=patients.satisfying(
        """
        astadm OR
        (astdx AND astrxm1 AND astrxm2 AND astrxm3)
        """,
        # day before date at which at risk group became eligible
        # Asthma Admission codes
        astadm=patients.with_these_clinical_events(
            codelists.astadm,
            returning="binary_flag",
            between=[ref_ar, "elig_date - 1 day"],
        ),
        # Asthma systemic steroid prescription code in month 1
        astrxm1=patients.with_these_medications(
            codelists.astrx,
            returning="binary_flag",
            between=["elig_date - 31 days", "elig_date - 1 day"],
        ),
        # Asthma systemic steroid prescription code in month 2
        astrxm2=patients.with_these_medications(
            codelists.astrx,
            returning="binary_flag",
            between=["elig_date - 61 days", "elig_date - 32 days"],
        ),
        # Asthma systemic steroid prescription code in month 3
        astrxm3=patients.with_these_medications(
            codelists.astrx,
            returning="binary_flag",
            between=["elig_date - 91 days", "elig_date - 62 days"],
        ),
    ),

    # Chronic Respiratory Disease other than asthma
    resp_group=patients.with_these_clinical_events(
        codelists.resp_cov,
        returning="binary_flag",
        between=[ref_ar, "elig_date - 1 day"],
    ),

    # Chronic Neurological Disease including Significant Learning Disorder
    cns_group=patients.with_these_clinical_events(
        codelists.cns_cov,
        returning="binary_flag",
        between=[ref_ar, "elig_date - 1 day"],
    ),

    # diabetes
    diab_group=patients.satisfying(
        """
        (NOT dmres_date AND diab_date) OR
        (dmres_date < diab_date)
        """,
        diab_date=patients.with_these_clinical_events(
            codelists.diab,
            returning="date",
            find_last_match_in_period=True,
            between=[ref_ar, "elig_date - 1 day"],
            date_format="YYYY-MM-DD",
        ),
        dmres_date=patients.with_these_clinical_events(
            codelists.dmres,
            returning="date",
            find_last_match_in_period=True,
            between=[ref_ar, "elig_date - 1 day"],
            date_format="YYYY-MM-DD",
        ),
    ),

    # severe mental illness codes
    sevment_group=patients.satisfying(
        """
        (NOT smhres_date AND sev_mental_date) OR
        smhres_date < sev_mental_date
        """,
        # Severe Mental Illness codes
        sev_mental_date=patients.with_these_clinical_events(
            codelists.sev_mental,
            returning="date",
            find_last_match_in_period=True,
            between=[ref_ar, "elig_date - 1 day"],
            date_format="YYYY-MM-DD",
        ),
        # Remission codes relating to Severe Mental Illness
        smhres_date=patients.with_these_clinical_events(
            codelists.smhres,
            returning="date",
            find_last_match_in_period=True,
            between=[ref_ar, "elig_date - 1 day"],
            date_format="YYYY-MM-DD",
        ),
    ),

    # Chronic heart disease codes
    chd_group=patients.with_these_clinical_events(
        codelists.chd_cov,
        returning="binary_flag",
        between=[ref_ar, "elig_date - 1 day"],
    ),

    # Chronic kidney disease diagnostic codes
    ckd_group=patients.satisfying(
        """
            ckd OR
            (ckd15_date AND 
            (ckd35_date >= ckd15_date) OR (ckd35_date AND NOT ckd15_date))
        """,
        # Chronic kidney disease codes - all stages
        ckd15_date=patients.with_these_clinical_events(
            codelists.ckd15,
            returning="date",
            find_last_match_in_period=True,
            between=[ref_ar, "elig_date - 1 day"],
            date_format="YYYY-MM-DD",
        ),
        # Chronic kidney disease codes-stages 3 - 5
        ckd35_date=patients.with_these_clinical_events(
            codelists.ckd35,
            returning="date",
            find_last_match_in_period=True,
            between=[ref_ar, "elig_date - 1 day"],
            date_format="YYYY-MM-DD",
        ),
        # Chronic kidney disease diagnostic codes
        ckd=patients.with_these_clinical_events(
            codelists.ckd_cov,
            returning="binary_flag",
            between=[ref_ar, "elig_date - 1 day"],
        ),
    ),

    # Chronic Liver disease codes
    cld_group=patients.with_these_clinical_events(
        codelists.cld,
        returning="binary_flag",
        between=[ref_ar, "elig_date - 1 day"],
    ),

    # immunosuppressed
    immuno_group=patients.satisfying(
        "immrx OR immdx", 
        # immunosuppression diagnosis codes
        immdx=patients.with_these_clinical_events(
            codelists.immdx_cov,
            returning="binary_flag",
            between=[ref_ar, "elig_date - 1 day"],
        ),
        # Immunosuppression medication codes
        immrx=patients.with_these_medications(
            codelists.immrx,
            returning="binary_flag",
            between=["elig_date - 6 months", "elig_date - 1 day"],
        ),
    ),

    # Asplenia or Dysfunction of the Spleen codes
    spln_group=patients.with_these_clinical_events(
        codelists.spln_cov,
        returning="binary_flag",
        between=[ref_ar, "elig_date - 1 day"],
    ),

    # Wider Learning Disability
    learndis_group=patients.with_these_clinical_events(
        codelists.learndis,
        returning="binary_flag",
        between=[ref_ar, "elig_date - 1 day"],
    ),

    # Patients in long-stay nursing and residential care
    longres_group=patients.with_these_clinical_events(
        codelists.longres,
        returning="binary_flag",
        between=[start_date, "elig_date - 1 day"],
        return_expectations={"incidence": 0.01},
    ),

    ##### other clinical variables
    # add variables from https://github.com/opensafely/nhs-covid-vaccination-coverage/blob/main/analysis/study_definition_delivery.py 
    # most are commented out as they are included in the variables used for defining the JCVI groups
    # only remaining are: dmards, ssri

    # Medications (from https://github.com/opensafely/nhs-covid-vaccination-coverage)
    dmard=patients.with_these_medications(
        codelists.dmards_codes, 
        between=["elig_date - 1 year", "elig_date - 1 day"],
        returning="binary_flag", 
        return_expectations={"incidence": 0.01,},
    ),
    ssri=patients.with_these_medications(
        codelists.ssri_codes, 
        between=["elig_date - 1 year", "elig_date - 1 day"],
        returning="binary_flag", 
        return_expectations={"incidence": 0.01,},
    ),

    # obesity
    bmi=patients.categorised_as(
        {
          "Missing": "DEFAULT",
          "Not obese": "bmi_value >= 10 AND bmi_value < 30",
          "Obese I (30-34.9)": "bmi_value >= 30 AND bmi_value < 35",
          "Obese II (35-39.9)": "bmi_value >= 35 AND bmi_value < 40",
          "Obese III (40+)": "bmi_value >= 40 AND bmi_value < 100",
          # set minimum and maximum to avoid any impossibly extreme values being classified
        },
    bmi_value=patients.most_recent_bmi(
      between=["elig_date - 5 years", "elig_date - 1 day"],
      minimum_age_at_measurement=16
    ),
    return_expectations = {
      "rate": "universal",
      "category": {
        "ratios": {
          "Missing":0.1,
          "Not obese": 0.6,
          "Obese I (30-34.9)": 0.1,
          "Obese II (35-39.9)": 0.1,
          "Obese III (40+)": 0.1,
        }
      },
    },
  ),

    ## hypertension from risk factors work
    # should there be some adjustment for a normal bp measurement after diagnosed hypertension?
    # hypertension
    hypertension=patients.with_these_clinical_events(
        codelists.hypertension_codes, 
        returning="binary_flag",
        between=["elig_date - 5 years", "elig_date - 1 day"],
        find_last_match_in_period=True,
        return_expectations={"incidence": 0.2,},
    ),
    #### can't find the blood pressure codes!
    # high blood pressure
    # high_bp=patients.satisfying(
    #     # check the upper limits (used to exclude errors)
    #     """
    #     (bp_sys >= 140 AND bp_sys < 250) OR 
    #     (bp_dias >= 90 AND bp_dias < 150)
    #     """,
    #     # https://github.com/ebmdatalab/tpp-sql-notebook/issues/35
    #     bp_sys=patients.mean_recorded_value(
    #         codelists.systolic_blood_pressure_codes,
    #         on_most_recent_day_of_measurement=True,
    #         between=[days(elig_date, -5*365), days(elig_date, -1)],
    #         include_measurement_date=True,
    #         date_format = "YYYY-MM-DD",
    #         return_expectations={
    #             "float": {"distribution": "normal", "mean": 80, "stddev": 10},
    #             "date": {"earliest": days(elig_date, -5*365), "latest": days(elig_date, -1),},
    #             "incidence": 0.95,
    #         },
    #     ),
    #     bp_dias=patients.mean_recorded_value(
    #         codelists.diastolic_blood_pressure_codes,
    #         on_most_recent_day_of_measurement=True,
    #         between=[days(elig_date, -5*365), elig_date],
    #         include_measurement_date=True,
    #         date_format = "YYYY-MM-DD",
    #         return_expectations={
    #             "float": {"distribution": "normal", "mean": 120, "stddev": 10},
    #             "date": {"earliest": days(elig_date, -5*365), "latest": days(elig_date, -1),},
    #             "incidence": 0.95,
    #         },
    #     ),
    # ),
)