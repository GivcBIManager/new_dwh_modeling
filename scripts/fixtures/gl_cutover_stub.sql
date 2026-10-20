select toUInt8(b) as branch_id, toInt32(m) as first_fusion_gl_month,
       makeDate(intDiv(toInt32(m), 100), toInt32(m) % 100, 1) as first_fusion_gl_month_start
from values('b UInt8, m UInt32', (2, 202609), (3, 202607), (4, 202608), (5, 202609), (6, 202605), (7, 202601), (8, 202601))
