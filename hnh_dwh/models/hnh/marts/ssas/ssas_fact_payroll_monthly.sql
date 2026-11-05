{#- grade_key: the employee's grade in the month's headcount snapshot (HR report pay by grade, user request
    2026-11-05): payroll rows are dated the 1st, headcount rows the month end, so they meet on the month (one headcount
    row per employee and month). g_grade_key is Nullable, so an unmatched row reads NULL without join_use_nulls. -1 (Unknown)
    without a headcount row: before 2026 and Oasis staff with no Fusion employee (about 10 to 15 % of gross pay). -#}
{%- set grade_join -%}
left join (
    select employee_key as g_employee_key, intDiv(month_date_key, 100) as g_month, toNullable(any(grade_key)) as g_grade_key
    from {{ ref('fact_headcount_monthly') }}
    group by employee_key, intDiv(month_date_key, 100)
) as g on g.g_employee_key = t.employee_key and g.g_month = intDiv(t.month_date_key, 100)
{%- endset -%}
{{ hnh_ssas_view('fact_payroll_monthly', drop=['payroll_key', 'payee_key', 'paid_person_key', 'pay_category', 'payroll_month'], decimals=['amount', 'cost_amount', 'gross_pay', 'oasis_payment_amount', 'oasis_deduction_amount'], titles=['source'], extra=['toInt64(ifNull(g.g_grade_key, -1)) as grade_key'], joins=grade_join) }}
