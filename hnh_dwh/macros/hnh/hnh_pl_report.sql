{# P&L report line of lower-cased income-statement labels. `labels` names a CTE with source_system, fs_category,
   fs_caption and fs_line; returns those columns plus pl_line_code: the highest-score matching rule of
   pl_report_line_rule (same category; source, caption and line equal or '' in the rule), else 'NOT_MAPPED'.
   ClickHouse cannot take the OR conditions in a join's ON, so the rules join on the category, a where filters, and the
   picked code joins back to the labels. #}
{% macro hnh_pl_report_line_pick(labels) -%}
select
    l.source_system as source_system, l.fs_category as fs_category, l.fs_caption as fs_caption, l.fs_line as fs_line,
    if(p.pl_line_code = '', 'NOT_MAPPED', p.pl_line_code) as pl_line_code
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
