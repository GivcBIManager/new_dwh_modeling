{# Fails with one row per duplicated combination of the given columns. #}
{% test hnh_unique_combination(model, columns) %}
select {{ columns | join(', ') }}, count() as n
from {{ model }}
group by {{ columns | join(', ') }}
having n > 1
{% endtest %}
