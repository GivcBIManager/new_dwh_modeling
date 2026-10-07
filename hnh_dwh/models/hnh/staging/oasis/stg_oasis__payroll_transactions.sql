select
    toUInt8(branch_id)                          as branch_id,
    toInt64(account_transaction_no)             as account_transaction_no,
    {{ hnh_code('staff_id') }}                  as staff_id,
    toInt32(ifNull(year, 0) * 100 + ifNull(period, 0)) as payroll_month,
    upper(trimBoth(ifNull(trx_type, '')))       as trx_type,
    upper(trimBoth(ifNull(payable_type, '')))   as payable_type,
    {{ hnh_code('status') }}                    as status,
    toFloat64(ifNull(amount, 0))                as amount,
    toDate(transaction_date)                    as transaction_date
from {{ hnh_oasis_source('account_transactions') }} final
