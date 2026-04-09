{#- /*
--  Filename: objects_in_database_s20.sql
--  Author: Jared Church

--  Purpose:
--      Purpose

--  Technical Debt
--      none known

*/ -#}

with base as (
    select
        b.table_schema
        ,b.table_catalog
        ,b.table_name
        ,b.table_type
        ,b.test
        ,b.gold
        ,concat_ws('.' ,b.table_catalog ,b.table_schema) as full_schema_name
        ,concat_ws('.' ,b.table_catalog ,b.table_schema ,b.table_name) as full_table_name
    from {{ ref('objects_in_database_s10') }} as b
)


select
    a.table_schema
    ,a.table_name
    ,sum(a.test) as test
    ,sum(a.gold) as gold
    ,max(case
        when a.test = 1 then concat_ws(' ' ,'drop' ,a.table_type ,'') || a.full_table_name || ';'
    end) as drop_test_table
    ,max(case
        when a.test = 1 then 'drop schema ' || a.full_schema_name || ';'
    end) as drop_test_schema
    ,max(case when a.gold = 1 then a.full_table_name end) as gold_table_name
    ,max(case when a.test = 1 then a.full_table_name end) as test_table_name
from base as a
where
    a.table_catalog not like '%_STAGE'
    and a.table_schema not like 'DBT_TEST%'
    and a.table_schema not in ('INFORMATION_SCHEMA' ,'INFO_HS' ,'PUBLIC' ,'ROW_COMPARISON')
group by
    a.table_schema
    ,a.table_name



{#- /* End of File */ #}
