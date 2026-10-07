{{ hnh_ssas_view('fact_survey_response', drop=['surveycode', 'encounter_key', 'episode_key', 'encounter_id'], floats=['nps_score', 'physician_nps_score']) }}
