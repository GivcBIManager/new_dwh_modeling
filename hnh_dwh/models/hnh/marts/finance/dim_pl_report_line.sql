{{ config(order_by='pl_line_key') }}

-- Report lines of the Fusion "HNH profitability Report" (P&L), in report order. line_kind: detail lines take amounts
-- through pl_report_line_rule; not_mapped lines catch labels the rules do not know; a subtotal adds the sections it lists
-- in subtotal_sections. is_in_fusion_report = 0 for lines the Fusion report does not show.
-- pl_line_name keeps the exact Fusion wording; pl_line_label is unique (a repeated name gets its section, except a line
-- named like its own section) so the cube can sort it by pl_line_key; section_key puts the sections in report order.
select
    toUInt16(pl_line_key)                                   as pl_line_key,
    pl_line_code,
    pl_line_name,
    if(count() over (partition by pl_line_name) = 1 or pl_line_name = section_name,
       pl_line_name, concat(pl_line_name, ' - ', section_name)) as pl_line_label,
    section_name,
    toUInt16(min(pl_line_key) over (partition by section_name)) as section_key,
    toLowCardinality(line_kind)                             as line_kind,
    subtotal_sections,
    toUInt8(is_in_fusion_report)                            as is_in_fusion_report,
    budget_line_code,
    toInt8(budget_sign)                                     as budget_sign
