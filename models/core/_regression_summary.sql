{# /*

*/ #}


{{ config(
    materialized="view",
    schema="test_regression",
    post_hook="{{ print_query(query='select number_rows,test_name,category,test_details from '~this) }}",
    alias="regression_summary",
) }}

{#- /*
    materialized="table"
    probably switch over to a table for speed as this view is slow
    depends a bit on how I want to interact with it
    advantage of a view is that I don't have to ensure that it is built last after
    everything else & it's up to date when I query it
    advantage of a table is that it is fast to review
*/ -#}


with objects_added_removed as (
    select
        '{{ ref("objects_added_removed") }}' as test_name
        ,change as category
        ,count(*) as number_rows
    from {{ ref("objects_added_removed") }}
    group by change
)

,columns_added_removed as (
    select
        '{{ ref("columns_added_removed") }}' as test_name
        ,change as category
        ,count(*) as number_rows
    from {{ ref("columns_added_removed") }}
    group by change
)

,objects_in_both as (
    select
        '{{ ref("objects_in_both") }}' as test_name
        ,null as category
        ,count(*) as number_rows
    from {{ ref("objects_in_both") }}
)

,columns_in_both as (
    select
        '{{ ref("columns_in_both") }}' as test_name
        ,null as category
        ,count(*) as number_rows
    from {{ ref("columns_in_both") }}
)

,table_hash as (
    select
        '{{ ref("table_hash_compare") }}' as test_name
        ,case when match = true then 'match' else 'no match' end as category
        ,count(*) as number_rows
    from {{ ref("table_hash_compare") }}
    group by match
    order by match asc
)

,pk_compare as (
    select
        '{{ ref("primary_key_compare") }}' as test_name
        ,case when row_counts_match then 'match' else 'no match' end as category
        ,count(*) as number_rows
    from
        {{ ref("primary_key_compare") }}
    group by
        row_counts_match
    order by
        row_counts_match asc
)

,column_compare as (
    select
        '{{ ref("column_hash_compare") }}' as test_name
        ,'no_match' as category
        ,count(distinct object_name ,column_name) as number_rows
    from
        {{ ref("column_hash_compare") }}
)

,template as (
    select
        20 as row_order
        ,'{{ ref("objects_added_removed") }}' as test_name
    from dual
    union distinct
    select
        30 as row_order
        ,'{{ ref("columns_added_removed") }}' as test_name
    from dual
    union distinct
    select
        40 as row_order
        ,'{{ ref("objects_in_both") }}' as test_name
    from dual
    union distinct
    select
        50 as row_order
        ,'{{ ref("columns_in_both") }}' as test_name
    from dual
    union distinct
    select
        33 as row_order
        ,'{{ ref("table_hash_compare") }}' as test_name
    from dual
    union distinct
    select
        60 as row_order
        ,'{{ ref("primary_key_compare") }}' as test_name
    from dual
    union distinct
    select
        70 as row_order
        ,'{{ ref("column_hash_compare") }}' as test_name
    from dual
)

select
    b.number_rows
    ,b.category
    ,a.row_order
    ,initcap(replace(split_part(a.test_name ,'.' ,3) ,'_' ,' ')) as test_name
    ,'select * From ' || a.test_name || ';' as test_details
from template as a
full outer join (
    select
        test_name
        ,category
        ,number_rows
    from (
        select
            test_name
            ,category
            ,number_rows
        from objects_added_removed
        union distinct
        select
            test_name
            ,category
            ,number_rows
        from columns_added_removed
        union distinct
        select
            test_name
            ,category
            ,number_rows
        from objects_in_both
        union distinct
        select
            test_name
            ,category
            ,number_rows
        from columns_in_both
        union distinct
        select
            test_name
            ,category
            ,number_rows
        from table_hash
        union distinct
        select
            test_name
            ,category
            ,number_rows
        from pk_compare
        union distinct
        select
            test_name
            ,category
            ,number_rows
        from column_compare
    )
) as b on b.test_name = a.test_name
order by a.row_order

{# /* End of File */ #}
