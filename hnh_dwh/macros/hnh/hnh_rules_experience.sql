{# NPS-style band of a scored answer (spec X1-X3). Every scale is oriented higher = better. The 1-4 scale has no
   passive. score is the option score from pg_survey_answer_options, never the raw answer code (spec P4). #}
{% macro hnh_survey_band(scale_type, score) -%}
multiIf({{ score }} is null, cast(null as Nullable(String)),
        ifNull({{ scale_type }}, '') in ('rating_1_5', 'agree_1_5'),
            multiIf({{ score }} >= 4, 'Promoter', {{ score }} >= 3, 'Passive', 'Detractor'),
        ifNull({{ scale_type }}, '') = 'definitely_1_4',
            if({{ score }} >= 3, 'Promoter', 'Detractor'),
        ifNull({{ scale_type }}, '') = 'likelihood_0_10',
            multiIf({{ score }} >= 8, 'Promoter', {{ score }} >= 5, 'Passive', 'Detractor'),
        cast(null as Nullable(String)))
{%- endmacro %}

{# Encounter type of a Press Ganey encounter id from its prefix letter: o = OP, e = ER, i = IP (spec P6). #}
{% macro hnh_survey_encounter_type(encounter_id) -%}
multiIf(match(ifNull({{ encounter_id }}, ''), '^o[0-9]+$'), 'OP',
        match(ifNull({{ encounter_id }}, ''), '^e[0-9]+$'), 'ER',
        match(ifNull({{ encounter_id }}, ''), '^i[0-9]+$'), 'IP',
        cast(null as Nullable(String)))
{%- endmacro %}

{# Oasis id in a Press Ganey encounter id (appointment id, ER visit id or admission no); null when malformed. #}
{% macro hnh_survey_source_id(encounter_id) -%}
if(match(ifNull({{ encounter_id }}, ''), '^[oei][0-9]+$'), toInt64OrNull(substring({{ encounter_id }}, 2)), cast(null as Nullable(Int64)))
{%- endmacro %}
