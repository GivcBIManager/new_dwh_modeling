-- HR dashboard configuration tables (docs/superpowers/specs/2026-11-02-hr-dashboard-design.md). Insert-only change logs
-- like the map_bsc_* tables: a change is a new row, the latest row per key wins, is_deleted = 1 removes a key.
-- Edited by the BI manager with SQL: see docs/hr_config.md.
CREATE TABLE IF NOT EXISTS default.map_hr_kpi
(
    kpi_code String, kind String, kpi_name String, short_label String, area String, definition String, formula String,
    source_system String, grain String, caveats String, direction String, value_format String, display_order UInt16,
    measure_name String, bsc_kpi_code String, target_source String, needs_pay UInt8, is_home_tile UInt8, status String,
    changed_at DateTime64(3), changed_by String, change_note String, is_deleted UInt8
) ENGINE = MergeTree ORDER BY (kpi_code, changed_at);

CREATE TABLE IF NOT EXISTS default.map_hr_target
(
    kpi_code String, branch_id UInt8, year UInt16, month UInt8, target_value Float64, watch_value Float64,
    scale_with_months UInt8, source_basis String,
    changed_at DateTime64(3), changed_by String, change_note String, is_deleted UInt8
) ENGINE = MergeTree ORDER BY (kpi_code, branch_id, year, month, changed_at);

CREATE TABLE IF NOT EXISTS default.map_hr_dq_issue
(
    issue_code String, issue_name String, area String, fix_in String, owner String, severity String, how_to_fix String,
    display_order UInt16, status String,
    changed_at DateTime64(3), changed_by String, change_note String, is_deleted UInt8
) ENGINE = MergeTree ORDER BY (issue_code, changed_at);
