{{ config(severity='warn') }}
-- Closed days after go-live where more than 20% of the Oasis lines are not in Fusion yet (spec 8, F2).
select branch_key, line_date, lines_from_go_live, gap_lines, round(gap_share, 3) as gap_share
from {{ ref('rec_stock_interface_daily') }}
where is_live = 1 and line_date < today() and gap_share > 0.20
