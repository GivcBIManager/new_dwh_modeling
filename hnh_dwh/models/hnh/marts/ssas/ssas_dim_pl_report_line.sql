{{ hnh_ssas_view('dim_pl_report_line', drop=['subtotal_sections', 'pl_line_name'], extra=[
    "multiIf(t.line_kind = 'subtotal', 'subtotal', t.budget_sign != 0, 'linked', 'unlinked') as budget_kind"]) }}
