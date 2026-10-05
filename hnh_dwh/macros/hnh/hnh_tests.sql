{# Fails with one row per duplicated combination of the given columns. #}
{% test hnh_unique_combination(model, columns) %}
select {{ columns | join(', ') }}, count() as n
from {{ model }}
group by {{ columns | join(', ') }}
having n > 1
{% endtest %}

{# Fails with one row per value whose absolute size exceeds the tolerance. #}
{% test hnh_within_tolerance(model, column_name, tolerance) %}
select {{ column_name }} as value
from {{ model }}
where abs({{ column_name }}) > {{ tolerance }}
{% endtest %}
