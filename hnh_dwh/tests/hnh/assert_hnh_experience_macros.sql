{% set null_s = "cast(null as Nullable(String))" %}
{% set null_f = "cast(null as Nullable(Float64))" %}

select 'band 1-5 wrong' as failure
where not ({{ hnh_survey_band("'rating_1_5'", 'toFloat64(5)') }} = 'Promoter' and {{ hnh_survey_band("'rating_1_5'", 'toFloat64(4)') }} = 'Promoter'
       and {{ hnh_survey_band("'rating_1_5'", 'toFloat64(3)') }} = 'Passive' and {{ hnh_survey_band("'rating_1_5'", 'toFloat64(2)') }} = 'Detractor'
       and {{ hnh_survey_band("'rating_1_5'", 'toFloat64(1)') }} = 'Detractor' and {{ hnh_survey_band("'agree_1_5'", 'toFloat64(4)') }} = 'Promoter'
       and {{ hnh_survey_band("'agree_1_5'", 'toFloat64(3)') }} = 'Passive' and {{ hnh_survey_band("'agree_1_5'", 'toFloat64(2)') }} = 'Detractor')

union all
select 'band 1-4 wrong'
where not ({{ hnh_survey_band("'definitely_1_4'", 'toFloat64(4)') }} = 'Promoter' and {{ hnh_survey_band("'definitely_1_4'", 'toFloat64(3)') }} = 'Promoter'
       and {{ hnh_survey_band("'definitely_1_4'", 'toFloat64(2)') }} = 'Detractor' and {{ hnh_survey_band("'definitely_1_4'", 'toFloat64(1)') }} = 'Detractor')

union all
select 'band 0-10 wrong'
where not ({{ hnh_survey_band("'likelihood_0_10'", 'toFloat64(10)') }} = 'Promoter' and {{ hnh_survey_band("'likelihood_0_10'", 'toFloat64(8)') }} = 'Promoter'
       and {{ hnh_survey_band("'likelihood_0_10'", 'toFloat64(7)') }} = 'Passive' and {{ hnh_survey_band("'likelihood_0_10'", 'toFloat64(5)') }} = 'Passive'
       and {{ hnh_survey_band("'likelihood_0_10'", 'toFloat64(4)') }} = 'Detractor' and {{ hnh_survey_band("'likelihood_0_10'", 'toFloat64(0)') }} = 'Detractor')

union all
select 'band null handling wrong'
where not ({{ hnh_survey_band("'rating_1_5'", null_f) }} is null and {{ hnh_survey_band("'categorical'", 'toFloat64(1)') }} is null
       and {{ hnh_survey_band(null_s, 'toFloat64(5)') }} is null)

union all
select 'encounter type wrong'
where not ({{ hnh_survey_encounter_type("'o135025664'") }} = 'OP' and {{ hnh_survey_encounter_type("'e162062201'") }} = 'ER'
       and {{ hnh_survey_encounter_type("'i183761712'") }} = 'IP' and {{ hnh_survey_encounter_type("'x12'") }} is null
       and {{ hnh_survey_encounter_type("'o'") }} is null and {{ hnh_survey_encounter_type("'o12a'") }} is null
       and {{ hnh_survey_encounter_type(null_s) }} is null)

union all
select 'source id wrong'
where not ({{ hnh_survey_source_id("'o135025664'") }} = 135025664 and {{ hnh_survey_source_id("'i7'") }} = 7
       and {{ hnh_survey_source_id("'x12'") }} is null and {{ hnh_survey_source_id("'e'") }} is null
       and {{ hnh_survey_source_id(null_s) }} is null)
