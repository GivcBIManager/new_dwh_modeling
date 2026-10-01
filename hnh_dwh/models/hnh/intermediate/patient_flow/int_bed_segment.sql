{{ config(order_by='(branch_id, admission_no, bed_detail_id)') }}

select
    b.branch_id                                               as branch_id,
    b.bed_detail_id                                           as bed_detail_id,
    assumeNotNull(b.admission_no)                             as admission_no,
    b.patient_id                                              as patient_id,
    b.episode_no                                              as episode_no,
    b.work_entity                                             as work_entity,
    assumeNotNull(b.bed_location)                             as bed_location,
    b.bed_class                                               as bed_class,
    assumeNotNull(b.started_at)                               as started_at,
    b.ended_at                                                as ended_at,
    ifNull(cls.classification, 'Not Mapped')                  as classification,
    toUInt8(ifNull(cls.classification, '') = 'Critical')      as is_critical,
    toUInt8(ifNull(d.is_excluded_ward, 0))                    as is_excluded_ward,
    row_number() over (partition by b.branch_id, b.admission_no order by b.started_at asc, b.bed_detail_id asc)   as segment_seq,
    row_number() over (partition by b.branch_id, b.admission_no order by b.started_at desc, b.bed_detail_id desc) as segment_seq_desc
from {{ ref('stg_oasis__bed_details') }} as b
left join {{ ref('stg_ref__bed_classification') }} as cls
    on cls.branch_id = b.branch_id and cls.bed_location = b.bed_location
left join {{ ref('int_department_conformed') }} as d
    on d.branch_id = b.branch_id and d.work_entity = b.work_entity
where b.admission_no is not null
  and b.bed_location is not null
  and b.started_at is not null
{{ hnh_settings() }}
