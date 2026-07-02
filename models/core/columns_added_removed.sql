with pass1 as (
    select
        *
        ,case
            when gold = 1 and test = 0 then 'removed'
            when gold = 0 and test = 1 then 'added'
        end as change
    from {{ ref('columns_in_database_s20') }}
    where gold != test
        and (split_part(test_table, '.', 1) ilike '%_PRESENT' or split_part(gold_table, '.', 1) ilike '%_PRESENT')
)

,pass2 as (
    select
        table_schema
        ,table_name
        ,column_name
        ,test_table
        ,gold_table
        ,count(change) as count_change
        ,max(change) as max_change
        ,max(case when test = 1 then data_type end) as data_type_becomes
        ,max(case when gold = 1 then data_type end) as data_type_was
        ,sum(test) as test
        ,sum(gold) as gold
    from pass1
    group by
        table_schema
        ,table_name
        ,column_name
        ,test_table
        ,gold_table

)

select
    table_schema
    ,table_name
    ,column_name
    ,data_type_was
    ,data_type_becomes
    ,test
    ,gold
    ,test_table
    ,gold_table
    ,case count_change when 1 then max_change else 'change' end as change
from pass2
