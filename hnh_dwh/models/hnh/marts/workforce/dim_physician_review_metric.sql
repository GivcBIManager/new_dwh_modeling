{{ config(order_by='metric_code') }}

-- The nine metrics of the physician contract review, in report order (disconnected list: the report uses it as the row
-- axis and the measures read the selected metric_code). unit: 'sar' amount, '%' ratio shown as a percentage, 'n' count,
-- 'x' times. direction: 1 higher is better, -1 lower is better, 0 no direction. Names and sections are repo labels, not
-- title-cased.
select
    metric_code,
    metric_name,
    section,
    display_order,
    unit,
    direction
from values('metric_code String, metric_name String, section String, display_order UInt8, unit String, direction Int8',
    ('PR_PACKAGE', 'Monthly package', 'Salary', 1, 'sar', 0),
    ('PR_REVENUE', 'Billed revenue', 'Income', 2, 'sar', 1),
    ('PR_REJECTION', 'Claim rejection %', 'Income', 3, '%', -1),
    ('PR_OP_VISITS', 'OPD visits', 'Income', 4, 'n', 1),
    ('PR_ADMISSIONS', 'Admissions', 'Income', 5, 'n', 1),
    ('PR_SURGERIES', 'Surgeries / procedures', 'Income', 6, 'n', 1),
    ('PR_REV_PER_PATIENT', 'Revenue per patient', 'Income', 7, 'sar', 1),
    ('PR_GROWTH', 'Growth vs previous period', 'Income', 8, '%', 1),
    ('PR_REV_TO_PAY', 'Revenue-to-salary ratio', 'Income', 9, 'x', 1)
)
{{ hnh_settings() }}
