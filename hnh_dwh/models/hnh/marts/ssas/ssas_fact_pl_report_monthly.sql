{{ hnh_ssas_view('fact_pl_report_monthly', drop=['month_start'], decimals=['amount'], extra=['toInt64(toYYYYMMDD(t.month_start)) as month_date_key']) }}
