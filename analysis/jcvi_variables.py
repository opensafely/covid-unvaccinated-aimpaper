from datetime import date

from cohortextractor import (
    patients, 
    filter_codes_by_category
)

# Import codelists.py script
import codelists

# import json module
import json

## import study dates
# change this in design.R if necessary
with open("./analysis/lib/dates.json") as f:
  studydates = json.load(f)

# define variables explicitly
ref_age_1 = studydates["ref_age_1"] # reference date for calculating age for phase 1 groups
ref_age_2 = studydates["ref_age_1"] # reference date for calculating age for phase 2 groups
ref_cev = studydates["ref_cev"] # reference date for calculating eligibility for phase 1 group 4 (CEV)
ref_ar = studydates["ref_ar"] # reference date for calculating eligibility for phase 1 group 5 (at-risk)
start_date = studydates["start_date"] # start of phase 1
end_date = studydates["end_date"] # end of followup
pandemic_start = "2020-01-01"

## function to add days to a string date
from datetime import datetime, timedelta
def days(datestring, days):
  
  dt = datetime.strptime(datestring, "%Y-%m-%d").date()
  dt_add = dt + timedelta(days)
  datestring_add = datetime.strftime(dt_add, "%Y-%m-%d")

  return datestring_add


jcvi_variables = dict(

    # age on phase 1 reference date
    age_1=patients.age_as_of(
        ref_age_1,
        return_expectations={
            "int": {"distribution": "population_ages"},
            "rate": "universal",
        },
    ),

    # age on phase 2 reference date
    age_2=patients.age_as_of(
        ref_age_2,
        return_expectations={
            "int": {"distribution": "population_ages"},
            "rate": "universal",
        },
    ),

    # patient sex
    sex=patients.sex(
        return_expectations={
        "rate": "universal",
        "category": {"ratios": {"M": 0.49, "F": 0.51}},
        "incidence": 1,
        }
    ),
    
    jcvi_group=patients.categorised_as(
        {
            "00": "DEFAULT",
            "01": "longres_dat_temp",
            "02": "age_1 >=80",
            "03": "age_1 >=75",
            "04": "age_1 >=70 OR (cev_group_temp AND age_1 >=16 AND NOT preg_group_temp)",
            "05": "age_1 >=65",
            "06": "atrisk_group_temp AND age_1 >=16",
            "07": "age_1 >=60",
            "08": "age_1 >=55",
            "09": "age_1 >=50",
            "10":"age_2 >=40",
            "11":"age_2 >=30",
            "12":"age_2 >=18",
        },
        return_expectations={
            "rate": "universal",
            "incidence": 1,
            "category":{
                "ratios": {
                    "00": 1/13, "01": 1/13, "02": 1/13, "03": 1/13, "04": 1/13, "05": 1/13, "06": 1/13, "07":1/13, "08":1/13, "09":1/13, "10":1/13, "11":1/13, "12":1/13}}
        },

        #### clinically extremely vulnerable group variables
        # clinically extremely vulnerable
        cev_ever_temp = patients.with_these_clinical_events(
            codelists.shield,
            returning="binary_flag",
            on_or_before = days(ref_cev,-1),
            find_last_match_in_period = True,
            return_expectations={"incidence": 0.02},
        ),

        cev_group_temp = patients.satisfying(

            "severely_clinically_vulnerable_temp AND NOT less_vulnerable_temp",
    
        # SHIELDED GROUP - first flag all patients with "high risk" codes
        severely_clinically_vulnerable_temp=patients.with_these_clinical_events(
            codelists.shield,
            returning="binary_flag",
            on_or_before = days(ref_cev,-1),
            find_last_match_in_period = True,
        ),
    
        # find date at which the high risk code was added
        severely_clinically_vulnerable_date_temp=patients.date_of(
            "severely_clinically_vulnerable_temp",
            date_format="YYYY-MM-DD",
        ),
    
        # NOT SHIELDED GROUP (medium and low risk) - only flag if later than 'shielded'
        less_vulnerable_temp=patients.with_these_clinical_events(
            codelists.nonshield,
            between=["severely_clinically_vulnerable_date_temp + 1 day", days(ref_cev,-1)],
        ),

        return_expectations={"incidence": 0.01},

        ),

        #### at-risk group variables
        # asthma
        asthma_group_temp = patients.satisfying(
            """
            astadm_temp OR
            (astdx_temp AND astrxm1_temp AND astrxm2_temp AND astrxm3_temp)
            """,
            # day before date at which at risk group became eligible

            # Asthma Diagnosis code
            astdx_temp = patients.with_these_clinical_events(
                codelists.ast,
                returning="binary_flag",
                on_or_before=days(ref_ar,-1),
            ),

            # Asthma Admission codes
            astadm_temp=patients.with_these_clinical_events(
                codelists.astadm,
                returning="binary_flag",
                on_or_before=days(ref_ar,-1),
            ),
            # Asthma systemic steroid prescription code in month 1
            astrxm1_temp=patients.with_these_medications(
                codelists.astrx,
                returning="binary_flag",
                between=[days(ref_ar,-31), days(ref_ar,-1)],
            ),
            # Asthma systemic steroid prescription code in month 2
            astrxm2_temp=patients.with_these_medications(
                codelists.astrx,
                returning="binary_flag",
                between=[days(ref_ar,-61), days(ref_ar,-32)],
            ),
            # Asthma systemic steroid prescription code in month 3
            astrxm3_temp=patients.with_these_medications(
                codelists.astrx,
                returning="binary_flag",
                between= [days(ref_ar,-91), days(ref_ar,-62)],
            ),
        ),

        # Chronic Respiratory Disease
        resp_group_temp=patients.satisfying(
            "asthma_group_temp OR resp_cov_temp",
            resp_cov_temp=patients.with_these_clinical_events(
                codelists.resp_cov,
                returning="binary_flag",
                on_or_before=days(ref_ar,-1),
            ),
        ),

        # Chronic Neurological Disease including Significant Learning Disorder
        cns_group_temp=patients.with_these_clinical_events(
            codelists.cns_cov,
            returning="binary_flag",
            on_or_before=days(ref_ar,-1),
        ),

        # severe obesity
        sevobese_group_temp=patients.satisfying(
            """
            (sev_obesity_date_temp AND NOT bmi_date_temp) OR
            (sev_obesity_date_temp > bmi_date_temp) OR
            bmi_value_temp >= 40
            """,

            bmi_stage_date_temp=patients.with_these_clinical_events(
                codelists.bmi_stage,
                returning="date",
                find_last_match_in_period=True,
                on_or_before=days(ref_ar,-1),
                date_format="YYYY-MM-DD",
            ),
    
            sev_obesity_date_temp=patients.with_these_clinical_events(
                codelists.sev_obesity,
                returning="date",
                find_last_match_in_period=True,
                ignore_missing_values=True,
                between= ["bmi_stage_date_temp", days(ref_ar,-1)],
                date_format="YYYY-MM-DD",
            ),
    
            bmi_date_temp=patients.with_these_clinical_events(
                codelists.bmi,
                returning="date",
                ignore_missing_values=True,
                find_last_match_in_period=True,
                on_or_before=days(ref_ar,-1),
                date_format="YYYY-MM-DD",
            ),
    
            bmi_value_temp=patients.with_these_clinical_events(
                codelists.bmi,
                returning="numeric_value",
                ignore_missing_values=True,
                find_last_match_in_period=True,
                on_or_before=days(ref_ar,-1),
                return_expectations={
                    "float": {"distribution": "normal", "mean": 25, "stddev": 5},
                },
            ),
        ),

        # diabetes
        diab_group_temp=patients.satisfying(
            """
            (NOT dmres_date_temp AND diab_date_temp) OR
            (dmres_date_temp < diab_date_temp)
            """,
            diab_date_temp=patients.with_these_clinical_events(
                codelists.diab,
                returning="date",
                find_last_match_in_period=True,
                on_or_before=days(ref_ar,-1),
                date_format="YYYY-MM-DD",
            ),
            dmres_date_temp=patients.with_these_clinical_events(
                codelists.dmres,
                returning="date",
                find_last_match_in_period=True,
                on_or_before=days(ref_ar,-1),
                date_format="YYYY-MM-DD",
            ),
        ),

        # severe mental illness codes
        sevment_group_temp=patients.satisfying(
            """
            (NOT smhres_date_temp AND sev_mental_date_temp) OR
            smhres_date_temp < sev_mental_date_temp
            """,
            # Severe Mental Illness codes
            sev_mental_date_temp=patients.with_these_clinical_events(
                codelists.sev_mental,
                returning="date",
                find_last_match_in_period=True,
                on_or_before=days(ref_ar,-1),
                date_format="YYYY-MM-DD",
            ),
            # Remission codes relating to Severe Mental Illness
            smhres_date_temp=patients.with_these_clinical_events(
                codelists.smhres,
                returning="date",
                find_last_match_in_period=True,
                on_or_before=days(ref_ar,-1),
                date_format="YYYY-MM-DD",
            ),
        ),

        # Chronic heart disease codes
        chd_group_temp=patients.with_these_clinical_events(
            codelists.chd_cov,
            returning="binary_flag",
            on_or_before=days(ref_ar,-1),
        ),

        # Chronic kidney disease diagnostic codes
        ckd_group_temp=patients.satisfying(
            """
            ckd_temp OR
            (ckd15_date_temp AND 
            (ckd35_date_temp >= ckd15_date_temp) OR (ckd35_date_temp AND NOT ckd15_date_temp))
            """,
            # Chronic kidney disease codes - all stages
            ckd15_date_temp=patients.with_these_clinical_events(
                codelists.ckd15,
                returning="date",
                find_last_match_in_period=True,
                on_or_before=days(ref_ar,-1),
                date_format="YYYY-MM-DD",
            ),
            # Chronic kidney disease codes-stages 3 - 5
            ckd35_date_temp=patients.with_these_clinical_events(
                codelists.ckd35,
                returning="date",
                find_last_match_in_period=True,
                on_or_before=days(ref_ar,-1),
                date_format="YYYY-MM-DD",
            ),
            # Chronic kidney disease diagnostic codes
            ckd_temp=patients.with_these_clinical_events(
                codelists.ckd_cov,
                returning="binary_flag",
                on_or_before=days(ref_ar,-1),
            ),
        ),

        # Chronic Liver disease codes
        cld_group_temp=patients.with_these_clinical_events(
            codelists.cld,
            returning="binary_flag",
            on_or_before=days(ref_ar,-1),
        ),

        # immunosuppressed
        immuno_group_temp=patients.satisfying(
            "immrx_temp OR immdx_temp", 
            # immunosuppression diagnosis codes
            immdx_temp=patients.with_these_clinical_events(
                codelists.immdx_cov,
                returning="binary_flag",
                on_or_before=days(ref_ar,-1),
            ),
            # Immunosuppression medication codes
            immrx_temp=patients.with_these_medications(
                codelists.immrx,
                returning="binary_flag",
                between=[days(ref_ar,-6*30), days(ref_ar,-1)]
            ),
        ),

        # Asplenia or Dysfunction of the Spleen codes
        spln_group_temp=patients.with_these_clinical_events(
            codelists.spln_cov,
            returning="binary_flag",
            on_or_before=days(ref_ar,-1),
        ),

        # Wider Learning Disability
        learndis_group_temp=patients.with_these_clinical_events(
            codelists.learndis,
            returning="binary_flag",
            on_or_before=days(ref_ar,-1),
        ),

        # at-risk group
        # severe obesity missing from Will's atrisk group definitions - check why and remove if necessary
        atrisk_group_temp=patients.satisfying(
             """
             immuno_group_temp OR
             ckd_group_temp OR
             resp_group_temp OR
             diab_group_temp OR
             cld_group_temp OR
             cns_group_temp OR
             chd_group_temp OR
             spln_group_temp OR
             learndis_group_temp OR
             sevment_group_temp OR
             sevobese_group_temp
            """,
            return_expectations = {
            "incidence": 0.01,
            },
        ),

        # Patients in long-stay nursing and residential care
        longres_dat_temp=patients.with_these_clinical_events(
            codelists.longres,
            returning="binary_flag",
            on_or_before=days(start_date,-1),
            return_expectations={"incidence": 0.01},
        ),

        #### Pregnancy or Delivery codes recorded in the 36 weeks before ref_cev (to exclude from CEV group)
        preg_group_temp=patients.satisfying(
            """
            ((preg_dat_temp AND NOT pregdel_dat_temp) OR (preg_dat_temp AND pregdel_dat_temp <= preg_dat_temp)) AND
            (sex = 'F' AND age_1 < 50)
            """,
            preg_dat_temp=patients.with_these_clinical_events(
                codelists.preg,
                returning="date",
                find_last_match_in_period=True,
                between=[days(ref_cev,-253), days(ref_cev,-1)],
                date_format="YYYY-MM-DD",
            ),
            pregdel_dat_temp=patients.with_these_clinical_events(
                codelists.pregdel,
                returning="date",
                find_last_match_in_period=True,
                between=[days(ref_cev,-253), days(ref_cev,-1)],
                date_format="YYYY-MM-DD",
            ),
        ),
    ),

)