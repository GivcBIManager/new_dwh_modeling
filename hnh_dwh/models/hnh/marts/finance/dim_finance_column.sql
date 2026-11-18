{{ config(order_by='column_key') }}

-- Columns of the finance report pages (Finance Column table): which columns each page offers in the monthly and the
-- hospital comparison view, in which group and order. kind is what the measures switch on; month_num is 1..12 on the
-- month columns and 0 elsewhere. Labels are repo labels, not title-cased. column_key = page base + 50 per hospital view +
-- column_order, unique per page and view.
-- SSAS sorts Column Name by Column Order and Group Name by Group Order, which needs one order per label; the same label
-- has other orders on other pages ('Budget' is 21 on tb, 14 on is), so each label gets as many zero-width spaces
-- (U+200B, invisible) as its (page, view) pair's index: tb, is, bs, kpi monthly 0..3, hospital 4..7 (ruling R15e).
-- Measures key on kind, month_num, page and view, never on the labels.
select
    toUInt16(multiIf(page = 'tb', 100, page = 'is', 200, page = 'bs', 300, 400) + if(view = 'hospital', 50, 0) + column_order) as column_key,
    page,
    view,
    concat(group_label, repeat(unhex('E2808B'), toUInt8(multiIf(page = 'tb', 0, page = 'is', 1, page = 'bs', 2, 3) + if(view = 'hospital', 4, 0)))) as group_name,
    group_order,
    concat(column_label, repeat(unhex('E2808B'), toUInt8(multiIf(page = 'tb', 0, page = 'is', 1, page = 'bs', 2, 3) + if(view = 'hospital', 4, 0)))) as column_name,
    column_order,
    kind,
    month_num
