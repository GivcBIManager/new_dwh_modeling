{{ hnh_ssas_view('agg_clinic_capacity_daily', extra=['toFloat64(t.legacy_capacity_slots) as bsc_capacity_slots']) }}
