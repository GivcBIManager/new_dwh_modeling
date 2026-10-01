{{ config(severity='warn') }}
-- Beds with no classification are never counted as Critical. Review the mapping when this grows.
select branch_key, count() as unmapped_beds
from {{ ref('dim_bed') }}
where classification = 'Not Mapped'
group by branch_key
