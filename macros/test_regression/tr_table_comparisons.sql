{# /*
--  Filename: tr_table_comparisons.sql
--  Author: Jared Church <jared.church@healthsourcenz.co.nz
--
--  Purpose:
--      Creates views that compare at row level between
--      test_schema in test and gold databases

--  Notes:
--      At some stage should add to this capability to select a
--      specific table/group of tables to run for
--      also probably consolidate with tr_row_comparisons as these
--      two get used together (refer test_regression)

*/ #}

{% macro tr_table_comparisons(
        target_table='DBT_TEST_REGRESSION.table_hash_test'
        ,verbose=false
) %}

    {% set regression_db = regression_testing.get_regression_db() %}
    {% set target_table=regression_db~'.'~target_table %}
    {% set target_schema_row_cmp = regression_testing.get_row_cmp_schema() %}

    {% set queryCreate %}
        create or replace table {{ target_table }}
            (
                match boolean
                ,test_query text
                ,view_definition text
                ,hash_test number
                ,hash_gold number
                ,object_test text
                ,object_gold text
            )
    {% endset %}

    {% set queryIdObjects %}
    -- create a row for each object to be compared
        with b as (
            select
                test_table
                ,column_name
            from
                {{ ref('columns_in_both') }}
            where
                column_name='_INCLUDE_REGRESSION'
        ),
        c as (
            select
                test_table
                ,gold_table
                ,listagg(column_name, ',') within group (order by column_name) as cols
            from 
                {{ ref('columns_in_both') }}
            group by 
                test_table
                ,gold_table
        )
        select
            a.test_table_name
            ,a.gold_table_name
            ,b.column_name
            ,a.table_name || '___' || a.table_schema as row_comparison_object
            ,'skey_' || a.table_name as row_cmp_key
            ,c.cols
        from
            {{ ref('objects_in_both') }} a
        left join b
            on b.test_table = a.test_table_name
        left join c
            on
                c.test_table = a.test_table_name
                and c.gold_table = a.gold_table_name
        where
            a.table_schema not in ('INFORMATION_SCHEMA' ,'INFO_HS' ,'PUBLIC' ,'DBT_TEST_REGRESSION' ,'DBT_TEST_AUDIT')
            and SPLIT_PART(a.test_table_name, '.', 1) ilike '%_CORE'
        {# /*
            and table_name in ('REP_SOH_PLAN','DIM_SOURCE_SYSTEM','FACT_MTL_ITEM_SUB_INVENTORIES')
        */ #}
    {% endset %}

    {{ log(queryCreate,verbose) }}
    {{ log(queryIdObjects,verbose) }}

    {% do run_query(queryCreate) %}

    {% set list = run_query(queryIdObjects) %}
    {% set list_length = list | length %}

    {% for entry in list %}
        {{ log (entry[0]~':'~entry[1],verbose) }}

        {{ tr_table_comparisons_row(
            target_table=target_table
            ,test_table=entry[0]
            ,gold_table=entry[1]
            ,include_filter=entry[2]
            ,row_cmp_object=entry[3]
            ,row_cmp_key=entry[4]
            ,cols=entry[5]
            ,target_schema_row_cmp=target_schema_row_cmp
            ,cmp_number=loop.index~'/'~list_length
            ,regression_db=regression_db
            ,verbose=verbose
        ) }}
    {% endfor %}

{% endmacro %}


{% macro tr_table_comparisons_row(
        target_table
        ,test_table
        ,gold_table
        ,include_filter
        ,row_cmp_object
        ,row_cmp_key
        ,cols
        ,target_schema_row_cmp
        ,cmp_number
        ,regression_db
        ,verbose=false
) %}

    {{ log('Object Hash Comparison '~cmp_number~': '~test_table~' include_filter: '~include_filter,true) }}

    {% set test_query %}
        select *
        from {{ target_schema_row_cmp }}.{{ row_cmp_object }}
        {% if include_filter is not none %}
            where _include_regression = 1
        {% endif %}
        order by {{ row_cmp_key }},which
        ;
    {% endset %}

    {% set query %}
        insert into {{ target_table }}
        with test as (
            select 
                '{{ test_table }}' as db_test
                ,hash_agg({{ cols }}) as ha_test
            from {{ test_table }}
            {%- if include_filter is not none %}
                where _include_regression = 1
            {%- endif %}
        )
        , gold as (
            select 
                '{{ gold_table }}' as db_gold
                ,hash_agg({{ cols }}) as ha_gold
            from {{ gold_table }}
            {%- if include_filter is not none %}
                where _include_regression = 1
            {%- endif %}
        )
        , vd as (
            select view_definition
            from {{ regression_db }}.INFORMATION_SCHEMA.VIEWS
            where concat_ws('.',table_catalog,table_schema,table_name) = upper('{{ target_schema_row_cmp }}.{{ row_cmp_object }}')
        )
        select
            case when ha_test=ha_gold then true else false end  as match

            {#- /*
            this replace/trim/replace helps to avoid some usability issues in
            a specific case. When user queries the table in snowflake web interface
            then copies these querys to excel, and then copy back from excel to
            snowflake the query fails because of the carriag return character - the
            rest is just tidy up of spaces
             */ #}
            ,regexp_replace(trim(replace('{{ test_query }}','\n','')),' [ ]*',' ') as test_query
            ,vd.view_definition as view_definition
            ,ha_test    as hash_test
            ,ha_gold    as hash_gold
            ,db_test    as db_test
            ,db_gold    as db_gold
        from test
        left join gold
        left join vd
    {% endset %}

    {{ log(query,verbose) }}
    {% set res = run_query(query) %}
    {{ log(target_table~' inserted '~res[0][0]~' row(s)',verbose) }}

{% endmacro %}



{#- /* End of File */ #}
