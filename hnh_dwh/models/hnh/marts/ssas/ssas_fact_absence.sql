{#- Contingent workers left out: they count only in the Headcount table's contingent rows (user decision 2026-11-19). -#}
{{ hnh_ssas_view('fact_absence', drop=['absence_key'], floats=['absence_days', 'absence_hours'], where='t.employee_key not in (' ~ hnh_contingent_employee_keys() ~ ')') }}
