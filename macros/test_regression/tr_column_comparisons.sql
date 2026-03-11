{# /*
--  Filename: tr_column_comparisons.sql
--  Author: Badi James <badi.james@healthsourcenz.co.nz , badij@acumenbi.co.nz>
--
--  Purpose:
--      Creates a view that finds the mismatching columns and provides summary stats
--      on both the gold and test version of the columns for each object where the test 
--      version does not match the gold version, but the record counts and the primary
--      key columns do match.

--  Notes:
--      Refers to the object created by tr_pk_len_comparisons, which in turn refers to 
--      the object created by tr_table_comparisons, to find mismatched objects where the 
--      record counts and the primary key columns do match, hence should be run in order: 
--      tr_table_comparisons -> tr_pk_len_comparisons -> tr_column_comparisons

--  Development:
--      Add in a count_not_unknown values - seeing this as zero does indicate something
--      really useful and could be used to generate warnings that should be addressed.
--      These are either unnecessary columns, or errors.

-- Tech Debt:
--      Currently contains a hack in that it assumes DBT_WAREHOUSE is the schema that it's
--      testing, always and only. This should be fixed by including schema name
--      in the object passed by row_count_view.
*/ #}

{% macro tr_column_comparisons(row_count_view='DBT_TEST_REGRESSION.row_count_pk_compare', target_view='DBT_TEST_REGRESSION.column_compare', verbose=false) %}

    {% set regression_db = regression_testing.get_regression_db() %}
    {% set target_view = regression_db~'.'~target_view %}
    {% set row_count_view = regression_db~'.'~row_count_view %}

    {# /* Create target table to popluate with summary stats */ #}
    {% set target_create_ddl %}
        create or replace transient table {{ target_view }} (
            object_name text
            , object_test text
            , object_gold text
            , column_name text
            , stat_name text
            , test_stat_value number
            , gold_stat_value number
        )
    {% endset %}
    {{ log(target_create_ddl, verbose) }}
    {% do run_query(target_create_ddl) %}

    {# /* Get the mismatched tables where the row counts match */ #}
    {% set row_match_query %}
        select
            object_name
            , object_test
            , object_gold
        from
            {{ row_count_view }}
        where
            row_counts_match
    {% endset %}
    {{ log(row_match_query, verbose) }}

    {% set mismatch_list = run_query(row_match_query) %}

    {# /* for each mismatched table... */ #}
    {% for entry in mismatch_list %}
        {{log('Mismatch List: '~entry,verbose)}}
        {% set object_name = entry[0] %}
        {% set object_test = entry[1] %}
        {% set object_gold = entry[2] %}

        {# /* Get their columns from columns_in_both */ #}
        {% set column_query %}
            select distinct
                column_name
            from
                {{ ref('columns_in_both') }}
            where
                table_name = '{{ object_name }}'
                {#- /*
                    This is a hack, it should really be information passed in the source table
                    and used such that we can confirm what it is. In reality the testing is
                    only done against DBT_WAREHOUSE today, so this hack should be ok
                */ -#}
                and SPLIT_PART(test_table, '.', 1) ilike '%_CORE'
                and table_schema not in ('INFORMATION_SCHEMA' ,'INFO_HS' ,'PUBLIC' ,'DBT_TEST_REGRESSION' ,'DBT_TEST_AUDIT' ,'DBT_TEST_BIST')
        {% endset %}
        {{ log(column_query, verbose) }}
        {% set column_result = run_query(column_query) %}
        {% set column_list = [] %}
        {% for r in column_result %}{% do column_list.append(r[0]) %}{% endfor %}

        {# /* variables used to construct the query for the following steps */ #}
        {% set include_regression = '_INCLUDE_REGRESSION' in column_list %}
        {% set hash_select %}
            {%- for col in column_list -%}
                hash_agg("{{ col }}") as "{{ col }}"{% if not loop.last %},{% endif %}
            {% endfor %}
        {% endset %}
        {% set col_select %}
            {%- for col in column_list -%}
                "{{ col }}"{% if not loop.last %},{% endif %}
            {% endfor %}
        {% endset %}

        {% set mismatch_cols_query %}
            {# /* take the hash of each column from both test and gold */ #}
            with hash_gold as (
                select
                    {{ hash_select }}
                from
                    {{ object_gold }}
                {% if include_regression %}
                    where
                        _include_regression = 1
                {% endif %}
            )

            , hash_test as (
                select
                    {{ hash_select }}
                from
                    {{ object_test }}
                {% if include_regression %}
                    where
                        _include_regression = 1
                {% endif %}
            )

            , unpivot_gold as (
                select
                    *
                from
                    hash_gold unpivot(
                        gold_hash_value
                            for column_name in (
                                {{ col_select }}
                            )
                    )
            )

            , unpivot_test as (
                select
                    *
                from
                    hash_test unpivot(
                        test_hash_value
                            for column_name in (
                                {{ col_select }}
                            )
                    )
            )

            {# /* compare hash between test and gold to find mismatch columns */ #}
            , combined as (
                select
                    gold.column_name
                    , gold.gold_hash_value
                    , test.test_hash_value
                    , gold.gold_hash_value = test.test_hash_value as column_match
                from
                    unpivot_gold as gold
                left join
                    unpivot_test as test
                    on
                        gold.column_name = test.column_name
            )

            select
                column_name
            from
                combined
            where
                not column_match
        {% endset %}
        {{ log(mismatch_cols_query, verbose) }}
        {% set mismatch_cols_result = run_query(mismatch_cols_query) %}
        {% set mismatch_cols = [] %}
        {% for r in mismatch_cols_result %}{% do mismatch_cols.append(r[0]) %}{% endfor %}

        {# /* variables used to construct the query for the following steps */ #}
        {% set select_summary_stats %}
            {% for col in mismatch_cols %}
                count(distinct {{ col }})::INT as count_distinct__{{ col }},
                count_if({{ col }} is not null)::INT as count_not_null__{{ col }},
                count_if({{ col }} is null)::INT as count_null__{{ col }},
                count_if({{ col }} != '0')::INT as count_not_zero__{{ col }},
                count_if({{ col }} = '0')::INT as count_zero__{{ col }}{% if not loop.last %},{% endif %}
            {% endfor %}
        {% endset %}
        {% set summary_stat_list %}
            {% for col in mismatch_cols %}
                count_distinct__{{ col }},
                count_not_null__{{ col }},
                count_null__{{ col }},
                count_not_zero__{{ col }},
                count_zero__{{ col }}{% if not loop.last %},{% endif %}
            {% endfor %}
        {% endset %}

        {% set summary_query %}
            {# /* create query for summary stats on mismatched columns for both test and gold */ #}
            with summary_gold as (
                select
                    'GOLD' as source,
                    {{ select_summary_stats }}
                from
                    {{ object_gold }}
                {% if include_regression %}
                    where
                        _include_regression = 1
                {% endif %}
            )

            , summary_test as (
                select
                    'TEST' as source,
                    {{ select_summary_stats }}
                from
                    {{ object_test }}
                {% if include_regression %}
                    where
                        _include_regression = 1
                {% endif %}
            )

            {# /* unpivot and join summary stat results */ #}
            , unpivot_gold as (
                select
                    source
                    , stat_name
                    , gold_stat_value
                from
                    summary_gold unpivot(
                        gold_stat_value
                            for stat_name in (
                                {{ summary_stat_list }}
                            )
                    )
            )

            , unpivot_test as (
                select
                    source
                    , stat_name
                    , test_stat_value
                from
                    summary_test unpivot(
                        test_stat_value
                            for stat_name in (
                                {{ summary_stat_list }}
                            )
                    )
            )

            select
                '{{ object_name }}' as object_name
                , '{{ object_test }}' as object_test
                , '{{ object_gold }}' as object_gold
                , split_part(gold.stat_name, '__', 2) as column_name
                , split_part(gold.stat_name, '__', 1) as stat_name
                , test_stat_value
                , gold_stat_value
            from
                unpivot_gold as gold
            left join
                unpivot_test as test
                on
                    gold.stat_name = test.stat_name
        {% endset %}

        {# /* Add summary stat results to target table */ #}
        {% set insert_query %}
            insert into {{ target_view }}
            {{ summary_query }}
        {% endset %}

        {% if mismatch_cols|length == 0 %}
            {{ log('No columns to compare', verbose) }}
        {% else %}
            {{ log(insert_query, verbose) }}
            {% set res = run_query(insert_query) %}
            {{ log(target_view~' inserted '~res[0][0]~' row(s) from '~object_name~' summary',true) }}
        {% endif %}
    {% endfor %}

{% endmacro %}
