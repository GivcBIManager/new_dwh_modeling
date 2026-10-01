{# Append one row to gold.etl_run_log at the end of every dbt run or build. #}
{% macro hnh_log_run(results) %}
  {% if execute and flags.WHICH in ('run', 'build') %}
    {% set failed = results | selectattr('status', 'in', ['error', 'fail']) | list | length %}
    {% set built = results | selectattr('node.resource_type', 'equalto', 'model') | selectattr('status', 'equalto', 'success') | list | length %}
    {% set create_sql %}
      create table if not exists gold.etl_run_log (
          invocation_id String,
          run_started_at DateTime('Asia/Riyadh'),
          run_finished_at DateTime('Asia/Riyadh'),
          status LowCardinality(String),
          models_built UInt32,
          nodes_failed UInt32,
          selected String
      ) engine = MergeTree order by run_started_at
    {% endset %}
    {% do run_query(create_sql) %}
    {% set insert_sql %}
      insert into gold.etl_run_log values (
          '{{ invocation_id }}',
          toDateTime('{{ run_started_at.strftime("%Y-%m-%d %H:%M:%S") }}', 'UTC'),
          now('Asia/Riyadh'),
          '{{ "failed" if failed > 0 else "success" }}',
          {{ built }},
          {{ failed }},
          '{{ (invocation_args_dict.get("select") or []) | join(" ") | replace("'", "") }}'
      )
    {% endset %}
    {% do run_query(insert_sql) %}
  {% endif %}
{% endmacro %}
