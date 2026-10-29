-- Update of 2026-10-29 (second): Claim Final Rejection Rate (KPI 33) is active. The GL rejection (the monthly
-- rejection provision finance posts: Oasis GL before a hospital's Fusion cutover, Fusion from it) divided by the
-- submitted claim amount (latest submission, by statement month). Fixed target 8%.
-- Needs the model with BSC Claim Final Rejection deployed.
-- Applied with apply_bsc_config.ps1 -Update; insert-only, the latest row per key wins.

INSERT INTO default.map_bsc_kpi (kpi_code, kpi_num, kpi_name, short_label, objective_code, kpi_type, direction, value_format, chart_hint, display_order, definition, status, target_source, value_source, detail_page, changed_at, changed_by, change_note, is_deleted) VALUES
    ('INT_CLAIM_FINAL_REJECTION', 33, 'Claim Final Rejection Rate', 'Claim Final Rejection Rate', 'P3', 'Supporting', 'lower', 'pct', 'bullet', 33, 'Rejection posted in the GL (the monthly rejection provision, revenue settlement discount line rejection) divided by the submitted claim amount, latest submission, by statement month. Oasis GL before a hospital''s Fusion GL cutover, Fusion from it.', 'active', 'fixed', 'measure', 'revenue_cycle', now64(3), 'bsc-2026-10-29', 'final rejection defined from the GL rejection; fixed target 8%', 0);

INSERT INTO default.map_bsc_target (kpi_code, branch_id, year, month, target_value, scale_with_months, source_basis, changed_at, changed_by, change_note, is_deleted) VALUES
    ('INT_CLAIM_FINAL_REJECTION', 0, 2026, 0, 0.08, 0, 'BI manager target', now64(3), 'bsc-2026-10-29', 'Claim Final Rejection Rate target 8%', 0);
