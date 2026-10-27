"""Numerator and denominator of every scorecard KPI's actual (report plan, Task 2).

PARTS maps a KPI code to (numerator DAX, denominator DAX, kind), read from the body of the KPI's own measure in
tables/_Measures.tmdl (gen_bsc_kpi_lists.KPIS names it). The kind says how the parts give the actual:
    ratio   actual = DIVIDE ( numerator, denominator )
    growth  actual = DIVIDE ( numerator, denominator ) - 1, blank without a denominator
    value   actual = numerator; the denominator is "" (blank)
gen_bsc_kpi_lists.py writes them into BSC Numerator and BSC Denominator, which evaluate a part in the filter context
BSC Actual gives the KPI's measure. A part is a DAX expression that stands on its own (it may hold VAR ... RETURN; no
variable named Code, KpiState, Source, Past, Num or Den). A multi-line part keeps its relative indentation in tabs.
An AVERAGE becomes SUM ÷ COUNT of the same column (AVERAGE skips blanks, as COUNT does).

A KPI whose actual is none of the three kinds is listed in NO_PARTS with the reason (and in ssas/README.md); its
numerator and denominator are blank. Manual KPIs ('BSC KPI'[Value Source] = "manual") need no entry: their parts
are the 'BSC Manual Values' numerator and denominator.
"""

# Filters the encounter-based KPIs repeat.
_OP_ARRIVED = 'KEEPFILTERS ( Encounters[Encounter Type] = "OP" ), Encounters[Is Arrived] = "Yes"'
_OP_SEEN = _OP_ARRIVED + ', Encounters[Is Cancelled] = "No"'
_NEW_PATIENT = _OP_ARRIVED + ', KEEPFILTERS ( Encounters[Visit Type] = "New patient" )'
_LEAKAGE = ('Payer[Category] IN { "Insurance", "Government" }, '
            "'Claim Status'[Submission Channel] <> \"Manual\"")
_ALOS = ('Admissions[Is Countable] = "Yes", Admissions[Is LTC] = "No", '
         "USERELATIONSHIP ( Admissions[Physical Discharge Date Key], 'Date'[Date Key] )")
_OCCUPANCY = "'Bed Occupancy'[Is Inpatient Ward] = \"Yes\", 'Bed Occupancy'[Is Excluded Ward] = \"No\""
_PREAUTH = "KEEPFILTERS ( 'Pre-auth Lines'[Line Source] <> \"Payer advance\" )"


def _workforce_heads(extra: str) -> str:
    """Headcount of each branch's last closed workforce month (BSC Saudization)."""
    return ("SUMX (\n"
            "\tVALUES ( Branch[Branch Key] ),\n"
            "\tVAR LastMonth = [BSC Last Workforce Month]\n"
            "\tRETURN IF ( NOT ISBLANK ( LastMonth ), CALCULATE ( SUM ( 'Workforce Monthly'[Headcount] ), "
            "REMOVEFILTERS ( 'Date' ), 'Workforce Monthly'[Month Date Key] = LastMonth, "
            f"'Workforce Monthly'[Row Type] = \"head\"{extra} ) )\n"
            ")")


_PERIOD_END = ("VAR PeriodEnd = CALCULATE ( MAX ( 'Date'[Date] ), KEEPFILTERS ( 'Date'[Date] <= TODAY () ) )\n"
               "VAR LastKey = YEAR ( PeriodEnd ) * 10000 + MONTH ( PeriodEnd ) * 100 + DAY ( PeriodEnd )\n")

