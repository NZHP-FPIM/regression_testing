{#- /*
--  Filename: objects_in_database_s10.sql
--  Author: Jared Church

--  Purpose:
--      List all of the objects in the two families of databases
--      run macro that gets list of databases that match the two
--      families, then for each of test databases do the same

--  Technical Debt
--      should pull the database names from catalog_target_s10 and use
--      those rather than hard-coding the databases as done in here.
--      this can be done with jinja code and run_query.

*/ -#}



{% if execute %}
    {% set gold_dbs = get_database_family(family = env_var("DBT_REGRESSION_FROM_DB" ,var('qa_db'))) %}
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
        '{{ env_var("DBT_REGRESSION_FROM_DB" ,var('qa_db')) }}' as db_family
        ,table_catalog
        ,table_schema
        ,table_name
        ,null as table_type
        ,1 as gold
        ,0 as test
    from {{ db }}.information_schema.tables

{% endfor %}

{% for db in test_dbs %}
    union all

    /* Current database as the test database*/
    select
        '{{ env_var('DBT_TARGET_DB') }}' as db_family
        ,table_catalog
        ,table_schema
        ,table_name
        ,replace(table_type ,'BASE ' ,'') as table_type
        ,0 as gold
        ,1 as test
    from {{ db }}.information_schema.tables

{% endfor %}

{#- /* End of File */ #}
