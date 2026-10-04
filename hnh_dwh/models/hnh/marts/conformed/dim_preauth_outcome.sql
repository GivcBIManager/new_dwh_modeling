{{ config(order_by='preauth_outcome_key') }}

select {{ hnh_preauth_outcome_key('o') }} as preauth_outcome_key, o as preauth_outcome,
       toUInt8(o in ('Approved', 'Partially approved', 'Not required')) as is_approved
from (select arrayJoin(['Approved', 'Partially approved', 'Not required', 'Rejected', 'Pended',
                        'Error', 'Cancelled', 'Not sent', 'Unknown']) as o)