PARTS = {
    "FIN_NET_REVENUE": ("[BSC GL Net Revenue]", "", "value"),
    # the actual is the revenue; the growth is scored against last year's revenue as the target
    "FIN_REVENUE_GROWTH": ("[BSC GL Net Revenue]", "", "value"),
    "FIN_EBITDA_MARGIN": ("[BSC GL EBITDA]", "[BSC GL Net Revenue]", "ratio"),
    "FIN_COST_TO_REVENUE": ("[BSC GL Net Revenue] - [BSC GL EBITDA]", "[BSC GL Net Revenue]", "ratio"),
    "FIN_CONSUMABLES_RATIO": ("[BSC GL Consumables]", "[BSC GL Net Revenue]", "ratio"),
    "FIN_DAYS_IN_AR": ("[BSC GL AR Average] * [BSC Days in Period]", "[BSC GL Net Revenue]", "ratio"),
    "FIN_DAYS_INVENTORY": ("[BSC GL Inventory Average] * [BSC Days in Period]", "[BSC GL COGS]", "ratio"),
    "FIN_REVENUE_PER_BED": ("[BSC GL Net Revenue]", "[BSC Available Beds]", "ratio"),
    "FIN_RETURN_ON_ASSETS": ("[BSC GL Income]", "[BSC GL Assets Opening]", "ratio"),
    "FIN_EBITDA_PER_BED": ("[BSC GL EBITDA]", "[BSC Available Beds]", "ratio"),
    "FIN_REVENUE_PER_DOCTOR": ("[BSC GL Net Revenue]", "[BSC Average Doctors]", "ratio"),
    "FIN_EBITDA_PER_DOCTOR": ("[BSC GL EBITDA]", "[BSC Average Doctors]", "ratio"),
    "CUS_MULTI_SPECIALTY_SHARE": (
        "CALCULATE ( [Revenue], 'Care Type'[Care Type] = \"OP\" )\n"
        "\t+ CALCULATE ( [Revenue], 'Care Type'[Care Type] = \"IP\", 'Charge Lines'[Is LTC] = \"No\" )",
        "[Revenue]", "ratio"),
    "CUS_PAYER_MIX": ("CALCULATE ( [Revenue by Episode Payer], Payer[Category] = \"Insurance\" )",
                      "[Revenue by Episode Payer]", "ratio"),
    # Overall Satisfaction (0-100) is the rescaled scored answers summed over their count
    "CUS_PATIENT_SATISFACTION": (
        "VAR Groups =\n"
        "\tCALCULATETABLE (\n"
        "\t\tADDCOLUMNS (\n"
        "\t\t\tSUMMARIZE ( 'Survey Answers', 'Survey Answers'[Scale Type], 'Survey Answers'[Answer Score] ),\n"
        "\t\t\t\"@n\", CALCULATE ( COUNTROWS ( 'Survey Answers' ) )\n"
        "\t\t),\n"
        "\t\t'Survey Answers'[Is Scored] = \"Yes\",\n"
        "\t\tNOT ISBLANK ( 'Survey Answers'[Answer Score] )\n"
        "\t)\n"
        "RETURN\n"
        "\tSUMX (\n"
        "\t\tGroups,\n"
        "\t\t[@n] * SWITCH (\n"
        "\t\t\t'Survey Answers'[Scale Type],\n"
        "\t\t\t\"likelihood_0_10\", 'Survey Answers'[Answer Score] * 10,\n"
        "\t\t\t\"definitely_1_4\", ( 'Survey Answers'[Answer Score] - 1 ) / 3 * 100,\n"
        "\t\t\t( 'Survey Answers'[Answer Score] - 1 ) / 4 * 100\n"
        "\t\t)\n"
        "\t)",
        "CALCULATE ( COUNTROWS ( 'Survey Answers' ), 'Survey Answers'[Is Scored] = \"Yes\", NOT ISBLANK ( 'Survey Answers'[Answer Score] ) )",
        "ratio"),
    # Top Box %: top-of-scale answers over the scored answers
    "CUS_PREMS": (
        "CALCULATE (\n"
        "\tCOUNTROWS ( 'Survey Answers' ),\n"
        "\t'Survey Answers'[Is Scored] = \"Yes\",\n"
        "\tKEEPFILTERS (\n"
        "\t\tFILTER (\n"
        "\t\t\tALL ( 'Survey Answers'[Scale Type], 'Survey Answers'[Answer Score] ),\n"
        "\t\t\tSWITCH (\n"
        "\t\t\t\t'Survey Answers'[Scale Type],\n"
        "\t\t\t\t\"likelihood_0_10\", 'Survey Answers'[Answer Score] >= 9,\n"
        "\t\t\t\t\"definitely_1_4\", 'Survey Answers'[Answer Score] = 4,\n"
        "\t\t\t\t'Survey Answers'[Answer Score] = 5\n"
        "\t\t\t)\n"
        "\t\t)\n"
        "\t)\n"
        ")",
        "[NPS Answers]", "ratio"),
    "CUS_PATIENT_RETENTION": (
        f"CALCULATE ( DISTINCTCOUNT ( Encounters[Patient Key] ), {_OP_SEEN}, Encounters[Is Returning] = \"Yes\" )",
        f"CALCULATE ( DISTINCTCOUNT ( Encounters[Patient Key] ), {_OP_SEEN} )", "ratio"),
    "CUS_NEW_PATIENTS": (f"CALCULATE ( COUNTROWS ( Encounters ), {_NEW_PATIENT} )", "[OP Visits]", "ratio"),
    "CUS_OP_WAIT": (f"CALCULATE ( SUM ( Encounters[Wait Minutes] ), {_OP_SEEN} )",
                    f"CALCULATE ( COUNT ( Encounters[Wait Minutes] ), {_OP_SEEN} )", "ratio"),
    "CUS_NON_MOH_SHARE": ("CALCULATE ( [Revenue by Episode Payer], Payer[Is MOH] = \"No\" )",
                          "[Revenue by Episode Payer]", "ratio"),
    "CUS_PAYER_VOLUME": ("CALCULATE ( [Census], Payer[Category] = \"Insurance\" )", "", "value"),
    "CUS_ACQUISITION_COST": ("[BSC GL Marketing]",
                             f"CALCULATE ( DISTINCTCOUNT ( Encounters[Patient Key] ), {_NEW_PATIENT} )", "ratio"),
    "INT_BED_OCCUPANCY": (f"CALCULATE ( SUM ( 'Bed Occupancy'[Is Occupied] ), {_OCCUPANCY} )",
                          f"CALCULATE ( SUM ( 'Bed Occupancy'[Is Available] ), {_OCCUPANCY} )", "ratio"),
    "INT_OP_UTILIZATION": ("[OP Visits]", "[BSC Clinic Capacity]", "ratio"),
    "INT_ALOS": (f"CALCULATE ( SUM ( Admissions[LOS Days] ), {_ALOS} )",
                 f"CALCULATE ( COUNT ( Admissions[LOS Days] ), {_ALOS} )", "ratio"),
    "INT_OP_TO_IP": ("[Admissions]", "[OP Visits]", "ratio"),
    "INT_PATIENT_VOLUME": ("[OP Visits] + [ER Visits] + [Admissions]", "", "value"),
    "INT_ER_GROWTH": (
        "[ER Visits]",
        "CALCULATE ( [ER Visits], SAMEPERIODLASTYEAR ( "
        "CALCULATETABLE ( VALUES ( 'Date'[Date] ), KEEPFILTERS ( 'Date'[Date] <= TODAY () ) ) ) )", "growth"),
    "INT_DOCTOR_UTILIZATION": ("[OP Visits]", "SUM ( 'Clinic Capacity'[BSC Capacity Slots] )", "ratio"),
    "INT_ACTIVATED_BEDS": ("[BSC Available Beds]", "[BSC Licensed Beds]", "ratio"),
    "INT_HIGH_VALUE_REVENUE": ("CALCULATE ( [Revenue], Staff[Is High Value Specialty] = \"Yes\" )",
                               "[Revenue]", "ratio"),
    "INT_HIGH_VALUE_CENSUS": (
        "CALCULATE ( [Census], 'Booked Doctor'[Is High Value Specialty] = \"Yes\" )\n"
        "\t+ CALCULATE ( [Admissions], Staff[Is High Value Specialty] = \"Yes\" )",
        "[Census]", "ratio"),
    "INT_OP_REVENUE_PER_EPISODE": ("CALCULATE ( [Revenue], 'Care Type'[Care Type] = \"OP\" )",
                                   "CALCULATE ( [Episodes], 'Care Type'[Care Type] = \"OP\" )", "ratio"),
    "INT_ANCILLARY_UTILIZATION": (
        "CALCULATE ( [Revenue], 'Care Type'[Care Type] = \"OP\", 'Product Category'[Is BSC Ancillary] = \"Yes\" )",
        "CALCULATE ( [Revenue], 'Care Type'[Care Type] = \"OP\" )", "ratio"),
    "INT_REVENUE_LEAKAGE": (
        f"CALCULATE ( SUM ( Invoices[Net Amount] ), {_LEAKAGE}, 'Claim Status'[Is Submitted] = \"No\" )",
        f"CALCULATE ( SUM ( Invoices[Net Amount] ), {_LEAKAGE} )", "ratio"),
    "INT_CLAIM_INITIAL_REJECTION": ("[Claims Rejected]", "[Claims Submitted]", "ratio"),
    # BSC Order Not Done is [Unutilised Approval Rate %] = DIVIDE ( [Unutilised Approvals], [Pre-auth Services] )
    "INT_ORDER_NOT_DONE": ("[Unutilised Approvals]", "[Pre-auth Services]", "ratio"),
    # BSC Approval TAT (min) is [Sent to Response Avg (min)], an AVERAGE
    "INT_APPROVAL_TAT": (f"CALCULATE ( SUM ( 'Pre-auth Lines'[Sent To Response Minutes] ), {_PREAUTH} )",
                         f"CALCULATE ( COUNT ( 'Pre-auth Lines'[Sent To Response Minutes] ), {_PREAUTH} )", "ratio"),
    "INT_COST_BUDGET_VARIANCE": ("[BSC GL Opex] - [BSC Budget Opex]", "[BSC Budget Opex]", "ratio"),
    "INT_GA_RATIO": ("[BSC GL G&A]", "[BSC GL Net Revenue]", "ratio"),
    "INT_READMISSION_30D": ("CALCULATE ( [Admissions], Admissions[Is Readmission 30d] = \"Yes\" )", "[Discharges]",
                            "ratio"),
    "INT_READMISSION_48H_CRITICAL": ("[ICU Readmissions 48h]", "CALCULATE ( [Discharges], Bed[Is Critical] = \"Yes\" )",
                                     "ratio"),
    "INT_EXTERNAL_REFERRALS": (
        "CALCULATE ( [Census], Encounters[Is Referral Policy] = \"Yes\" ) "
        "+ CALCULATE ( [Admissions], Admissions[Is Referral Policy] = \"Yes\" )", "", "value"),
    "LRN_TURNOVER": ("SUM ( 'Workforce Monthly'[Resignations] )", "[BSC Average Headcount]", "ratio"),
    "LRN_REVENUE_PER_FTE": ("[BSC GL Net Revenue]", "[BSC Average FTE]", "ratio"),
    "LRN_STAFF_TO_BED": ("[BSC Average FTE]", "[BSC Available Beds]", "ratio"),
    "LRN_SAUDIZATION": (_workforce_heads(", 'Workforce Monthly'[Is Saudi] = 1"), _workforce_heads(""), "ratio"),
    "LRN_VACANCY_RATE": (
        _PERIOD_END + "RETURN\n"
        "\tIF (\n"
        "\t\tNOT ISBLANK ( PeriodEnd ),\n"
        "\t\tCALCULATE (\n"
        "\t\t\tSUM ( Requisitions[Number To Hire] ),\n"
        "\t\t\tREMOVEFILTERS ( 'Date' ),\n"
        "\t\t\tRequisitions[Approved Date Key] <= LastKey,\n"
        "\t\t\tFILTER ( ALL ( Requisitions[Filled Date Key] ), "
        "ISBLANK ( Requisitions[Filled Date Key] ) || Requisitions[Filled Date Key] > LastKey )\n"
        "\t\t)\n"
        "\t)",
        "VAR PeriodEnd = CALCULATE ( MAX ( 'Date'[Date] ), KEEPFILTERS ( 'Date'[Date] <= TODAY () ) )\n"
        "RETURN\n"
        "\tIF (\n"
        "\t\tNOT ISBLANK ( PeriodEnd ),\n"
        "\t\tCALCULATE ( SUM ( 'BSC Budgeted FTE'[Budgeted FTE] ), REMOVEFILTERS ( 'Date' ), "
        "'Date'[Year] = YEAR ( PeriodEnd ) )\n"
        "\t)", "ratio"),
    # BSC Time to Fill (days) is an AVERAGE
    "LRN_TIME_TO_FILL": ("SUM ( Requisitions[Days To Fill] )", "COUNT ( Requisitions[Days To Fill] )", "ratio"),
    "LRN_CLINICAL_TO_DOCTOR": ("[BSC Average Medical]", "[BSC Average Doctors]", "ratio"),
}

NO_PARTS: dict[str, str] = {}
