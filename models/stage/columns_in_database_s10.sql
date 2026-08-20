{#- /*
--  Filename: columns_in_database_s10.sql
--  Author: Jared Church <jared.church@healthsourcenz.co.nz>

--  Purpose:
--      gets all of the columns in the two databases test and gold
--      note that the current database is included two times
--      the raeson for this being in the case that user needs to 
--      do some testing for a change in process before it is
--      released - adjust the definitions in catalog_target_s10
--      to make test and gold the same and can then work in here

--  Primary Key:
--      table_catalog,table_schema,table_name,column_name

--  Technical Debt
--      none known
*/ -#}

{% set cols %}
    table_catalog
    ,table_schema
    ,table_name
    ,column_name
    ,data_type
{% endset %}

{% if execute %}
    {% set gold_dbs = get_database_family(family = env_var('DBT_REGRESSION_FROM_DB', var('qa_db')) ) %}
    {% set test_dbs = get_database_family(family = env_var('DBT_TARGET_DB')) %}
{% else %}
    {% set gold_dbs = [var('qa_db')] %}
    {% set test_dbs = [env_var('DBT_TARGET_DB')] %}
{% endif %}

{% for db in gold_dbs if 'REGRESSION' not in db %}

    {% if not loop.first %}
        union all
    {% endif %}
    select
        {{ "'" ~ env_var('DBT_REGRESSION_FROM_DB', var('qa_db')) ~ "'" }} as db_family
        ,{{ cols }}
        ,1 as gold
        ,0 as test
    from {{ db }}.information_schema.columns

{% endfor %}

{% for db in test_dbs %}
    union all

    /* Current database as the test database*/
    select
        '{{ env_var('DBT_TARGET_DB') }}' as db_family
        ,{{ cols }}
        ,0 as gold
        ,1 as test
    from {{ db }}.information_schema.columns

{% endfor %}


{#- /* End of File */ #}
