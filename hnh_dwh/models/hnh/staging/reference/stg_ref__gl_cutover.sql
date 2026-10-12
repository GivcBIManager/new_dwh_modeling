-- First month each branch's GL comes from Fusion (bsc spec 5.1); a branch without a row stays on the Oasis GL.
select
    toUInt8(BRANCH_ID)                                                                       as branch_id,
    toInt32(FIRST_FUSION_GL_MONTH)                                                           as first_fusion_gl_month,
    makeDate(intDiv(toInt32(FIRST_FUSION_GL_MONTH), 100), toInt32(FIRST_FUSION_GL_MONTH) % 100, 1) as first_fusion_gl_month_start
from {{ source('reference', 'map_gl_cutover') }}
