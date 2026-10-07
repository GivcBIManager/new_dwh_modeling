{{ hnh_ssas_view('fact_survey_answer', drop=['surveycode', 'question_code', 'encounter_key'], floats=['answer_score'], int_flags=['is_promoter', 'is_passive', 'is_detractor']) }}
