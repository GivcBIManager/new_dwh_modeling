-- Conservation, per source: Oasis status-C amounts in the window, and Fusion pay-value results of completed actions (employer
-- recovered from the sibling results of the action, latest regular action per person/element/employer/month plus QuickPay)
-- in cutover months, reach the fact once (signed). Unresolved employers must reach the fact as branch 0.
with oasis_staged as (
    select round(sum(amount), 2) as amt
    from {{ ref('stg_oasis__payroll_transactions') }}
    where status = 'C' and payroll_month >= toInt32(toYYYYMM(toDate('{{ var("hnh_history_start_date") }}'))) and payroll_month % 100 between 1 and 12
),
recovered as (
    select * from (
        select input_value_id, element_type_id, person_id, effective_date, result_value, action_type, payroll_action_id, payroll_action_status,
               max(legal_employer_id) over (partition by person_id, payroll_action_id) as legal_employer_id
        from {{ ref('stg_fusion__payroll_run_results') }}
    )
    where payroll_action_status = 'C' and result_value is not null
),
latest as (
    select *, max(if(action_type = 'R', payroll_action_id, null)) over (partition by person_id, element_type_id, legal_employer_id, toYYYYMM(effective_date)) as latest_regular_action_id
    from recovered
),
fusion_staged as (
    select round(sum(r.result_value * ifNull(c.fusion_sign, 1)), 2) as amt
    from latest as r
    inner join (select input_value_id from {{ ref('stg_fusion__payroll_input_values') }} where input_value_base_name = 'Pay Value') as i
        on i.input_value_id = r.input_value_id
    left join {{ ref('int_legal_employer_branch') }} as b on b.legal_employer_id = r.legal_employer_id
    left join {{ ref('stg_ref__payroll_cutover') }} as k on k.branch_id = b.branch_key
    left join (select element_type_id, element_name from {{ ref('stg_fusion__payroll_elements') }}) as e on e.element_type_id = r.element_type_id
    left join (select source_code, pay_category from {{ ref('stg_ref__pay_category') }} where source = 'fusion') as m on m.source_code = e.element_name
    left join {{ ref('dim_pay_category') }} as c on c.pay_category = ifNull(m.pay_category, 'Unmapped')
    where (r.action_type = 'Q' or r.payroll_action_id = r.latest_regular_action_id)
      and (b.branch_key is null or toInt32(toYYYYMM(r.effective_date)) >= k.first_fusion_month)
    {{ hnh_settings() }}
),
fact as (
    select round(sumIf(amount, source = 'oasis'), 2) as oasis_amt, round(sumIf(amount, source = 'fusion'), 2) as fusion_amt
    from {{ ref('fact_payroll_monthly') }}
)
select 'payroll fact differs from staging' as failure, f.oasis_amt, o.amt as oasis_staged, f.fusion_amt, u.amt as fusion_staged
from fact as f cross join oasis_staged as o cross join fusion_staged as u
where abs(f.oasis_amt - o.amt) > 0.01 or abs(f.fusion_amt - u.amt) > 0.01
{{ hnh_settings() }}
