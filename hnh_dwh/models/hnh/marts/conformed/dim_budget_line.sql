{{ config(order_by='budget_line_key') }}

-- The 48 codes of default.income_statement_budget plus REV_UNALLOCATED and UNBUDGETED (spec 5.5).
select
    {{ hnh_surrogate_key(['code']) }}            as budget_line_key,
    code                                         as budget_line_code,
    name                                         as budget_line_name,
    toUInt16(sort_order)                         as sort_order,
    toUInt8(is_subtotal)                         as is_subtotal,
    {{ hnh_budget_natural_side('code', "''") }}  as natural_side
from values('code String, name String, sort_order UInt16, is_subtotal UInt8',
    ('REV_OP', 'Revenue - outpatient', 10, 0), ('REV_IP', 'Revenue - inpatient', 20, 0), ('REV_ER', 'Revenue - emergency', 30, 0),
    ('REV_UNALLOCATED', 'Revenue - unallocated', 40, 0), ('REV_SUB', 'Gross revenue', 50, 1),
    ('DIS_REJECTION_INS', 'Rejections - insurance', 60, 0), ('DIS_REJECTION_MOH', 'Rejections - MOH', 70, 0),
    ('DIS_REJECTION', 'Rejections', 80, 1), ('DIS_EARLY_PAY', 'Early payment discount', 90, 0),
    ('DIS_VOLUME', 'Volume discount', 100, 0), ('DIS_SETTLEMENT', 'Settlement discounts', 110, 1), ('REV_NET', 'Net revenue', 120, 1),
    ('DC_EMPLOYEE', 'Employee costs', 130, 0), ('DC_DOCTORS_FEE', 'Doctors fee and commission', 140, 0),
    ('DC_MEDICINES', 'Cost of medicines', 150, 0), ('DC_CONSUMABLES', 'Consumables', 160, 0),
    ('DC_GOVT_FEES', 'Employee government fees', 170, 0), ('DC_INSURANCE', 'Insurance', 180, 0),
    ('DC_MAINTENANCE', 'Maintenance', 190, 0), ('DC_UTILITIES', 'Utilities', 200, 0), ('DC_RENTAL', 'Rental', 210, 0),
    ('DC_REFERRAL', 'Referral cost', 220, 0), ('DC_KITCHEN', 'Kitchen', 230, 0), ('DC_TRAVEL', 'Travel and transport', 240, 0),
    ('DC_TRAINING', 'Training and recruitment', 250, 0), ('DC_OTHER', 'Other direct expenses', 260, 0),
    ('TOTAL_DC', 'Total direct cost', 270, 1), ('GROSS_PROFIT', 'Gross profit', 280, 1),
    ('GA_EMPLOYEE', 'G&A employee cost', 290, 0), ('GA_PROFESSIONAL', 'Professional fees and subscriptions', 300, 0),
    ('GA_AUDIT', 'Audit fee', 310, 0), ('GA_COMMUNICATION', 'Communication', 320, 0), ('GA_POSTAGE', 'Postage and stationery', 330, 0),
    ('GA_SECURITY', 'Security and cleaning', 340, 0), ('GA_GOVT_FEE', 'Government fees', 350, 0),
    ('GA_TRAINING', 'G&A training and recruitment', 360, 0), ('GA_ECL', 'Expected credit loss', 370, 0),
    ('GA_MARKETING', 'Selling and marketing', 380, 0), ('GA_HO_CHARGES', 'Head office charges', 390, 0),
    ('GA_OTHER', 'Other indirect expenses', 400, 0), ('TOTAL_GA', 'Total G&A', 410, 1), ('OTHER_INCOME', 'Other income', 420, 0),
    ('EBITDA', 'EBITDA', 430, 1), ('DEPRECIATION', 'Depreciation and amortisation', 440, 0), ('FINANCE_COST', 'Finance cost', 450, 0),
    ('ZAKAT', 'Zakat', 460, 0), ('NET_PROFIT', 'Net profit', 470, 1), ('OCI', 'Other comprehensive income', 480, 0),
    ('TOTAL_COMP_INCOME', 'Total comprehensive income', 490, 1), ('UNBUDGETED', 'Not in budget', 500, 0))
