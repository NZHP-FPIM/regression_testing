{% macro get_row_cmp_schema(verbose=false) %}

    {% set row_cmp_schema = regression_testing.get_regression_db()~'.ROW_COMPARISON' %}
    {{ log('row_cmp_schema='~row_cmp_schema,verbose) }}
    {{ return(row_cmp_schema) }}

{% endmacro %}