from values('page String, view String, group_label String, group_order UInt8, column_label String, column_order UInt8, kind String, month_num UInt8',
    ('tb', 'monthly', 'Period', 1, 'Opening', 1, 'opening', 0), ('tb', 'monthly', 'Period', 1, 'Opening journals', 2, 'opening_journal', 0), ('tb', 'monthly', 'Period', 1, 'Debit', 3, 'debit', 0),
    ('tb', 'monthly', 'Period', 1, 'Credit', 4, 'credit', 0), ('tb', 'monthly', 'Period', 1, 'Closing', 5, 'closing', 0), ('tb', 'monthly', 'Period', 1, 'Cutover difference', 6, 'cutover', 0),
    ('tb', 'monthly', 'Net movement by month', 2, 'Jan', 7, 'month', 1), ('tb', 'monthly', 'Net movement by month', 2, 'Feb', 8, 'month', 2), ('tb', 'monthly', 'Net movement by month', 2, 'Mar', 9, 'month', 3),
    ('tb', 'monthly', 'Net movement by month', 2, 'Apr', 10, 'month', 4), ('tb', 'monthly', 'Net movement by month', 2, 'May', 11, 'month', 5), ('tb', 'monthly', 'Net movement by month', 2, 'Jun', 12, 'month', 6),
    ('tb', 'monthly', 'Net movement by month', 2, 'Jul', 13, 'month', 7), ('tb', 'monthly', 'Net movement by month', 2, 'Aug', 14, 'month', 8), ('tb', 'monthly', 'Net movement by month', 2, 'Sep', 15, 'month', 9),
    ('tb', 'monthly', 'Net movement by month', 2, 'Oct', 16, 'month', 10), ('tb', 'monthly', 'Net movement by month', 2, 'Nov', 17, 'month', 11), ('tb', 'monthly', 'Net movement by month', 2, 'Dec', 18, 'month', 12),
    ('tb', 'monthly', 'Closing vs last year and budget', 3, 'Last year', 19, 'ly', 0), ('tb', 'monthly', 'Closing vs last year and budget', 3, 'Growth', 20, 'growth', 0), ('tb', 'monthly', 'Closing vs last year and budget', 3, 'Budget', 21, 'budget', 0),
    ('tb', 'monthly', 'Closing vs last year and budget', 3, 'vs Bud', 22, 'vs_bud', 0), ('is', 'monthly', 'Actual by month', 1, 'Jan', 1, 'month', 1), ('is', 'monthly', 'Actual by month', 1, 'Feb', 2, 'month', 2),
    ('is', 'monthly', 'Actual by month', 1, 'Mar', 3, 'month', 3), ('is', 'monthly', 'Actual by month', 1, 'Apr', 4, 'month', 4), ('is', 'monthly', 'Actual by month', 1, 'May', 5, 'month', 5),
    ('is', 'monthly', 'Actual by month', 1, 'Jun', 6, 'month', 6), ('is', 'monthly', 'Actual by month', 1, 'Jul', 7, 'month', 7), ('is', 'monthly', 'Actual by month', 1, 'Aug', 8, 'month', 8),
    ('is', 'monthly', 'Actual by month', 1, 'Sep', 9, 'month', 9), ('is', 'monthly', 'Actual by month', 1, 'Oct', 10, 'month', 10), ('is', 'monthly', 'Actual by month', 1, 'Nov', 11, 'month', 11),
    ('is', 'monthly', 'Actual by month', 1, 'Dec', 12, 'month', 12), ('is', 'monthly', 'Period total', 2, 'Actual', 13, 'actual', 0), ('is', 'monthly', 'Period total', 2, 'Budget', 14, 'budget', 0),
    ('is', 'monthly', 'Period total', 2, 'Variance', 15, 'variance', 0), ('is', 'monthly', 'Period total', 2, 'Var %', 16, 'var_pct', 0), ('is', 'monthly', 'Period total', 2, 'Last year', 17, 'ly', 0),
    ('is', 'monthly', 'Period total', 2, 'Growth', 18, 'growth', 0), ('is', 'monthly', 'Period total', 2, '% Rev', 19, 'pct_rev', 0), ('bs', 'monthly', 'Month-end balance', 1, 'Jan', 1, 'month', 1),
    ('bs', 'monthly', 'Month-end balance', 1, 'Feb', 2, 'month', 2), ('bs', 'monthly', 'Month-end balance', 1, 'Mar', 3, 'month', 3), ('bs', 'monthly', 'Month-end balance', 1, 'Apr', 4, 'month', 4),
    ('bs', 'monthly', 'Month-end balance', 1, 'May', 5, 'month', 5), ('bs', 'monthly', 'Month-end balance', 1, 'Jun', 6, 'month', 6), ('bs', 'monthly', 'Month-end balance', 1, 'Jul', 7, 'month', 7),
    ('bs', 'monthly', 'Month-end balance', 1, 'Aug', 8, 'month', 8), ('bs', 'monthly', 'Month-end balance', 1, 'Sep', 9, 'month', 9), ('bs', 'monthly', 'Month-end balance', 1, 'Oct', 10, 'month', 10),
    ('bs', 'monthly', 'Month-end balance', 1, 'Nov', 11, 'month', 11), ('bs', 'monthly', 'Month-end balance', 1, 'Dec', 12, 'month', 12), ('bs', 'monthly', 'End of period vs last year and budget', 2, 'Last year', 13, 'ly', 0),
    ('bs', 'monthly', 'End of period vs last year and budget', 2, 'Growth', 14, 'growth', 0), ('bs', 'monthly', 'End of period vs last year and budget', 2, 'Budget', 15, 'budget', 0), ('bs', 'monthly', 'End of period vs last year and budget', 2, 'vs Bud', 16, 'vs_bud', 0),
    ('bs', 'monthly', 'End of period vs last year and budget', 2, '% Assets', 17, 'pct_assets', 0), ('kpi', 'monthly', 'Period', 1, 'Target', 1, 'target', 0), ('kpi', 'monthly', 'Period', 1, 'Actual', 2, 'actual', 0),
    ('kpi', 'monthly', 'Period', 1, 'Status', 3, 'status', 0), ('kpi', 'monthly', 'Period', 1, 'Budget', 4, 'budget', 0), ('kpi', 'monthly', 'Period', 1, 'vs Bud', 5, 'vs_bud', 0),
    ('kpi', 'monthly', 'Period', 1, 'Last year', 6, 'ly', 0), ('kpi', 'monthly', 'Period', 1, 'vs LY', 7, 'vs_ly', 0), ('kpi', 'monthly', 'Actual by month', 2, 'Jan', 8, 'month', 1),
    ('kpi', 'monthly', 'Actual by month', 2, 'Feb', 9, 'month', 2), ('kpi', 'monthly', 'Actual by month', 2, 'Mar', 10, 'month', 3), ('kpi', 'monthly', 'Actual by month', 2, 'Apr', 11, 'month', 4),
    ('kpi', 'monthly', 'Actual by month', 2, 'May', 12, 'month', 5), ('kpi', 'monthly', 'Actual by month', 2, 'Jun', 13, 'month', 6), ('kpi', 'monthly', 'Actual by month', 2, 'Jul', 14, 'month', 7),
    ('kpi', 'monthly', 'Actual by month', 2, 'Aug', 15, 'month', 8), ('kpi', 'monthly', 'Actual by month', 2, 'Sep', 16, 'month', 9), ('kpi', 'monthly', 'Actual by month', 2, 'Oct', 17, 'month', 10),
    ('kpi', 'monthly', 'Actual by month', 2, 'Nov', 18, 'month', 11), ('kpi', 'monthly', 'Actual by month', 2, 'Dec', 19, 'month', 12), ('tb', 'hospital', '', 1, 'Closing', 1, 'closing', 0),
    ('tb', 'hospital', '', 1, 'Ach %', 2, 'ach', 0), ('tb', 'hospital', '', 1, 'Growth', 3, 'growth', 0), ('bs', 'hospital', '', 1, 'Closing', 1, 'closing', 0),
    ('bs', 'hospital', '', 1, 'Ach %', 2, 'ach', 0), ('bs', 'hospital', '', 1, 'Growth', 3, 'growth', 0), ('is', 'hospital', '', 1, 'Actual', 1, 'actual', 0),
    ('is', 'hospital', '', 1, 'Ach %', 2, 'ach', 0), ('is', 'hospital', '', 1, 'Growth', 3, 'growth', 0), ('kpi', 'hospital', '', 1, 'Actual', 1, 'actual', 0),
    ('kpi', 'hospital', '', 1, 'vs Bud', 2, 'vs_bud', 0), ('kpi', 'hospital', '', 1, 'vs LY', 3, 'vs_ly', 0)
)
{{ hnh_settings() }}
