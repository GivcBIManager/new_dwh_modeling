-- Finance report configuration tables (docs/superpowers/specs/2026-11-18-finance-report-design.md). Insert-only change
-- logs like the map_hr_* tables: a change is a new row, the latest row per key wins, is_deleted = 1 removes a key.
-- Edited by the BI manager with SQL: see docs/finance_config.md.
CREATE TABLE IF NOT EXISTS default.map_finance_budget
(
    branch_id UInt8, year UInt16, month UInt8, statement String, line_code String, amount Float64,
    changed_at DateTime64(3), changed_by String, change_note String, is_deleted UInt8
) ENGINE = MergeTree ORDER BY (branch_id, year, month, statement, line_code, changed_at);

CREATE TABLE IF NOT EXISTS default.map_finance_target
(
    kpi_code String, branch_id UInt8, year UInt16, target_value Float64, watch_pct Float64,
    changed_at DateTime64(3), changed_by String, change_note String, is_deleted UInt8
) ENGINE = MergeTree ORDER BY (kpi_code, branch_id, year, changed_at);