from values('pl_line_key UInt16, pl_line_code String, pl_line_name String, section_name String, line_kind String, subtotal_sections Array(String), is_in_fusion_report UInt8, budget_line_code String, budget_sign Int8',
    (100, 'REV_CASH', 'Revenue Cash', 'Revenue', 'detail', [], 1, '', 0), (110, 'REV_CREDIT', 'Revenue Credit', 'Revenue', 'detail', [], 1, '', 0),
    (190, 'REV_NM', 'Not mapped', 'Revenue', 'not_mapped', [], 0, '', 0), (199, 'REV_TOTAL', 'Revenue Total', 'Revenue', 'subtotal', ['Revenue'], 1, '', 0),
    (200, 'DIS_CASH', 'Cash Discount', 'Revenue - Contractual Discounts', 'detail', [], 1, '', 0), (210, 'DIS_CREDIT', 'Credit Discount', 'Revenue - Contractual Discounts', 'detail', [], 1, '', 0),
    (220, 'DIS_PACKAGE', 'Package Discount', 'Revenue - Contractual Discounts', 'detail', [], 1, '', 0), (290, 'DIS_CONTRACTUAL_NM', 'Not mapped', 'Revenue - Contractual Discounts', 'not_mapped', [], 0, '', 0),
    (299, 'DIS_CONTRACTUAL', 'Revenue - Contractual Discounts', 'Revenue - Contractual Discounts', 'subtotal', ['Revenue - Contractual Discounts'], 1, '', 0), (300, 'DIS_REJECTION', 'Rejection', 'Revenue - Settlement Discount', 'detail', [], 1, 'DIS_REJECTION', -1),
    (310, 'DIS_VOLUME', 'Volume Discount', 'Revenue - Settlement Discount', 'detail', [], 1, 'DIS_VOLUME', -1), (320, 'DIS_EARLY_PAYMENT', 'Early Payment Discount', 'Revenue - Settlement Discount', 'detail', [], 1, 'DIS_EARLY_PAY', -1),
    (330, 'DIS_UNCLAIMED', 'Unclaimed Discount', 'Revenue - Settlement Discount', 'detail', [], 0, '', 0), (340, 'DIS_PATIENT_REFERRAL', 'Patient Referral Discount', 'Revenue - Settlement Discount', 'detail', [], 0, '', 0),
    (390, 'DIS_SETTLEMENT_NM', 'Not mapped', 'Revenue - Settlement Discount', 'not_mapped', [], 0, '', 0), (399, 'DIS_SETTLEMENT', 'Revenue - Settlement Discount', 'Revenue - Settlement Discount', 'subtotal', ['Revenue - Settlement Discount'], 1, 'DIS_SETTLEMENT', -1),
    (499, 'NET_REVENUE', 'Net Revenue', 'Net Revenue', 'subtotal', ['Revenue', 'Revenue - Contractual Discounts', 'Revenue - Settlement Discount'], 1, 'REV_NET', 1), (500, 'DC_CONSUMABLES', 'Consumables', 'Direct Cost', 'detail', [], 1, 'DC_CONSUMABLES', -1),
    (505, 'DC_MEDICINES', 'Cost of Medicines', 'Direct Cost', 'detail', [], 1, 'DC_MEDICINES', -1), (510, 'DC_DOCTORS_FEE', 'Doctors Fee and Commission', 'Direct Cost', 'detail', [], 1, 'DC_DOCTORS_FEE', -1),
    (515, 'DC_EMPLOYEE', 'Employee Costs', 'Direct Cost', 'detail', [], 1, 'DC_EMPLOYEE', -1), (520, 'DC_GOVT_FEES', 'Employee Govt Fees', 'Direct Cost', 'detail', [], 1, 'DC_GOVT_FEES', -1),
    (525, 'DC_INSURANCE', 'Insurance Expenses', 'Direct Cost', 'detail', [], 1, 'DC_INSURANCE', -1), (530, 'DC_KITCHEN', 'Kitchen Expenses', 'Direct Cost', 'detail', [], 1, 'DC_KITCHEN', -1),
    (535, 'DC_MAINTENANCE', 'Maintenance Expense', 'Direct Cost', 'detail', [], 1, 'DC_MAINTENANCE', -1), (540, 'DC_OTHER', 'Other Direct expenses', 'Direct Cost', 'detail', [], 1, 'DC_OTHER', -1),
    (545, 'DC_REFERRAL', 'Referral Cost', 'Direct Cost', 'detail', [], 1, 'DC_REFERRAL', -1), (550, 'DC_RENTAL', 'Rental Cost', 'Direct Cost', 'detail', [], 1, 'DC_RENTAL', -1),
    (555, 'DC_TRAINING', 'Staff training and recruitments', 'Direct Cost', 'detail', [], 1, 'DC_TRAINING', -1), (560, 'DC_TRAVEL', 'Travelling Expenses', 'Direct Cost', 'detail', [], 1, 'DC_TRAVEL', -1),
    (565, 'DC_UTILITIES', 'Utilities', 'Direct Cost', 'detail', [], 1, 'DC_UTILITIES', -1), (590, 'DC_NM', 'Not mapped', 'Direct Cost', 'not_mapped', [], 0, '', 0),
    (599, 'DIRECT_COST', 'Direct Cost', 'Direct Cost', 'subtotal', ['Direct Cost'], 1, 'TOTAL_DC', -1), (699, 'GROSS_PROFIT', 'Gross Profit', 'Gross Profit', 'subtotal', ['Revenue', 'Revenue - Contractual Discounts', 'Revenue - Settlement Discount', 'Direct Cost'], 1, 'GROSS_PROFIT', 1),
    (700, 'GA_GOVT_FEE', 'Government Fee', 'General and administrative expenses', 'detail', [], 1, 'GA_GOVT_FEE', -1), (705, 'GA_AUDIT', 'Audit Fees', 'General and administrative expenses', 'detail', [], 1, 'GA_AUDIT', -1),
    (710, 'GA_BOARD', 'Board Of Directors Expenses', 'General and administrative expenses', 'detail', [], 1, '', 0), (715, 'GA_COMMUNICATION', 'Communication Expense', 'General and administrative expenses', 'detail', [], 1, 'GA_COMMUNICATION', -1),
    (720, 'GA_MGMT_REWARD', 'Corporate Management Reward', 'General and administrative expenses', 'detail', [], 1, '', 0), (725, 'GA_ECL', 'Expected credit loss', 'General and administrative expenses', 'detail', [], 1, 'GA_ECL', -1),
    (730, 'GA_OTHER', 'Other indirect Expenses', 'General and administrative expenses', 'detail', [], 1, 'GA_OTHER', -1), (735, 'GA_POSTAGE', 'Postage printing and stationary', 'General and administrative expenses', 'detail', [], 1, 'GA_POSTAGE', -1),
    (740, 'GA_PROFESSIONAL', 'Professional Fee and subscription', 'General and administrative expenses', 'detail', [], 1, 'GA_PROFESSIONAL', -1), (745, 'GA_SECURITY', 'Security and cleaning Expenses', 'General and administrative expenses', 'detail', [], 1, 'GA_SECURITY', -1),
    (750, 'GA_TRAINING', 'Staff training and recruitment', 'General and administrative expenses', 'detail', [], 1, 'GA_TRAINING', -1), (755, 'GA_EMPLOYEE', 'Employee Cost', 'General and administrative expenses', 'detail', [], 1, 'GA_EMPLOYEE', -1),
    (760, 'GA_MAINTENANCE', 'Maintenance Expense', 'General and administrative expenses', 'detail', [], 0, '', 0), (765, 'GA_UTILITIES', 'Utilities Expenses', 'General and administrative expenses', 'detail', [], 0, '', 0),
    (770, 'GA_TRAVEL', 'Travelling Expenses', 'General and administrative expenses', 'detail', [], 0, '', 0), (775, 'GA_INSURANCE', 'Insurance Expenses', 'General and administrative expenses', 'detail', [], 0, '', 0),
    (780, 'GA_KITCHEN', 'Kitchen Expenses', 'General and administrative expenses', 'detail', [], 0, '', 0), (790, 'GA_NM', 'Not mapped', 'General and administrative expenses', 'not_mapped', [], 0, '', 0),
    (799, 'GA_TOTAL', 'General and administrative expenses', 'General and administrative expenses', 'subtotal', ['General and administrative expenses'], 1, 'TOTAL_GA', -1), (800, 'SM', 'Selling and Marketing expenses', 'Selling and Marketing expenses', 'detail', [], 1, 'GA_MARKETING', -1),
    (810, 'HO_CHARGES', 'Charges from head office', 'Charges from head office', 'detail', [], 1, 'GA_HO_CHARGES', -1), (820, 'OTHER_INCOME', 'Other Income', 'Other Income', 'detail', [], 1, 'OTHER_INCOME', 1),
    (830, 'NOT_MAPPED', 'Not mapped', 'Not mapped', 'not_mapped', [], 0, '', 0), (899, 'EBITDA', 'EBITDA', 'EBITDA', 'subtotal', ['Revenue', 'Revenue - Contractual Discounts', 'Revenue - Settlement Discount', 'Direct Cost', 'General and administrative expenses', 'Selling and Marketing expenses', 'Charges from head office', 'Other Income', 'Not mapped'], 1, 'EBITDA', 1),
    (900, 'FINANCE_COST', 'Finance Cost', 'Finance Cost', 'detail', [], 1, 'FINANCE_COST', -1), (910, 'DEPRECIATION', 'Depreciation and Amortization', 'Depreciation and Amortization', 'detail', [], 1, 'DEPRECIATION', -1),
    (920, 'ZAKAT', 'Zakat', 'Zakat', 'detail', [], 1, 'ZAKAT', -1), (999, 'NET_PROFIT', 'Net Profit / (Loss)', 'Net Profit / (Loss)', 'subtotal', ['Revenue', 'Revenue - Contractual Discounts', 'Revenue - Settlement Discount', 'Direct Cost', 'General and administrative expenses', 'Selling and Marketing expenses', 'Charges from head office', 'Other Income', 'Not mapped', 'Finance Cost', 'Depreciation and Amortization', 'Zakat'], 1, 'NET_PROFIT', 1),
    (1000, 'OCI', 'OCI', 'OCI', 'detail', [], 1, 'OCI', 1), (1099, 'TOTAL_COMPREHENSIVE_INCOME', 'Total Comprehensive Income', 'Total Comprehensive Income', 'subtotal', ['Revenue', 'Revenue - Contractual Discounts', 'Revenue - Settlement Discount', 'Direct Cost', 'General and administrative expenses', 'Selling and Marketing expenses', 'Charges from head office', 'Other Income', 'Not mapped', 'Finance Cost', 'Depreciation and Amortization', 'Zakat', 'OCI'], 1, 'TOTAL_COMP_INCOME', 1)
)
{{ hnh_settings() }}
