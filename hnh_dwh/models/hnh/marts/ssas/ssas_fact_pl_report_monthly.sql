{{ hnh_ssas_view('fact_pl_report_monthly', drop=['month_start'], decimals=['amount'], extra=[
    'toInt64(toYYYYMMDD(t.month_start)) as month_date_key',
    hnh_title('toString(t.fs_caption)') ~ ' as fs_caption_name']) }}
