{# /*
--  Filename: tr_table_comparisons.sql
--  Author: Jared Church <jared.church@healthsourcenz.co.nz
--
--  Purpose:
--      does a table comparison

--  Notes:
--      At some stage should add to this capability to select a
--      specific table/group of tables to run for
--      also probably consolidate with tr_table_comparisons as these
--      two get used together (refer test_regression)
*/ #}

{% macro tr_row_comparisons(
    verbose=false
    ,dry_run=false
) %}

    {% set test_db = regression_testing.get_regression_db() %}
    {% set create_in_schema = regression_testing.get_row_cmp_schema() %}

    {% do run_query('drop schema if exists '~create_in_schema) %}
    {% do run_query('create schema if not exists '~create_in_schema) %}

    {% set query1 %}
        select test_table,gold_table
            ,'"'||
                listagg(column_name,'", "')
                within group (
                    order by
                        case when column_name='SKEY_'||table_name then 1 else 9 end
                        ,column_name
                )
                ||'"' as cols
            ,max(case when column_name = 'SKEY_'||table_name then column_name||',which' end) as order_by
            ,max(case when column_name = '_INCLUDE_REGRESSION' then 'where '||column_name||' = 1' end) as include_regression
        from {{ ref('columns_in_both') }}
        where
            column_name not in ('HSNZ_UPDATE_TIMESTAMP')
            and SPLIT_PART(test_table, '.', 1) ilike '%_CORE'
            and table_schema not in ('INFORMATION_SCHEMA' ,'INFO_HS' ,'PUBLIC' ,'DBT_TEST_REGRESSION' ,'DBT_TEST_AUDIT')
        {# /*
            and table_name in ('REP_SOH_PLAN','DIM_SOURCE_SYSTEM','FACT_MTL_ITEM_SUB_INVENTORIES')
        */ #}
        {% endset %}


    {% set query3 %}
        group by test_table,gold_table
        order by test_table
    {% endset %}

    {% set query %}
        {{ query1 }}
        {{ query3 }}
    {% endset %}

    {{ log(query,verbose) }}

    {% if dry_run %}
        {{ log('[tr_row_comparisons] Dry Run - No execution',true) }}
    {% else %}
        {% set list = run_query(query) %}

        {% set list_length = list | length %}
        {{ log ('Number of Views: '~list_length,verbose) }}
        {% for entry in list %}

            {% set target_view_name=create_in_schema~'.'~entry[0].split('.')[2]~'___'~entry[0].split('.')[1] %}
            {{ log (entry[0]~':'~entry[1],verbose) }}
            {{ log (target_view_name,verbose) }}

            {% if entry[3] != None %}
                {% set order_by=' order by '~entry[3] %}
            {% else %}
                {% set order_by='' %}
            {% endif %}

            {% if entry[4] != None %}
                {% set include_regression=entry[4] %}
            {% else %}
                {% set include_regression='' %}
            {% endif %}

            {{ log('order_by='~order_by,verbose) }}
            {{ log('include_regression='~include_regression,verbose) }}

            {{ tr_create_compare_object(
                view_name=target_view_name
                ,test_table=entry[0]
                ,gold_table=entry[1]
                ,cols=entry[2]
                ,order_by=order_by
                ,include_regression=include_regression
                ,view_number=loop.index~'/'~list_length
                ,verbose=verbose)
            }}
        {% endfor %}
    {% endif %}
{% endmacro %}

{% macro tr_create_compare_object(
    view_name
    ,test_table
    ,gold_table
    ,cols='*'
    ,order_by=''
    ,include_regression=''
    ,view_number=''
    ,verbose=false
) %}

    {% set test_db=test_table.split('.')[0] %}
    {% set gold_db=gold_table.split('.')[0] %}

    {% set comparison_query %}
        with test as (
            select
                {{ cols }}
            From {{ test_table }}
        ),gold as (
            select
                {{ cols }}
            from {{ gold_table }}
        ),test_not_gold as (
            select * from test minus select * from gold
        ),gold_not_test as (
            select * from gold minus select * from test
        ),data as (
            select '{{ test_db }}' as which,* from test_not_gold
            union all
            select '{{ gold_db }}' as which,* from gold_not_test
        )
        select *,'{{ test_table }}' as test_table,'{{ gold_table }}' as gold_table
        from data {{ include_regression }} {{ order_by }}
    {% endset %}

    {% set query %}
    create or replace view {{ view_name }} as (
        {{ comparison_query }}
    )
    {% endset %}


    {{ log('Create View '~view_number~': '~view_name,true) }}
    {{ log(query,verbose) }}
    {% set res = run_query(query) %}
    {{ log(res[0][0],verbose) }}

{% endmacro %}


{#- /* End of File */ #}
