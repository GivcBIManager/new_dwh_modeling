{{ config(order_by='(branch_key, payroll_month, source, payee_key, pay_category_key)') }}

{% set first_month = "toInt32(toYYYYMM(toDate('" ~ var('hnh_history_start_date') ~ "')))" %}

with cutover as (select branch_id, first_fusion_month from {{ ref('stg_ref__payroll_cutover') }}),

categories as (select pay_category_key, pay_category, is_cost, is_gross_pay, fusion_sign from {{ ref('dim_pay_category') }}),

oasis_lines as (
    select t.branch_id as branch_key, 'oasis' as source, t.staff_id as staff_id, cast(null as Nullable(Int64)) as person_id,
           t.payroll_month as payroll_month, ifNull(m.pay_category, 'Unmapped') as pay_category, t.amount as raw_amount,
           toUInt8(k.first_fusion_month is not null and t.payroll_month >= k.first_fusion_month) as is_parallel_run
    from {{ ref('stg_oasis__payroll_transactions') }} as t
    left join (select source_code, payable_type, pay_category from {{ ref('stg_ref__pay_category') }} where source = 'oasis') as m
        on m.source_code = t.trx_type and m.payable_type = t.payable_type
    left join cutover as k on k.branch_id = t.branch_id
    where t.status = 'C' and t.payroll_month >= {{ first_month }} and t.payroll_month % 100 between 1 and 12
    {{ hnh_settings() }}  -- left joins in a CTE feeding a union
),

fusion_recovered as (
    -- GOSI and reference results carry no legal employer; take it from a sibling result of the same person and payroll action.
    select * from (
        select run_result_id, input_value_id, element_type_id, person_id, effective_date, result_value, action_type, payroll_action_id, payroll_action_status,
               max(legal_employer_id) over (partition by person_id, payroll_action_id) as legal_employer_id
        from {{ ref('stg_fusion__payroll_run_results') }}
    )
    where payroll_action_status = 'C' and result_value is not null
),

fusion_results as (
    -- Repeated full regular runs are not rolled back in the extract: keep the latest regular action per person, element, employer
    -- and month (supplementary runs carry other elements), plus QuickPay.
    select run_result_id, input_value_id, element_type_id, person_id, legal_employer_id, effective_date, result_value, action_type, payroll_action_id,
           max(if(action_type = 'R', payroll_action_id, null)) over (partition by person_id, element_type_id, legal_employer_id, toYYYYMM(effective_date)) as latest_regular_action_id
    from fusion_recovered
),

fusion_lines as (
    select ifNull(b.branch_key, toUInt8(0)) as branch_key, 'fusion' as source, cast(null as Nullable(String)) as staff_id, r.person_id as person_id,
           toInt32(toYYYYMM(assumeNotNull(r.effective_date))) as payroll_month, ifNull(m.pay_category, 'Unmapped') as pay_category,
           assumeNotNull(r.result_value) as raw_amount, toUInt8(0) as is_parallel_run
    from fusion_results as r
    inner join (select input_value_id from {{ ref('stg_fusion__payroll_input_values') }} where input_value_base_name = 'Pay Value') as i
        on i.input_value_id = r.input_value_id
    left join {{ ref('int_legal_employer_branch') }} as b on b.legal_employer_id = r.legal_employer_id
    left join cutover as k on k.branch_id = b.branch_key
    left join (select element_type_id, element_name from {{ ref('stg_fusion__payroll_elements') }}) as e on e.element_type_id = r.element_type_id
    left join (select source_code, pay_category from {{ ref('stg_ref__pay_category') }} where source = 'fusion') as m
        on m.source_code = e.element_name
    where (r.action_type = 'Q' or r.payroll_action_id = r.latest_regular_action_id)
      -- an unresolved employer (or one resolved to branch 0) stays visible as branch 0; a resolved one must be in a cutover branch and month
      and (b.branch_key is null or b.branch_key = 0 or toInt32(toYYYYMM(r.effective_date)) >= k.first_fusion_month)
    {{ hnh_settings() }}  -- left joins in a CTE feeding a union
),

