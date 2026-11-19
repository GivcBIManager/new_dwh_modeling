-- Every review_physician_key other than -1 has exactly one home row (is_review_physician = 1): the attached rows of
-- other hospitals point at one review physician (physician contract review spec, dbt item 3). One row per bad key.
select review_physician_key, countIf(is_review_physician = 1) as home_rows
from {{ ref('dim_review_physician') }}
where review_physician_key != -1
group by review_physician_key
having countIf(is_review_physician = 1) != 1
