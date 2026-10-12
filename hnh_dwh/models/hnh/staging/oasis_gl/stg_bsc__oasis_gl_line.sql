-- Oasis GL lines for fact_gl_fs_monthly (bsc spec 5.2). fact_oasis_gl_line already applies the old warehouse's
-- filters (C_ID 36, latest version): its 2025 rows and totals equal the old tr_gl_distribution per branch (2026-10-12).
select
    branch_key,
    oasis_gl_account_key,
    month_start,
    is_posted,
    is_brought_forward,
    amount
from {{ hnh_oasis_gl_source('fact_oasis_gl_line') }}
