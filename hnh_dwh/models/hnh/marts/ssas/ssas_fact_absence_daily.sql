{#- Contingent workers left out: they count only in the Headcount table's contingent rows (user decision 2026-11-19). -#}
{{ hnh_ssas_view('fact_absence_daily', drop=['absence_day_key'], where='t.employee_key not in (' ~ hnh_contingent_employee_keys() ~ ')') }}
