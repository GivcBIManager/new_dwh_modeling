{% set null_s = "cast(null as Nullable(String))" %}

select 'fs label wrong' as failure
where not ifNull({{ hnh_fs_label("'  Deprecition   and Amortization '") }} = 'Depreciation and Amortization', 0)
   or not ifNull({{ hnh_fs_label("'Trade receivables, net'") }} = 'Trade receivables, net', 0)

union all
select 'fs line key wrong'
where {{ hnh_fs_line_key("'BS'", "'Assets'", "'Current Assets'", "'Cash and bank balances'", "'Bank'") }}
   != {{ hnh_fs_line_key("'bs'", "' assets '", "'CURRENT ASSETS'", "'Cash and  bank balances'", "'bank'") }}
   or {{ hnh_fs_line_key("'BS'", "'Assets'", "'Current Assets'", "'Cash and bank balances'", "'Bank'") }}
   = {{ hnh_fs_line_key("'BS'", "'Assets'", "'Current Assets'", "'Cash and bank balances'", "'Cash'") }}

union all
select 'gl care type wrong'
where not ({{ hnh_gl_care_type("'01'") }} = 'OP' and {{ hnh_gl_care_type("'04'") }} = 'OP' and {{ hnh_gl_care_type("'07'") }} = 'OP'
       and {{ hnh_gl_care_type("'08'") }} = 'OP' and {{ hnh_gl_care_type("'09'") }} = 'OP' and {{ hnh_gl_care_type("'10'") }} = 'OP'
       and {{ hnh_gl_care_type("'11'") }} = 'OP' and {{ hnh_gl_care_type("'02'") }} = 'IP' and {{ hnh_gl_care_type("'03'") }} = 'IP'
       and {{ hnh_gl_care_type("'05'") }} = 'IP' and {{ hnh_gl_care_type("'06'") }} = 'ER' and {{ hnh_gl_care_type("'12'") }} = 'Other'
       and {{ hnh_gl_care_type("'13'") }} = 'Other' and {{ hnh_gl_care_type("'00'") }} = 'Unallocated'
       and {{ hnh_gl_care_type("'99'") }} = 'Unallocated' and {{ hnh_gl_care_type(null_s) }} = 'Unallocated')

union all
select 'display sign wrong'
where not ({{ hnh_fs_display_sign("'Revenue'") }} = -1 and {{ hnh_fs_display_sign("'Other income'") }} = -1
       and {{ hnh_fs_display_sign("'Liabilities'") }} = -1 and {{ hnh_fs_display_sign("'Equity'") }} = -1
       and {{ hnh_fs_display_sign("'Assets'") }} = 1 and {{ hnh_fs_display_sign("'Expenses'") }} = 1)

union all
select 'balance side wrong'
where not ({{ hnh_gl_balance_side("'IS'", "'L'") }} = 'IS' and {{ hnh_gl_balance_side(null_s, "'A'") }} = 'BS'
       and {{ hnh_gl_balance_side(null_s, "'L'") }} = 'BS' and {{ hnh_gl_balance_side(null_s, "'O'") }} = 'BS'
       and {{ hnh_gl_balance_side(null_s, "'R'") }} = 'IS' and {{ hnh_gl_balance_side(null_s, "'E'") }} = 'IS'
       and {{ hnh_gl_balance_side(null_s, null_s) }} = 'IS')

union all
select 'not mapped element wrong'
where not ({{ hnh_not_mapped_element("'A'") }} = 'Assets' and {{ hnh_not_mapped_element("'L'") }} = 'Liabilities'
       and {{ hnh_not_mapped_element("'O'") }} = 'Equity' and {{ hnh_not_mapped_element("'R'") }} = 'Revenue'
       and {{ hnh_not_mapped_element("'E'") }} = 'Expenses' and {{ hnh_not_mapped_element(null_s) }} = 'Expenses')

union all
select 'period key for date wrong'
where not ({{ hnh_gl_period_key_for_date("toDate('2026-01-15')") }} = 202601 and {{ hnh_gl_period_key_for_date("toDate('2026-03-31')") }} = 202603
       and {{ hnh_gl_period_key_for_date("toDate('2026-04-01')") }} = 202605 and {{ hnh_gl_period_key_for_date("toDate('2026-06-30')") }} = 202607
       and {{ hnh_gl_period_key_for_date("toDate('2026-07-01')") }} = 202609 and {{ hnh_gl_period_key_for_date("toDate('2026-12-31')") }} = 202615)

union all
select 'natural side wrong'
where not ({{ hnh_budget_natural_side("'REV_OP'", "''") }} = 'credit' and {{ hnh_budget_natural_side("'REV_UNALLOCATED'", "''") }} = 'credit'
       and {{ hnh_budget_natural_side("'OTHER_INCOME'", "''") }} = 'credit' and {{ hnh_budget_natural_side("'OCI'", "''") }} = 'credit'
       and {{ hnh_budget_natural_side("'DC_EMPLOYEE'", "''") }} = 'debit' and {{ hnh_budget_natural_side("'DIS_EARLY_PAY'", "''") }} = 'debit'
       and {{ hnh_budget_natural_side("'UNBUDGETED'", "'Other income'") }} = 'credit'
       and {{ hnh_budget_natural_side("'UNBUDGETED'", "'Revenue'") }} = 'credit'
       and {{ hnh_budget_natural_side("'UNBUDGETED'", "'Direct cost'") }} = 'debit')

union all
select 'ageing bucket wrong'
where not ({{ hnh_ageing_bucket('-5') }} = 'Not due' and {{ hnh_ageing_bucket('0') }} = 'Not due' and {{ hnh_ageing_bucket('1') }} = '1-30'
       and {{ hnh_ageing_bucket('30') }} = '1-30' and {{ hnh_ageing_bucket('31') }} = '31-60' and {{ hnh_ageing_bucket('61') }} = '61-90'
       and {{ hnh_ageing_bucket('91') }} = '91-180' and {{ hnh_ageing_bucket('181') }} = 'Over 180')

union all
select 'prior year results key wrong'
where {{ hnh_prior_year_results_key('toUInt8(6)') }} != toInt64(8342949216454285929)

union all
select 'subtotal weights wrong'
where (select count() from ({{ hnh_budget_subtotal_weights() }})
       where (subtotal_code, component_code, component_group, weight) in (
           ('EBITDA', 'DC_EMPLOYEE', '', -1), ('EBITDA', 'OTHER_INCOME', '', 1), ('EBITDA', 'UNBUDGETED', 'Other income', 1),
           ('EBITDA', 'DIS_EARLY_PAY', '', -1), ('EBITDA', 'REV_OP', '', 1), ('NET_PROFIT', 'DEPRECIATION', '', -1),
           ('DIS_SETTLEMENT', 'DIS_REJECTION_INS', '', 1), ('TOTAL_GA', 'UNBUDGETED', 'Not mapped expenses', 1))) != 8
   or (select count() from ({{ hnh_budget_subtotal_weights() }})
       where component_code in ('REV_SUB', 'DIS_REJECTION', 'DIS_SETTLEMENT', 'REV_NET', 'TOTAL_DC', 'TOTAL_GA',
                                'GROSS_PROFIT', 'EBITDA', 'NET_PROFIT', 'TOTAL_COMP_INCOME')) != 0
   or (select uniqExact(subtotal_code) from ({{ hnh_budget_subtotal_weights() }})) != 10
