{{ config(order_by='scope_code') }}

-- The two peer scopes of the physician contract review (disconnected list: the report uses it as the column axis and the
-- measures read the selected scope_code). Names are repo labels, not title-cased.
select
    scope_code,
    scope_name,
    display_order
from values('scope_code String, scope_name String, display_order UInt8',
    ('HOSPITAL', 'Same hospital', 1),
    ('GROUP', 'Group', 2)
)
{{ hnh_settings() }}
