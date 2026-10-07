{{ config(alias='fact_gl_journal_line', order_by='(branch_key, period_key, gl_account_key, gl_journal_line_key)') }}

{% set oasis_feed = "'" ~ var('hnh_fusion_oasis_feed_source') ~ "'" %}

select
    {{ hnh_surrogate_key(['j.je_header_id', 'j.je_line_num']) }}         as gl_journal_line_key,
    j.je_header_id                                                      as je_header_id,
    j.je_line_num                                                       as je_line_num,
    ifNull(b.branch_key, toUInt8(0))                                    as branch_key,
    ifNull(a.gl_account_key, toInt64(-1))                               as gl_account_key,
    ifNull(p.period_key, toInt32(0))                                    as period_key,
    {{ hnh_date_key_in_range('j.accounting_date') }}                    as accounting_date_key,
    {{ hnh_date_key_in_range('j.posted_date') }}                        as posted_date_key,
    a.intercompany_branch_key                                           as intercompany_branch_key,
    j.ledger_id                                                         as ledger_id,
    j.je_batch_id                                                       as je_batch_id,
    j.journal_name                                                      as journal_name,
    j.doc_sequence_value                                                as doc_sequence_value,
    j.je_source                                                         as je_source,
    if(ifNull(j.je_source, '') = {{ oasis_feed }}, 'Oasis feed', ifNull(j.je_source, 'Unknown')) as je_source_label,
    j.je_category                                                       as je_category,
    j.header_status                                                     as header_status,
    j.line_description                                                  as line_description,
    toUInt8(ifNull(j.header_status, '') = 'P')                          as is_posted,
    -- Opening balance: Fusion category, or a batch listed in map_opening_balance_batch (O-P3-12).
    toUInt8(ifNull(j.je_category, '') = 'MRC Open Balances'
            or ifNull(j.je_batch_id, toInt64(-1)) in (select je_batch_id from {{ ref('stg_ref__opening_balance_batch') }})) as is_opening_balance_journal,
    toUInt8(ifNull(j.je_source, '') = {{ oasis_feed }})                 as is_oasis_feed,
    j.debit                                                             as debit,
    j.credit                                                            as credit,
    j.debit - j.credit                                                  as amount,
    now()                                                               as _loaded_at
from {{ ref('stg_fusion__gl_journal_lines') }} as j
left join (
    select gl_account_key, code_combination_id, intercompany_branch_key
    from {{ ref('hnh_dim_gl_account') }} where code_combination_id is not null
) as a on a.code_combination_id = j.code_combination_id
left join (
    select branch_key, fusion_ledger_id from {{ ref('hnh_dim_branch') }} where fusion_ledger_id is not null
) as b on b.fusion_ledger_id = j.ledger_id
left join (select period_key, period_name from {{ ref('hnh_dim_gl_period') }}) as p on p.period_name = j.period_name
where j.actual_flag = 'A'
{{ hnh_settings() }}
