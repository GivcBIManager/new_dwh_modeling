{{ config(order_by='(branch_id, bed_location, date_day)') }}

{% set start_date = "toDate('" ~ var('hnh_history_start_date') ~ "')" %}
{% set end_date = "(today() - 1)" %}

with bed_rows as (
    select
        branch_id, bed_detail_id, bed_location, bed_status, work_entity, started_at,
        if(
            ended_at is null and is_current != 'Y',
            ifNull(leadInFrame(started_at) over (
                partition by branch_id, bed_location order by started_at, bed_detail_id
                rows between current row and unbounded following), started_at),
            ended_at
        ) as ended_at
    from {{ ref('stg_oasis__bed_details') }}
    where bed_location is not null and started_at is not null
),

beds as (
    select
        branch_id, bed_location,
        toDate(min(started_at)) as first_seen_date,
        max(if(ended_at is null, {{ end_date }}, toDate(assumeNotNull(ended_at)))) as last_seen_date,
        argMax(work_entity, tuple(started_at, bed_detail_id)) as current_work_entity
    from bed_rows
    group by branch_id, bed_location
),

spine as (
    select
        branch_id, bed_location, current_work_entity,
        arrayJoin(arrayMap(
            x -> greatest(first_seen_date, {{ start_date }}) + x,
            range(toUInt32(greatest(dateDiff('day', greatest(first_seen_date, {{ start_date }}), least(last_seen_date, {{ end_date }})) + 1, 0)))
        )) as date_day
    from beds
),

occupied_days as (
    -- A stay occupies the night of every day from its start date up to the day
    -- before its end date; an open stay occupies every night through yesterday.
    select
        branch_id, bed_location, date_day,
        argMax(admission_no, tuple(started_at, bed_detail_id))      as admission_no,
        argMax(patient_id, tuple(started_at, bed_detail_id))        as patient_id,
        argMax(work_entity, tuple(started_at, bed_detail_id))       as work_entity,
        argMax(is_excluded_ward, tuple(started_at, bed_detail_id))  as is_excluded_ward
    from (
        select
            g.branch_id as branch_id, g.bed_location as bed_location, g.bed_detail_id as bed_detail_id,
            g.admission_no as admission_no, g.patient_id as patient_id, g.work_entity as work_entity,
            g.is_excluded_ward as is_excluded_ward, g.started_at as started_at,
            arrayJoin(arrayMap(
                x -> g.night_from + x,
                range(toUInt32(greatest(dateDiff('day', g.night_from, g.night_to), 0)))
            )) as date_day
        from (
            -- Nights are clipped to the admission: [admission date, physical discharge date).
            select
                s.branch_id as branch_id, s.bed_location as bed_location, s.bed_detail_id as bed_detail_id,
                s.admission_no as admission_no, s.patient_id as patient_id, s.work_entity as work_entity,
                s.is_excluded_ward as is_excluded_ward, s.started_at as started_at,
                greatest(toDate(s.started_at), ifNull(toDate(a.admitted_at), toDate('1970-01-01'))) as night_from,
                least(
                    if(s.ended_at is null, {{ end_date }} + 1, toDate(assumeNotNull(s.ended_at))),
                    if(a.admission_no is null, toDate('2149-06-06'),
                       if(a.physical_discharge_at is null, {{ end_date }} + 1, toDate(assumeNotNull(a.physical_discharge_at))))
                ) as night_to
            from {{ ref('int_bed_segment') }} as s
            left join {{ ref('int_admission') }} as a
                on a.branch_id = s.branch_id and a.admission_no = s.admission_no
        ) as g
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
    from bed_rows as b
    inner join {{ ref('int_code_decode') }} as st
        on st.branch_id = b.branch_id and st.code = b.bed_status
    where st.description_upper in ('NO BED IN SLOT', 'NOT AVAILABLE')
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
    toUInt8(coalesce(o.is_excluded_ward, d.is_excluded_ward, 0)) as is_excluded_ward,
    toUInt8(ifNull(dw.care_setting, '') = 'IP')            as is_inpatient_ward
from spine as s
left join occupied_days as o
    on o.branch_id = s.branch_id and o.bed_location = s.bed_location and o.date_day = s.date_day
left join unavailable_days as u
    on u.branch_id = s.branch_id and u.bed_location = s.bed_location and u.date_day = s.date_day
left join {{ ref('int_department_conformed') }} as d
    on d.branch_id = s.branch_id and d.work_entity = s.current_work_entity
left join {{ ref('int_department_conformed') }} as dw
    on dw.branch_id = s.branch_id and dw.work_entity = coalesce(o.work_entity, s.current_work_entity)
{{ hnh_settings() }}
