{{ hnh_ssas_view('fact_gl_fs_monthly', drop=['month_start'], decimals=['opening_balance', 'movement', 'opening_journal_amount', 'closing_balance', 'debit', 'credit'], extra=[
    'toInt64(toYYYYMMDD(t.month_start)) as month_date_key',
    hnh_fs_type_label('t.fs_type') ~ ' as fs_type_name',
    hnh_title('toString(t.fs_element)') ~ ' as fs_element_name',
    hnh_title('toString(t.fs_category)') ~ ' as fs_category_name',
    hnh_title('toString(t.fs_caption)') ~ ' as fs_caption_name',
    hnh_bs_side('t.fs_type', 't.fs_element', 't.fs_category') ~ ' as bs_side',
    hnh_bs_element('t.fs_type', 't.fs_element', 't.fs_category') ~ ' as bs_element',
    hnh_bs_category('t.fs_type', 't.fs_element', 't.fs_category') ~ ' as bs_category',
    hnh_bs_caption('t.fs_type', 't.fs_element', 't.fs_category', 't.fs_caption') ~ ' as bs_caption',
    hnh_bs_display_sign('t.fs_type', 't.fs_element', 't.fs_category') ~ ' as display_sign',
    hnh_bs_element_order('t.fs_type', 't.fs_element', 't.fs_category') ~ ' as bs_element_order',
    hnh_bs_category_order('t.fs_type', 't.fs_element', 't.fs_category') ~ ' as bs_category_order']) }}
