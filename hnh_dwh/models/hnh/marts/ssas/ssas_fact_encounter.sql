{{ hnh_ssas_view('fact_encounter', drop=['encounter_key', 'episode_key', 'wait_minutes_raw', 'door_to_triage_minutes_raw', 'service_minutes_raw', 'er_los_minutes_raw'],
    extra=["if(ep.is_referral_policy = 1, 'Yes', 'No') as is_referral_policy"],
    joins='left join (select episode_key, is_referral_policy from ' ~ ref('fact_episode') ~ ') as ep on ep.episode_key = t.episode_key') }}
