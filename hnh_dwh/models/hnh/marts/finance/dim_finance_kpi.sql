{{ config(order_by='kpi_code') }}

-- The 27 finance report KPIs (Finance KPI table), in report order. unit: '%' ratio shown as a percentage, 'x' times,
-- 'd' days. direction: 1 higher is better, -1 lower is better (the status rule reads it). card_code F1..F6 marks the
-- six cards of the Summary page, '' for no card. Names and groups are repo labels, not title-cased.
select
    kpi_code,
    kpi_group,
    group_order,
    kpi_name,
    unit,
    direction,
    display_order,
    card_code
from values('kpi_code String, kpi_group String, group_order UInt8, kpi_name String, unit String, direction Int8, display_order UInt8, card_code String',
    ('FR_REV_GROWTH', 'Growth & budget achievement', 1, 'Net revenue growth', '%', 1, 1, 'F1'),
    ('FR_REV_VS_BUD', 'Growth & budget achievement', 1, 'Net revenue vs budget', '%', 1, 2, ''),
    ('FR_NP_GROWTH', 'Growth & budget achievement', 1, 'Net profit growth', '%', 1, 3, ''),
    ('FR_NP_VS_BUD', 'Growth & budget achievement', 1, 'Net profit vs budget', '%', 1, 4, 'F3'),
    ('FR_GP_MARGIN', 'Profitability', 2, 'Gross profit margin', '%', 1, 5, ''),
    ('FR_EBITDA_MARGIN', 'Profitability', 2, 'EBITDA margin', '%', 1, 6, 'F2'),
    ('FR_OP_MARGIN', 'Profitability', 2, 'Operating margin', '%', 1, 7, ''),
    ('FR_NP_MARGIN', 'Profitability', 2, 'Net profit margin', '%', 1, 8, ''),
    ('FR_ROA', 'Profitability', 2, 'Return on assets', '%', 1, 9, ''),
    ('FR_ROE', 'Profitability', 2, 'Return on equity', '%', 1, 10, ''),
    ('FR_CURRENT_RATIO', 'Liquidity', 3, 'Current ratio', 'x', 1, 11, ''),
    ('FR_QUICK_RATIO', 'Liquidity', 3, 'Quick ratio', 'x', 1, 12, ''),
    ('FR_CASH_RATIO', 'Liquidity', 3, 'Cash ratio', 'x', 1, 13, ''),
    ('FR_AR_DAYS', 'Efficiency & working capital', 4, 'Receivable days', 'd', -1, 14, 'F4'),
    ('FR_INV_DAYS', 'Efficiency & working capital', 4, 'Inventory days', 'd', -1, 15, ''),
    ('FR_AP_DAYS', 'Efficiency & working capital', 4, 'Payable days', 'd', 1, 16, ''),
    ('FR_CCC', 'Efficiency & working capital', 4, 'Cash conversion cycle', 'd', -1, 17, ''),
    ('FR_ASSET_TURNOVER', 'Efficiency & working capital', 4, 'Asset turnover', 'x', 1, 18, ''),
    ('FR_DEBT_EQUITY', 'Leverage & solvency', 5, 'Debt to equity', 'x', -1, 19, ''),
    ('FR_NET_DEBT_EBITDA', 'Leverage & solvency', 5, 'Net debt to EBITDA', 'x', -1, 20, ''),
    ('FR_INTEREST_COVER', 'Leverage & solvency', 5, 'Interest cover', 'x', 1, 21, ''),
    ('FR_EQUITY_RATIO', 'Leverage & solvency', 5, 'Equity ratio', '%', 1, 22, ''),
    ('FR_COST_TO_REV', 'Cost structure & revenue cycle', 6, 'Cost of revenue ratio', '%', -1, 23, 'F6'),
    ('FR_STAFF_COST_RATIO', 'Cost structure & revenue cycle', 6, 'Staff cost ratio', '%', -1, 24, ''),
    ('FR_MED_MATERIALS_RATIO', 'Cost structure & revenue cycle', 6, 'Medical materials ratio', '%', -1, 25, ''),
    ('FR_REJECTION_RATE', 'Cost structure & revenue cycle', 6, 'Claim rejection rate', '%', -1, 26, 'F5'),
    ('FR_ECL_RATIO', 'Cost structure & revenue cycle', 6, 'Credit loss charge', '%', -1, 27, '')
)
{{ hnh_settings() }}
