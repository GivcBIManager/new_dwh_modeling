{{ hnh_ssas_view('fact_bed_occupancy_daily', drop=['patient_key', 'admission_key'], int_flags=['is_available', 'is_occupied']) }}
