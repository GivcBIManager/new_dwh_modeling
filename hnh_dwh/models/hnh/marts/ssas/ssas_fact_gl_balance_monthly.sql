{{ hnh_ssas_view('fact_gl_balance_monthly',
    decimals=['opening_balance', 'period_debit', 'period_credit', 'period_movement', 'period_movement_excl_opening', 'closing_balance'],
    extra=['toInt64(p.end_date_key) as period_end_date_key'],
    joins='inner join ' ~ ref('hnh_dim_gl_period') ~ ' as p on p.period_key = t.period_key') }}
