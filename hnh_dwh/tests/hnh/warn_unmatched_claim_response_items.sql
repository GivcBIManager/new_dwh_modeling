{{ config(severity='warn') }}
-- Claim-response items that match no claim line of the visit that sent the transaction.
select a.branch_id, count() as items
from {{ ref('int_nphies_adjudication') }} as a
left join (
    select v.branch_id as branch_id, v.api_trans_id as api_trans_id, s.sequence_no as sequence_no
    from {{ ref('int_claim_submission') }} as v
    inner join {{ ref('stg_oasis__claim_services') }} as s on s.branch_id = v.branch_id and s.visit_id = v.visit_id
    where v.api_trans_id is not null
) as c on c.branch_id = a.branch_id and c.api_trans_id = a.about_api_trans_id and c.sequence_no = a.item_sequence
where a.response_kind = 'Claim' and c.api_trans_id is null
group by a.branch_id
settings join_use_nulls = 1
