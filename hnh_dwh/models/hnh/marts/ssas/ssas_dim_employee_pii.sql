-- The birth date goes to SSAS as a yyyymmdd number: the view's Date (1970 to 2149) would wrap the 38 employees born
-- before 1970 into the 2140s (2026-11-19); the HR measures turn the key back into a date.
{{ hnh_ssas_view('dim_employee_pii', drop=['birth_date'], extra=['if(t.birth_date is null, cast(null as Nullable(Int64)), toInt64(toYYYYMMDD(assumeNotNull(t.birth_date)))) as birth_date_key']) }}
