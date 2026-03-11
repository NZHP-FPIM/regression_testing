{# /*
--  Filename: tr_pk_len_comparisons.sql
--  Author: Badi James <badi.james@healthsourcenz.co.nz , badij@acumenbi.co.nz>
--
--  Purpose:
--      Creates a view that compares row count and intersection of primary key 
--      values for each object where the test version does not match the gold version

--  Notes:
--      Refers to the object created by tr_table_comparisons to find mismatched
--      objects, hence should be run after tr_table_comparisons

--  Tech Debt:
--      The may be an issue where no results to compare - possible scenario
--      optimising a staging table with no output impact.

--      I think that this needs to include schema for object name when it builds
--      this table - that is then used in tr_column_comparisons to resolve
--      and correctly identify the part of columns in both that is of interest.

--      Probably should have schema name passed as a variable for which objects
--      to test rather than filtering where a column _INCLUDE_REGRESSION exists
--      (which is probably not correct as that column indicates rows for
--      inclusion in regression test, not tables - see additional comments below).
*/ #}

{% macro tr_pk_len_comparisons(table_hash_test='DBT_TEST_REGRESSION.table_hash_test', target_view='DBT_TEST_REGRESSION.row_count_pk_compare', verbose=false) %}

    {% set regression_db = regression_testing.get_regression_db() %}
    {% set table_hash_test=regression_db~'.'~table_hash_test %}

    {% set queryMismatchTables %}
        with inc_reg_tables as (
            select distinct
                table_name
            from
                {{ ref('columns_in_both' ) }}
            where
                -- This is used to identify if include regression column exists
                -- if it does exist in both versions then it is used to restrict the set of data
                -- in this query.
                column_name = '_INCLUDE_REGRESSION'
                -- Should only be considered against the warehouse layer, _include_regression
                -- column anywhere else is an error. The column is only defined as existing
                -- in the WAREHOUSE layer
                and SPLIT_PART(test_table, '.', 1) ilike '%_CORE'
                and table_schema not in ('INFORMATION_SCHEMA' ,'INFO_HS' ,'PUBLIC' ,'DBT_TEST_REGRESSION' ,'DBT_TEST_AUDIT' ,'DBT_TEST_BIST')
        )

        -- This part of query is used to identify where tables have differences
        -- restricted to just consider warehouse layer as that is where
        -- the testing should occur
        select
            a.object_test
            , a.object_gold
            , b.table_name is not null as include_regression
        from
            {{ table_hash_test }} as a
        left join
            inc_reg_tables as b
            on
                split_part(a.object_test, '.', 3) = b.table_name
        where
            -- only run test where the two tables are not identical
            not a.match
            -- only run the test against objects in DBT_WAREHOUSE layer
            and split_part(a.object_test, '.', 1) ilike '%_CORE'

    {% endset %}

    {{ log(queryMismatchTables, verbose) }}

    {% set list = run_query(queryMismatchTables) %}

    {% set view_name = regression_db~'.'~target_view %}

    {% set createCountQuery %}
        create or replace transient table {{ view_name }} as (
        {% for entry in list %}
            {% set object_test = entry[0] %}
            {% set object_gold = entry[1] %}
            {% set include_regression = entry[2] %}
            {% set table_name = object_test.split('.')[2] %}
            {{ log (object_test~':'~object_gold,verbose) }}
            {%- set pk_name = 'skey_'~table_name -%}
            {{ log(pk_name, verbose) }}

            select
                '{{ table_name }}' as object_name
                ,'{{ entry[0] }}' as object_test
                ,'{{ entry[1] }}' as object_gold
                ,count(*) as full_count
                ,count_if(gold.{{ pk_name }} is not null) as gold_count
                ,count_if(test.{{ pk_name }} is not null) as test_count
                ,count_if(test.{{ pk_name }} is not null and gold.{{ pk_name }} is not null) as intersect_count
                ,gold_count - intersect_count as gold_not_in_test_count
                ,test_count - intersect_count as test_not_in_gold_count
                ,gold_not_in_test_count = 0 and test_not_in_gold_count = 0 as row_counts_match
                ,case
                    when gold_count = intersect_count and gold_count = test_count then 'Equal Sets'
                    when gold_count = intersect_count and gold_count < test_count then 'Test is superset of Gold'
                    when test_count = intersect_count and test_count < gold_count then 'Gold is superset of Test'
                    when intersect_count = 0 then 'No Intersection'
                    else 'Intersecting Sets'
                end as set_comparison
            from
                {{ object_test }} as test
            full outer join
                {{ object_gold }} as gold on test.{{ pk_name }} = gold.{{ pk_name }} 
            {% if include_regression %}
                where
                    test._include_regression = 1
                    or gold._include_regression = 1
            {% endif %}

            {% if not loop.last %}
                union all
            {% endif %}

        {%- endfor %}

        )
    
    {% endset %}

    {% if execute %}
        {{ log(createCountQuery, verbose) }}
        {{ log('Create table '~view_name,true) }}
    {% endif %}

    {% if list|length < 1 %}
        {# /* create minimum necessary table if not exists */#}
        {% set minTableCreate %}
            create transient table if not exists {{ view_name }} as
                select null as object_name
                    ,null as object_test
                    ,null as object_gold
                    ,true as row_counts_match 
                from dual where 1=0
        {% endset %}
        {{ log(minTableCreate, verbose) }}
        {% do run_query(minTableCreate)%}
        {#/* Clear any results from previous run to avoid confusion */#}
        {% do run_query('truncate table if exists '~view_name) %}
    {% else %}
        {% do run_query(createCountQuery) %}
    {% endif %}

{% endmacro %}



{#- /* End of File */ #}
