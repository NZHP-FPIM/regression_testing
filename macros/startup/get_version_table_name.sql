{% macro get_version_table_name(verbose=false) %}
    {#
    -- define the version table
    -- this means that the naming of the version table is only defined in one macro
    -- other macros can use this.
    #}
    
    {% set version_table = target.database~'_land.'~var('cInfoSchema')~"."~var('cVersionTable') %}
    {{ log ('Version Table: '~version_table,verbose) }}
    {{ return (version_table) }}

{% endmacro %}
