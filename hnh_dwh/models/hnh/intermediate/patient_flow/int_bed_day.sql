{{ config(order_by='(branch_id, bed_location, date_day)') }}

{% set start_date = "toDate('" ~ var('hnh_history_start_date') ~ "')" %}
{% set end_date = "(today() - 1)" %}

with beds as (
    select
        branch_id, bed_location,
        toDate(min(started_at)) as first_seen_date,
        argMax(work_entity, tuple(started_at, bed_detail_id)) as current_work_entity
    from {{ ref('stg_oasis__bed_details') }}
    where bed_location is not null and started_at is not null
    group by branch_id, bed_location
),

spine as (
    select
        branch_id, bed_location, current_work_entity,
        arrayJoin(arrayMap(
            x -> greatest(first_seen_date, {{ start_date }}) + x,
            range(toUInt32(greatest(dateDiff('day', greatest(first_seen_date, {{ start_date }}), {{ end_date }}) + 1, 0)))
        )) as date_day
    from beds
),

occupied_days as (
    -- A stay occupies the night of every day from its start date up to the day
    -- before its end date; an open stay occupies every night through yesterday.
    select
        branch_id, bed_location, date_day,
        argMax(admission_no, started_at)      as admission_no,
        argMax(patient_id, started_at)        as patient_id,
        argMax(work_entity, started_at)       as work_entity,
        argMax(is_excluded_ward, started_at)  as is_excluded_ward
    from (
        select
            branch_id, bed_location, admission_no, patient_id, work_entity, is_excluded_ward, started_at,
            arrayJoin(arrayMap(
                x -> toDate(started_at) + x,
                range(toUInt32(greatest(
                    dateDiff('day', toDate(started_at), if(ended_at is null, {{ end_date }} + 1, toDate(assumeNotNull(ended_at)))),
                    0)))
            )) as date_day
        from {{ ref('int_bed_segment') }}
    )
    group by branch_id, bed_location, date_day
),

unavailable_days as (
    select distinct
        b.branch_id as branch_id, b.bed_location as bed_location,
        arrayJoin(arrayMap(
            x -> toDate(b.started_at) + x,
            range(toUInt32(greatest(
                dateDiff('day', toDate(b.started_at), if(b.ended_at is null, {{ end_date }} + 1, toDate(assumeNotNull(b.ended_at)))),
                0)))
        )) as date_day
    from {{ ref('stg_oasis__bed_details') }} as b
    inner join {{ ref('int_code_decode') }} as st
        on st.branch_id = b.branch_id and st.code = b.bed_status
    where b.bed_location is not null and b.started_at is not null
      and st.description_upper in ('NO BED IN SLOT', 'NOT AVAILABLE')
)

select
    s.branch_id                                            as branch_id,
    assumeNotNull(s.bed_location)                          as bed_location,
    assumeNotNull(s.date_day)                              as date_day,
    coalesce(o.work_entity, s.current_work_entity)         as work_entity,
    toUInt8(u.bed_location is null or o.bed_location is not null) as is_available,
    toUInt8(o.bed_location is not null)                    as is_occupied,
    o.admission_no                                         as admission_no,
    o.patient_id                                           as patient_id,
    toUInt8(coalesce(o.is_excluded_ward, d.is_excluded_ward, 0)) as is_excluded_ward
from spine as s
left join occupied_days as o
    on o.branch_id = s.branch_id and o.bed_location = s.bed_location and o.date_day = s.date_day
left join unavailable_days as u
    on u.branch_id = s.branch_id and u.bed_location = s.bed_location and u.date_day = s.date_day
left join {{ ref('int_department_conformed') }} as d
    on d.branch_id = s.branch_id and d.work_entity = s.current_work_entity
{{ hnh_settings() }}
