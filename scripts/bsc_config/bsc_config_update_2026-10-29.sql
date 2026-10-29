-- Update of 2026-10-29: Net Collection Rate (KPI 7) is active. Credit-patient AR collected from 1 January to the
-- selected month (insurers, government and companies; no cash patients) over the credit AR closing balance at the end
-- of that month, always year to date. Fixed target 90%, not pro-rated by months (the actual is already year to date).
-- Needs the model with BSC Net Collection Rate (fact_bsc_ar_collection_monthly) deployed.
-- Applied with apply_bsc_config.ps1 -Update; insert-only, the latest row per key wins.

INSERT INTO default.map_bsc_kpi (kpi_code, kpi_num, kpi_name, short_label, objective_code, kpi_type, direction, value_format, chart_hint, display_order, definition, status, target_source, value_source, detail_page, changed_at, changed_by, change_note, is_deleted) VALUES
    ('FIN_NET_COLLECTION', 7, 'Net Collection Rate', 'Net Collection Rate', 'F3', 'Supporting', 'higher', 'pct', 'stat', 7, 'Credit-patient AR collected from 1 January to the selected month (receipts of insurers, government and companies; no cash patients) divided by the credit AR closing balance at the end of that month. Always year to date. Oasis AR receipts before a hospital''s Fusion GL cutover, Fusion Receivables receipts from it.', 'active', 'fixed', 'measure', 'revenue_cycle', now64(3), 'bsc-2026-10-29', 'net collection rate defined: YTD collected / closing credit AR; fixed target 90%', 0);

INSERT INTO default.map_bsc_target (kpi_code, branch_id, year, month, target_value, scale_with_months, source_basis, changed_at, changed_by, change_note, is_deleted) VALUES
    ('FIN_NET_COLLECTION', 0, 2026, 0, 0.90, 0, 'BI manager target', now64(3), 'bsc-2026-10-29', 'Net Collection Rate target 90% (year to date)', 0);
