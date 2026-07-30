-- Regression summary: query and log regression test results
-- Co-authored with CoCo
{# /*
--  Filename: run_regression_summary.sql
--
--  Purpose:
--      Replaces the PowerShell summary-output function.
--      Queries regression result tables and logs output.
--
--      Call via: dbt run-operation run_regression_summary
*/ #}

{% macro run_regression_summary(verbose=false) %}

    {% set regression_db = regression_testing.get_regression_db() %}

    {{ log('', true) }}
    {{ log('╔══════════════════════════════════════════════════╗', true) }}
    {{ log('║         REGRESSION TEST SUMMARY                 ║', true) }}
    {{ log('╚══════════════════════════════════════════════════╝', true) }}
    {{ log('', true) }}

    {# --- Regression Summary --- #}
    {{ _regression_query(
        query="select NUMBER_ROWS, TEST_NAME, CATEGORY, TEST_DETAILS from DBT_TEST_REGRESSION.REGRESSION_SUMMARY",
        title="Regression Summary",
        db_ext="_core"
    ) }}

    {# --- Table Hash Compare (mismatches only) --- #}
    {{ _regression_query(
        query="select OBJECT_TEST from DBT_TEST_REGRESSION.TABLE_HASH_COMPARE where match = false",
        title="Table Hash Compare - Not Matching",
        db_ext="_core"
    ) }}

    {# --- Changed Objects in Presentation Layer --- #}
    {{ _regression_query(
        query="select TABLE_SCHEMA, TABLE_NAME, CHANGE from DBT_TEST_REGRESSION.OBJECTS_ADDED_REMOVED where TABLE_SCHEMA like 'DBT_DM_%'",
        title="Changed Objects - Presentation Layer",
        db_ext="_core"
    ) }}

    {# --- Changed Columns in Presentation Layer --- #}
    {{ _regression_query(
        query="select TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, CHANGE, DATA_TYPE_WAS, DATA_TYPE_BECOMES from DBT_TEST_REGRESSION.COLUMNS_ADDED_REMOVED where TABLE_SCHEMA like 'DBT_DM_%' order by 1,2,3",
        title="Changed Columns - Presentation Layer",
        db_ext="_core"
    ) }}

    {{ log('', true) }}
    {{ log('=== Regression Summary Complete ===', true) }}

{% endmacro %}


{% macro _regression_query(query, title, db_ext='_core') %}
    {# Helper: execute a query against regression db and log results #}

    {% set full_db = target.database ~ db_ext %}
    {% set full_query = 'select * from ' ~ full_db ~ '.' ~ query.split('from ')[1] if 'from ' in query.lower() else query %}

    {# Build the actual query with correct database prefix #}
    {% set actual_query %}
        use database {{ full_db }};
    {% endset %}
    {% do run_query(actual_query) %}

    {{ log('--- ' ~ title ~ ' ---', true) }}

    {% if execute %}
        {% set results = run_query(query) %}
        {% if results|length == 0 %}
            {{ log('  (no rows)', true) }}
        {% else %}
            {# Log column headers #}
            {% set headers = results.column_names | join(' | ') %}
            {{ log('  ' ~ headers, true) }}
            {{ log('  ' ~ '-' * headers|length, true) }}
            {# Log each row #}
            {% for row in results %}
                {% set row_values = [] %}
                {% for col in row %}
                    {% do row_values.append(col|string) %}
                {% endfor %}
                {{ log('  ' ~ row_values | join(' | '), true) }}
            {% endfor %}
            {{ log('  (' ~ results|length ~ ' rows)', true) }}
        {% endif %}
    {% endif %}
    {{ log('', true) }}

{% endmacro %}
