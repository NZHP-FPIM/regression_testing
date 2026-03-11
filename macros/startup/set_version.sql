{% macro set_version(db_version) %}
    {#
    -- Query Used to set the version
    -- possibly add a comment column in the future to capture comment as well.
    #}
    {% set version_table = regression_testing.get_version_table_name() %}
    {% do run_query('create or replace table '~version_table~' as (select '~db_version~' as version,current_timestamp as last_update_date from dual)') %}
{% endmacro %}
