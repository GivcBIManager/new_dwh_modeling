-- Read-only. Every candidate pair of a review physician's home row and another hospital's staff row for the user to check
-- before G3 (physician contract review spec, dbt item 3; ruling R2): the same staff id in another branch, the other row not
-- linked to HR, the national ids not contradicting. attached: 1 when dim_review_physician attaches the row to this home.
-- reason: 'national id' (both rows have one and they agree), else 'name agrees' or 'name differs' (hnh_name_tokens_agree).
-- A row with two agreeing homes is listed twice, not attached. Not-attached pairs first.
-- A pair the user rejects goes on an exclusion list in the model. The result holds staff names: keep it out of the repo.
-- Render with scripts/render_model_sql.py (path of this file; --inline dim_review_physician before the model is built).
with staff as (
    select d.staff_key as staff_key, d.branch_key as branch_key, d.staff_id as staff_id, d.staff_name as staff_name,
           d.national_id_hash as national_id_hash, {{ hnh_name_tokens('d.staff_name') }} as name_tokens
    from {{ ref('dim_staff') }} as d
    where d.staff_id is not null
),

home as (
    select s.staff_key as staff_key, s.branch_key as branch_key, s.staff_id as staff_id, s.staff_name as staff_name,
           s.national_id_hash as national_id_hash, s.name_tokens as name_tokens
    from staff as s
    inner join {{ ref('dim_review_physician') }} as r on r.staff_key = s.staff_key
    where r.is_review_physician = 1
)

select
    h.staff_key                                                         as home_staff_key,
    h.branch_key                                                        as home_branch_key,
    h.staff_id                                                          as staff_id,
    h.staff_name                                                        as home_staff_name,
    o.staff_key                                                         as other_staff_key,
    o.branch_key                                                        as other_branch_key,
    o.staff_name                                                        as other_staff_name,
    toUInt8(r.review_physician_key = h.staff_key)                       as attached,
    multiIf(h.national_id_hash is not null and o.national_id_hash is not null, 'national id',
            {{ hnh_name_tokens_agree('o.name_tokens', 'h.name_tokens') }}, 'name agrees', 'name differs') as reason
from staff as o
inner join home as h on h.staff_id = o.staff_id
inner join {{ ref('dim_review_physician') }} as r on r.staff_key = o.staff_key
where o.branch_key != h.branch_key
  and o.staff_key not in (select staff_key from {{ ref('bridge_employee_staff') }})
  and (o.national_id_hash is null or h.national_id_hash is null or o.national_id_hash = h.national_id_hash)
order by attached, home_branch_key, staff_id, other_branch_key
{{ hnh_settings() }}
