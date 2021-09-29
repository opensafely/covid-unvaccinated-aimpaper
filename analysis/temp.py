# severe obesity
        sevobese_group=patients.satisfying(
            """
            (sev_obesity_date AND NOT bmi_date) OR
            (sev_obesity_date > bmi_date) OR
            bmi_value >= 40
            """,

            bmi_stage_date=patients.with_these_clinical_events(
                codelists.bmi_stage,
                returning="date",
                find_last_match_in_period=True,
                on_or_before="elig_date - 1 day",
                date_format="YYYY-MM-DD",
            ),
    
            sev_obesity_date=patients.with_these_clinical_events(
                codelists.sev_obesity,
                returning="date",
                find_last_match_in_period=True,
                ignore_missing_values=True,
                between= ["bmi_stage_date", "elig_date - 1 day"],
                date_format="YYYY-MM-DD",
            ),
    
            bmi_date=patients.with_these_clinical_events(
                codelists.bmi,
                returning="date",
                ignore_missing_values=True,
                find_last_match_in_period=True,
                on_or_before="elig_date - 1 day",
                date_format="YYYY-MM-DD",
            ),
    
            bmi_value=patients.with_these_clinical_events(
                codelists.bmi,
                returning="numeric_value",
                ignore_missing_values=True,
                find_last_match_in_period=True,
                on_or_before="elig_date - 1 day",
                return_expectations={
                    "float": {"distribution": "normal", "mean": 25, "stddev": 5},
                },
            ),
        ),