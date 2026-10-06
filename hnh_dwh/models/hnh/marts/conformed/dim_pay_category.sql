{{ config(order_by='pay_category_key') }}

-- Common pay categories of Oasis and Fusion payroll (spec 4.3). fusion_sign turns Fusion's positive deduction values
-- into negative amounts; Oasis amounts are already signed.
select
    {{ hnh_surrogate_key(['c']) }}  as pay_category_key,
    c                               as pay_category,
    g                               as pay_group,
    toUInt8(cost)                   as is_cost,
    toUInt8(gross)                  as is_gross_pay,
    toUInt8(rec)                    as is_recurring,
    toInt8(sgn)                     as fusion_sign,
    toUInt16(srt)                   as sort_order
from values('c String, g String, cost UInt8, gross UInt8, rec UInt8, sgn Int8, srt UInt16',
    ('Basic', 'Earnings', 1, 1, 1, 1, 10), ('Housing', 'Earnings', 1, 1, 1, 1, 20), ('Transport', 'Earnings', 1, 1, 1, 1, 30),
    ('Food', 'Earnings', 1, 1, 1, 1, 40), ('Clinical allowances', 'Earnings', 1, 1, 1, 1, 50),
    ('Other allowances', 'Earnings', 1, 1, 1, 1, 60), ('Overtime', 'Earnings', 1, 1, 0, 1, 70),
    ('Leave pay', 'Earnings', 1, 1, 0, 1, 80), ('End of service', 'Earnings', 1, 1, 0, 1, 90),
    ('Awards and bonus', 'Earnings', 1, 1, 0, 1, 100),
    ('Absence and lateness deduction', 'Earnings adjustments', 1, 1, 0, -1, 110),
    ('GOSI employer charge', 'Employer charges', 1, 0, 0, 1, 120), ('Other employer charges', 'Employer charges', 1, 0, 0, 1, 130),
    ('GOSI employee deduction', 'Employee deductions', 0, 0, 0, -1, 140),
    ('Loans and advances', 'Employee deductions', 0, 0, 0, -1, 150), ('Other deductions', 'Employee deductions', 0, 0, 0, -1, 160),
    ('Not pay', 'Not pay', 0, 0, 0, 1, 170), ('Unmapped', 'Unmapped', 0, 0, 0, 1, 180))
