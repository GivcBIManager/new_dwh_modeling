-- The P&L report layout is consistent: no duplicate rule, every rule lands on a detail or not-mapped line, every
-- subtotal adds up sections that exist, and the probe labels resolve to the expected report line.
-- One row per problem.
select 'duplicate rule' as problem, concat(source_system, '|', fs_category, '|', fs_caption, '|', fs_line) as detail
from {{ ref('pl_report_line_rule') }}
group by source_system, fs_category, fs_caption, fs_line
having count() > 1

union all

select 'rule code is not a detail or not-mapped line', concat(r.fs_category, '|', r.fs_caption, '|', r.fs_line, ' -> ', r.pl_line_code)
from {{ ref('pl_report_line_rule') }} as r
where r.pl_line_code not in (select pl_line_code from {{ ref('dim_pl_report_line') }} where line_kind in ('detail', 'not_mapped'))

union all

select 'subtotal section has no line', concat(s.pl_line_code, ' -> ', section)
from {{ ref('dim_pl_report_line') }} as s
array join s.subtotal_sections as section
where s.line_kind = 'subtotal'
  and section not in (select section_name from {{ ref('dim_pl_report_line') }} where line_kind != 'subtotal')

union all

select 'probe resolves to another line', concat(source_system, '|', fs_category, '|', fs_caption, '|', fs_line, ' -> ', pl_line_code, ', expected ', expected)
from (
    with probe as (
        select * from values('source_system String, fs_category String, fs_caption String, fs_line String, expected String',
            ('oasis', 'revenue', 'revenue inpatient', 'revenue cash - ip', 'REV_CASH'),
            ('oasis', 'revenue', 'revenue out patient', 'revenue credit - op', 'REV_CREDIT'),
            ('fusion', 'revenue', 'revenue insurance companies', 'revenue insurance companies', 'REV_CREDIT'),
            ('oasis', 'revenue - discounts', 'revenue - settlement discount', 'early payment disocunt', 'DIS_EARLY_PAYMENT'),
            ('fusion', 'revenue - discounts', 'revenue - settlement discount', 'unclaimed discount', 'DIS_UNCLAIMED'),
            ('fusion', 'direct cost', 'cost of goods sold', 'cost of medicines', 'DC_MEDICINES'),
            ('fusion', 'direct cost', 'cost of goods sold', 'medical gases', 'DC_CONSUMABLES'),
            ('oasis', 'direct cost', 'medical consumables', 'other direct expenses', 'DC_OTHER'),
            ('oasis', 'direct cost', 'depreciation', 'depreciation', 'DEPRECIATION'),
            ('fusion', 'direct cost', 'kitchen expenses', 'hospitality', 'DC_KITCHEN'),
            ('oasis', 'general and administrative expenses', 'other indirect expenses', 'inma supervising expenses', 'HO_CHARGES'),
            ('fusion', 'general and administrative expenses', 'audit fee', 'audit fee', 'GA_AUDIT'),
            ('fusion', 'general and administrative expenses', 'maintenance expense', 'it maintenance', 'GA_MAINTENANCE'),
            ('oasis', 'general and administrative expenses', 'maintenance', 'maintenance expense', 'GA_MAINTENANCE'),
            ('oasis', 'expected credit loss', 'expected credit loss', 'expected credit loss', 'GA_ECL'),
            ('fusion', 'direct cost', 'some new caption', 'x', 'DC_NM'),
            ('oasis', 'not mapped', 'not mapped', 'not mapped', 'NOT_MAPPED'))
    ),
    picked as (
        {{ hnh_pl_report_line_pick('probe') }}
    )
    select p.source_system as source_system, p.fs_category as fs_category, p.fs_caption as fs_caption, p.fs_line as fs_line,
           k.pl_line_code as pl_line_code, p.expected as expected
    from probe as p
    left join picked as k
        on k.source_system = p.source_system and k.fs_category = p.fs_category
           and k.fs_caption = p.fs_caption and k.fs_line = p.fs_line
    where ifNull(k.pl_line_code, '') != p.expected
    {{ hnh_settings() }}
)
