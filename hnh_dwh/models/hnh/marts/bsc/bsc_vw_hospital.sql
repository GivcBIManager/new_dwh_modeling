{{ config(alias='vw_hospital') }}

-- Old bsc.vw_hospital (bsc spec 7.1): branches 1-8 with name and city. Khamis's city is 'Aseer' (old: 'Asser').
select
    toUInt64(branch_key)       as Id,
    ifNull(branch_name, '')    as Hospital,
    ifNull(city, '')           as City
from {{ ref('hnh_dim_branch') }}
where branch_key between 1 and 8
