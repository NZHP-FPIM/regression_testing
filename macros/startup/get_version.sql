{% macro get_version() %}
    {#
    -- Get current version of db
    -- if the version table doesn't exist it will get created and version set to 1
    #}

    {% set version_table = regression_testing.get_version_table_name() %}

    {% set new_version=1 %}
    {% do run_query('create schema if not exists '~var('cInfoSchema')) %}
    {% do run_query('create table if not exists '~version_table~' as (select '~new_version~' as version from dual)') %}

    -- find out what current version is
    {% set results = run_query('select version from ' ~ version_table) %}
    {% set current_version = results.columns[0].values()[0] %}

    {{ return(current_version) }}

{% endmacro %}
