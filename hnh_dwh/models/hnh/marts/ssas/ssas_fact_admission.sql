{{ hnh_ssas_view('fact_admission', drop=['admission_key', 'encounter_key', 'episode_key', 'admitted_at', 'physical_discharge_at', 'planned_admit_at'], floats=['los_hours', 'los_days', 'los_days_to_date', 'critical_bed_hours'],
    extra=["if(ep.is_referral_policy = 1, 'Yes', 'No') as is_referral_policy"],
    joins='left join (select episode_key, is_referral_policy from ' ~ ref('fact_episode') ~ ') as ep on ep.episode_key = t.episode_key') }}
