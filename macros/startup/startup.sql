{# /*
-----------------------------------------------------------------------
--
--  Filename:   startup.sql
--  Author:     Jared Church <jared.church@healthsourcenz.co.nz>
--  Purpose:    hook for start of execution
--              moves old logs to history table
--              upgrade db version
--
--  Deprecation Note:
--      upgrade_version macro is deprecated as it often ended up
--      making changes that caused dbt operation to fail. It should
--      be run separately and before the run/build operation to
--      do the upgrade
--
-----------------------------------------------------------------------

--
-- main macro for on run start
--
*/ #}

{% macro startup() %}

    {% if execute %}
        {% set info_schema = var('cInfoSchema') %}
        {% set t = run_query('create schema if not exists '~info_schema) %}

        {{ regression_testing.startup_logging() }}

        {{ print('############ upgrade_version macro is removed from on-run-start hook. Please run separately') }}
        {{ print('############ > dbt run-operation upgrade_version') }}

        {% set tmp = regression_testing.get_regression_db() %}

    {% endif %}
{% endmacro %}
