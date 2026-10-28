-- Update of 2026-10-28 (second): OP-to-IP and Referral Conversion divide by OP and ER episodes (episodes with an
-- arrived encounter that is not a follow-up, by episode start date), not by the census. The OP-to-IP budget target is
-- target IP episodes over target OP and ER episodes. Definitions only; targets unchanged.
-- Applied with apply_bsc_config.ps1 -Update; insert-only, the latest row per key wins.

INSERT INTO default.map_bsc_kpi (kpi_code, kpi_num, kpi_name, short_label, objective_code, kpi_type, direction, value_format, chart_hint, display_order, definition, status, target_source, value_source, detail_page, changed_at, changed_by, change_note, is_deleted) VALUES
    ('INT_OP_TO_IP', 24, 'OP-to-IP Conversion', 'OP-to-IP Conversion', 'P1', 'Supporting', 'higher', 'pct', 'bullet', 24, 'Admissions from OP or ER divided by OP and ER episodes (episodes with an arrived encounter that is not a follow-up); target: budgeted IP episodes over budgeted OP and ER episodes.', 'active', 'budget', 'measure', 'volume', now64(3), 'bsc-2026-10-28', 'divide by episodes, not the census', 0),
    ('CUS_REFERRAL_CONVERSION', 61, 'Referral Conversion Rate', 'Referral Conversion Rate', 'C3', 'Supporting', 'higher', 'pct', 'bullet', 61, 'Admissions from OP or ER under a referral policy divided by OP and ER episodes under a referral policy (episodes with an arrived encounter that is not a follow-up).', 'active', 'fixed', 'measure', 'volume', now64(3), 'bsc-2026-10-28', 'divide by episodes, not the census', 0);
