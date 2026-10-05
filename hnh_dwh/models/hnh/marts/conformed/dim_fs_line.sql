{{ config(order_by='fs_line_key') }}

with mapped as (
    select fs_type, fs_element, fs_category, fs_caption, fs_line, min(natural_account) as first_account, toUInt8(0) as is_not_mapped
    from {{ ref('stg_ref__fs_account') }}
    group by fs_type, fs_element, fs_category, fs_caption, fs_line
),

not_mapped as (
    -- one Not mapped line per account-type element, so unmapped accounts keep the statements balanced
    select t as fs_type, e as fs_element, 'Not mapped' as fs_category, 'Not mapped' as fs_caption, 'Not mapped' as fs_line,
           toUInt32(4294967295) as first_account, toUInt8(1) as is_not_mapped
    from values('t String, e String', ('BS', 'Assets'), ('BS', 'Liabilities'), ('BS', 'Equity'), ('IS', 'Revenue'), ('IS', 'Expenses'))
),

lines as (
    select * from mapped
    union all
    select * from not_mapped
),

ord as (select level, value_lower, sort_order, statement_group from {{ ref('stg_ref__fs_line_order') }})

select
    {{ hnh_fs_line_key('l.fs_type', 'l.fs_element', 'l.fs_category', 'l.fs_caption', 'l.fs_line') }} as fs_line_key,
    l.fs_type                                                               as fs_type,
    l.fs_element                                                            as fs_element,
    l.fs_category                                                           as fs_category,
    l.fs_caption                                                            as fs_caption,
    l.fs_line                                                               as fs_line,
    ifNull(ot.sort_order, toUInt16(999))                                    as type_sort,
    ifNull(oe.sort_order, toUInt16(999))                                    as element_sort,
    if(l.is_not_mapped = 1, toUInt16(99), ifNull(oc.sort_order, toUInt16(999)))  as category_sort,
    if(l.is_not_mapped = 1, toUInt16(99), ifNull(op.sort_order, toUInt16(999)))  as caption_sort,
    toUInt16(row_number() over (partition by l.fs_type, l.fs_element, l.fs_category, l.fs_caption order by l.first_account, l.fs_line)) as line_sort,
    if(l.is_not_mapped = 1,
       multiIf(l.fs_element = 'Revenue', 'Revenue', l.fs_type = 'IS', 'Not mapped expenses', 'Balance sheet'),
       if(l.fs_type = 'BS', 'Balance sheet', oc.statement_group))           as statement_group,
    {{ hnh_fs_display_sign('l.fs_element') }}                               as display_sign,
    l.is_not_mapped                                                         as is_not_mapped
from lines as l
left join (select value_lower, sort_order from ord where level = 'type') as ot on ot.value_lower = lower(l.fs_type)
left join (select value_lower, sort_order from ord where level = 'element') as oe on oe.value_lower = lower(l.fs_element)
left join (select value_lower, sort_order, statement_group from ord where level = 'category') as oc on oc.value_lower = lower(l.fs_category)
left join (select value_lower, sort_order from ord where level = 'caption') as op on op.value_lower = lower(l.fs_caption)
{{ hnh_settings() }}
