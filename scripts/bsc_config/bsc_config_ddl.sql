-- Balanced-scorecard configuration tables (bsc ssas spec 6.2). Insert-only change logs: a change is a new row,
-- the latest row per key wins (stg_ref__bsc_*), is_deleted = 1 removes a key. Edited by the BI manager with SQL.
CREATE TABLE IF NOT EXISTS default.map_bsc_kpi
(
    kpi_code String, kpi_num UInt16, kpi_name String, short_label String, objective_code String, kpi_type String,
    direction String, value_format String, chart_hint String, display_order UInt16, definition String,
    status String, target_source String, value_source String, detail_page String,
    changed_at DateTime64(3), changed_by String, change_note String, is_deleted UInt8
) ENGINE = MergeTree ORDER BY (kpi_code, changed_at);

CREATE TABLE IF NOT EXISTS default.map_bsc_objective
(
    objective_code String, pillar String, pillar_order UInt8, pillar_weight Float64, pillar_question String,
    objective_title String, objective_question String, objective_order UInt8,
    changed_at DateTime64(3), changed_by String, change_note String, is_deleted UInt8
) ENGINE = MergeTree ORDER BY (objective_code, changed_at);

CREATE TABLE IF NOT EXISTS default.map_bsc_target
(
    kpi_code String, branch_id UInt8, year UInt16, month UInt8, target_value Float64, scale_with_months UInt8,
    source_basis String,
    changed_at DateTime64(3), changed_by String, change_note String, is_deleted UInt8
) ENGINE = MergeTree ORDER BY (kpi_code, branch_id, year, month, changed_at);

CREATE TABLE IF NOT EXISTS default.map_bsc_weight
(
    profile String, kpi_code String, weight Float64,
    changed_at DateTime64(3), changed_by String, change_note String, is_deleted UInt8
) ENGINE = MergeTree ORDER BY (profile, kpi_code, changed_at);

CREATE TABLE IF NOT EXISTS default.map_bsc_threshold
(
    kpi_code String, score_base Float64, score_slope Float64, good_from Float64, watch_from Float64,
    changed_at DateTime64(3), changed_by String, change_note String, is_deleted UInt8
) ENGINE = MergeTree ORDER BY (kpi_code, changed_at);

CREATE TABLE IF NOT EXISTS default.map_bsc_owner
(
    kpi_code String, branch_id UInt8, owner String, co_owners String,
    changed_at DateTime64(3), changed_by String, change_note String, is_deleted UInt8
) ENGINE = MergeTree ORDER BY (kpi_code, branch_id, changed_at);

CREATE TABLE IF NOT EXISTS default.map_bsc_hospital_category
(
    branch_id UInt8, category String,
    changed_at DateTime64(3), changed_by String, change_note String, is_deleted UInt8
) ENGINE = MergeTree ORDER BY (branch_id, changed_at);

CREATE TABLE IF NOT EXISTS default.map_bsc_manual_value
(
    kpi_code String, branch_id UInt8, year UInt16, month UInt8, numerator Float64, denominator Float64, note String,
    changed_at DateTime64(3), changed_by String, change_note String, is_deleted UInt8
) ENGINE = MergeTree ORDER BY (kpi_code, branch_id, year, month, changed_at);

CREATE TABLE IF NOT EXISTS default.map_bsc_code_list
(
    list_name String, code String,
    changed_at DateTime64(3), changed_by String, change_note String, is_deleted UInt8
) ENGINE = MergeTree ORDER BY (list_name, code, changed_at);

CREATE TABLE IF NOT EXISTS default.map_bsc_budgeted_fte
(
    branch_id UInt8, year UInt16, budgeted_fte Float64,
    changed_at DateTime64(3), changed_by String, change_note String, is_deleted UInt8
) ENGINE = MergeTree ORDER BY (branch_id, year, changed_at);
