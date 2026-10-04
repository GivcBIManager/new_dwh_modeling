select
    trimBoth(DetailedStatus)    as detailed_status,
    trimBoth(SubmitionStatus)   as submission_status,
    trimBoth(ValidationStatus)  as validation_status
from {{ source('reference', 'map_claim_status') }}