lines as (
    select * from oasis_lines
    union all
    select * from fusion_lines
),

aggregated as (
    select l.branch_key as branch_key, l.source as source, l.staff_id as staff_id, l.person_id as person_id,
           l.payroll_month as payroll_month, l.pay_category as pay_category, l.is_parallel_run as is_parallel_run,
           sum(if(l.source = 'fusion', l.raw_amount * c.fusion_sign, l.raw_amount)) as amount,
           any(c.pay_category_key) as pay_category_key, any(c.is_cost) as is_cost, any(c.is_gross_pay) as is_gross_pay
    from lines as l
    inner join categories as c on c.pay_category = l.pay_category
    group by l.branch_key, l.source, l.staff_id, l.person_id, l.payroll_month, l.pay_category, l.is_parallel_run
),

keyed as (
    select a.*,
           if(a.source = 'fusion', {{ hnh_surrogate_key(['a.person_id']) }}, toInt64(-1))           as fusion_employee_key,
           if(a.source = 'oasis', {{ hnh_surrogate_key(['a.branch_key', 'a.staff_id']) }}, toInt64(-1)) as oasis_staff_key,
           toLastDayOfMonth(makeDate(intDiv(a.payroll_month, 100), a.payroll_month % 100, 1))       as month_end
    from aggregated as a
),

resolved as (
    select k.*,
           if(k.source = 'fusion', k.fusion_employee_key, ifNull(bo.employee_key, toInt64(-1)))    as employee_key,
           if(k.source = 'oasis', ifNull(ds.staff_key, toInt64(-1)), ifNull(bf.staff_key, toInt64(-1))) as staff_key
    from keyed as k
    left join (select staff_key, min(employee_key) as employee_key from {{ ref('bridge_employee_staff') }} group by staff_key) as bo on bo.staff_key = k.oasis_staff_key
    left join (select employee_key, staff_key from {{ ref('bridge_employee_staff') }}) as bf on bf.employee_key = k.fusion_employee_key
    left join (select staff_key from {{ ref('dim_staff') }}) as ds on ds.staff_key = k.oasis_staff_key
    {{ hnh_settings() }}
)

select
    {{ hnh_surrogate_key(['r.source', 'r.branch_key', "ifNull(toString(r.person_id), r.staff_id)", 'r.payroll_month', 'r.pay_category', 'r.is_parallel_run']) }} as payroll_key,
    r.branch_key                                                        as branch_key,
    r.source                                                            as source,
    {{ hnh_surrogate_key(['r.source', 'r.branch_key', "ifNull(toString(r.person_id), r.staff_id)"]) }} as payee_key,
    r.employee_key                                                      as employee_key,
    -- one key per person across sources (an Oasis payee linked through the bridge and its Fusion pay share it); distinct count for paid headcount
    if(r.employee_key != -1, r.employee_key, payee_key)                 as paid_person_key,
    r.staff_key                                                         as staff_key,
    r.pay_category_key                                                  as pay_category_key,
    r.pay_category                                                      as pay_category,
    toInt32(r.payroll_month * 100 + 1)                                  as month_date_key,
    r.payroll_month                                                     as payroll_month,
    ifNull(h.hr_department_key, toInt64(-1))                            as hr_department_key,
    r.is_parallel_run                                                   as is_parallel_run,
    r.amount                                                            as amount,
    if(r.is_parallel_run = 0 and r.is_cost = 1, r.amount, 0)            as cost_amount,
    if(r.is_parallel_run = 0 and r.is_gross_pay = 1, r.amount, 0)       as gross_pay,
    now()                                                               as _loaded_at
from resolved as r
left join (select employee_key, month_end, hr_department_key from {{ ref('fact_headcount_monthly') }}) as h
    on h.employee_key = r.employee_key and h.month_end = r.month_end and r.employee_key != -1
{{ hnh_settings() }}
