-- Read-only. The other-hospital staff rows attached to a review physician's home row (gold.dim_review_physician), one row
-- each, for the user to check before G3 (physician contract review spec, dbt item 3): a pair the user rejects goes on an
-- exclusion list in the model. names_differ compares the two staff names in lower case with single spaces.
-- Before the model is built, put the rendered model (scripts/render_model_sql.py dim_review_physician) in place of
-- gold.dim_review_physician. The result holds staff names: keep it out of the repository.
select
    h.staff_key                                                         as home_staff_key,
    h.branch_key                                                        as home_branch_key,
    h.staff_id                                                          as staff_id,
    h.staff_name                                                        as home_staff_name,
    o.staff_key                                                         as other_staff_key,
    o.branch_key                                                        as other_branch_key,
    o.staff_name                                                        as other_staff_name,
    if(h.national_id_hash is not null and o.national_id_hash is not null, 'agreed', 'missing') as national_id,
    toUInt8(lower(replaceRegexpAll(trimBoth(ifNull(h.staff_name, '')), '\\s+', ' '))
         != lower(replaceRegexpAll(trimBoth(ifNull(o.staff_name, '')), '\\s+', ' ')))     as names_differ
from gold.dim_review_physician as r
inner join gold.dim_staff as o on o.staff_key = r.staff_key
inner join gold.dim_staff as h on h.staff_key = r.review_physician_key
where r.is_review_physician = 0 and r.review_physician_key != -1
order by home_branch_key, staff_id, other_branch_key
