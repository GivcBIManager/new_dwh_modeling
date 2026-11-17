{# P&L report line of lower-cased income-statement labels. `labels` names a CTE with source_system, fs_category,
   fs_caption and fs_line; returns those columns plus pl_line_code: the highest-score matching rule of
   pl_report_line_rule (same category; source, caption and line equal or '' in the rule), else 'NOT_MAPPED'.
   ClickHouse cannot take the OR conditions in a join's ON, so the rules join on the category, a where filters, and the
   picked code joins back to the labels; unmatched labels give NULL or '' by join_use_nulls, both become NOT_MAPPED. #}
{% macro hnh_pl_report_line_pick(labels) -%}
select
    l.source_system as source_system, l.fs_category as fs_category, l.fs_caption as fs_caption, l.fs_line as fs_line,
    coalesce(nullIf(p.pl_line_code, ''), 'NOT_MAPPED') as pl_line_code
from (select distinct source_system, fs_category, fs_caption, fs_line from {{ labels }}) as l
left join (
    select
        d.source_system as source_system, d.fs_category as fs_category, d.fs_caption as fs_caption, d.fs_line as fs_line,
        argMax(r.pl_line_code, r.score) as pl_line_code
    from (select distinct source_system, fs_category, fs_caption, fs_line from {{ labels }}) as d
    inner join {{ ref('pl_report_line_rule') }} as r on r.fs_category = d.fs_category
    where (r.source_system = '' or r.source_system = d.source_system)
      and (r.fs_caption = '' or r.fs_caption = d.fs_caption)
      and (r.fs_line = '' or r.fs_line = d.fs_line)
    group by d.source_system, d.fs_category, d.fs_caption, d.fs_line
) as p
    on p.source_system = l.source_system and p.fs_category = l.fs_category
       and p.fs_caption = l.fs_caption and p.fs_line = l.fs_line
{%- endmacro %}

{# Fusion detail rows of the P&L report for balance_view ('including_unposted' or 'posted'): fact_gl_balance_monthly
   income-statement accounts per branch, month (an adjustment period lands in its hnh_dim_gl_period.month_start), natural
   account, lower-case FS labels and slicer names ('Unallocated' when a segment name is missing). amount = credit
   positive movement without the go-live opening-balance journals. Head Office (100) always; branches 1-8 from their
   first Fusion GL month (stg_ref__gl_cutover; a branch without a row stays on Oasis); branch 0 never. Exact-zero
   movements are skipped. Returns the input of hnh_pl_report_rows. #}
{% macro hnh_pl_report_fusion_details(balance_view) -%}
select
    f.branch_key                                                        as branch_key,
    p.month_start                                                       as month_start,
    'fusion'                                                            as source_system,
    -- the natural account (segment 2), as fact_gl_fs_monthly; a combination without one keeps its own key
    ifNull(toString(a.natural_account), toString(f.gl_account_key))     as account_code,
    lower(d.fs_category)                                                as fs_category,
    lower(d.fs_caption)                                                 as fs_caption,
    lower(d.fs_line)                                                    as fs_line,
    ifNull(a.specialty_name, 'Unallocated')                             as specialty_name,
    ifNull(a.service_location_name, 'Unallocated')                      as service_location_name,
    ifNull(a.service_group_name, 'Unallocated')                         as service_group_name,
    -sum(f.period_movement_excl_opening)                                as amount
from {{ ref('fact_gl_balance_monthly') }} as f
inner join {{ ref('hnh_dim_gl_period') }} as p on p.period_key = f.period_key
inner join {{ ref('hnh_dim_gl_account') }} as a on a.gl_account_key = f.gl_account_key
inner join {{ ref('dim_fs_line') }} as d on d.fs_line_key = a.fs_line_key
-- first month each branch's report rows come from Fusion; an inner join, so no Nullable cutover under join_use_nulls
inner join (
    select branch_id as branch_key, first_fusion_gl_month_start
    from {{ ref('stg_ref__gl_cutover') }}
    where branch_id between 1 and 8
    union all
    select toUInt8(100), toDate('1970-01-01')
) as c on c.branch_key = f.branch_key
where f.balance_view = '{{ balance_view }}'
  and lower(d.fs_type) = 'is'
  and p.month_start >= c.first_fusion_gl_month_start
  and f.period_movement_excl_opening != 0
group by branch_key, month_start, account_code, fs_category, fs_caption, fs_line, specialty_name, service_location_name,
         service_group_name
{%- endmacro %}

{# P&L report rows from detail rows. `details` names a CTE with branch_key, month_start, source_system, account_code,
   fs_category, fs_caption, fs_line (lower case, not Nullable), specialty_name, service_location_name,
   service_group_name and amount (credit positive), at any grain. Returns branch_key, month_start, source_system,
   pl_line_key, pl_line_code, account_code, fs_category, fs_caption, fs_line, the three slicer names and amount:
   - detail rows: the labels resolved to a detail or not-mapped line (hnh_pl_report_line_pick), summed per line,
     account, labels and slicer names;
   - subtotal rows: per subtotal line, the detail and not-mapped rows whose section is in its subtotal_sections
     (in-section subtotals such as REV_TOTAL carry a section too, so subtotals never add subtotals), summed per branch,
     month, source and slicer names; account and labels ''.
   Rows with abs(amount) < 0.005 are left out. A full select with its own WITH: use it as a subquery. #}
{% macro hnh_pl_report_rows(details) -%}
with
pl_labels as (
    select distinct source_system, fs_category, fs_caption, fs_line from {{ details }}
),

pl_label_line as (
    {{ hnh_pl_report_line_pick('pl_labels') }}
),

pl_detail as (
    select
        d.branch_key as branch_key, d.month_start as month_start, d.source_system as source_system,
        l.pl_line_key as pl_line_key, l.pl_line_code as pl_line_code, l.section_name as section_name,
        d.account_code as account_code, d.fs_category as fs_category, d.fs_caption as fs_caption, d.fs_line as fs_line,
        d.specialty_name as specialty_name, d.service_location_name as service_location_name,
        d.service_group_name as service_group_name, sum(d.amount) as amount
    from {{ details }} as d
    inner join pl_label_line as k
        on k.source_system = d.source_system and k.fs_category = d.fs_category
           and k.fs_caption = d.fs_caption and k.fs_line = d.fs_line
    inner join (
        select pl_line_key, pl_line_code, section_name
        from {{ ref('dim_pl_report_line') }}
        where line_kind in ('detail', 'not_mapped')
    ) as l on l.pl_line_code = k.pl_line_code
    group by branch_key, month_start, source_system, pl_line_key, pl_line_code, section_name, account_code,
             fs_category, fs_caption, fs_line, specialty_name, service_location_name, service_group_name
),

pl_subtotal as (
    select
        d.branch_key as branch_key, d.month_start as month_start, d.source_system as source_system,
        s.pl_line_key as pl_line_key, s.pl_line_code as pl_line_code, '' as account_code, '' as fs_category,
        '' as fs_caption, '' as fs_line, d.specialty_name as specialty_name,
        d.service_location_name as service_location_name, d.service_group_name as service_group_name,
        sum(d.amount) as amount
    from pl_detail as d
    inner join (
        select pl_line_key, pl_line_code, section
        from {{ ref('dim_pl_report_line') }}
        array join subtotal_sections as section
        where line_kind = 'subtotal'
    ) as s on s.section = d.section_name
    group by branch_key, month_start, source_system, pl_line_key, pl_line_code, specialty_name, service_location_name,
             service_group_name
),

pl_rows as (
    select branch_key, month_start, source_system, pl_line_key, pl_line_code, account_code, fs_category, fs_caption,
           fs_line, specialty_name, service_location_name, service_group_name, amount
    from pl_detail
    union all
    select branch_key, month_start, source_system, pl_line_key, pl_line_code, account_code, fs_category, fs_caption,
           fs_line, specialty_name, service_location_name, service_group_name, amount
    from pl_subtotal
)

select * from pl_rows where abs(amount) >= 0.005
{%- endmacro %}
