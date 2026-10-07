{{ hnh_ssas_view('fact_payroll_monthly', drop=['payroll_key', 'payee_key', 'paid_person_key', 'pay_category', 'payroll_month'], decimals=['amount', 'cost_amount', 'gross_pay']) }}
