{#- /*
--  Filename: expected_cases_s10.sql
--  Author: Jared Church <jared.church@healthsourcenz.co.nz>

--  Purpose:
--      Defines the expected standard test cases
--      Test cases are defined against a table type and column type
--      support test cases for text data types, primary and foreign keys

--  Primary Key:
--      a.table_schema ,a.table_name ,a.column_name ,e.test_type

--  Technical Debt
--      there is some question of the boolean
--      test being not_null (defined in reference file)
--      should the unknown row of a dim being not
--      null - for a fact I think it should be not null
--      just the unknown row of a dim that is in question

--  History
--      2024-04-16: churchj2: Was missing expected cases if a column
--                            didn't exist (e.g. skey not there).
--                            This resolves that.

*/ -#}

{{ config(
    materialized="view",
    tags=["must_be_view"],
) }}

{% set std_cols %}
    a.table_catalog
    ,a.table_schema
    ,a.table_name
    ,a.column_name
    ,concat_ws('.' ,a.table_catalog ,a.table_schema ,a.table_name) as object_full_name
{% endset %}



with foreign_keys as (
    select
        {{ std_cols }}
        ,'foreign_key' as key_type
        ,split_part(a.table_name ,'_' ,1) as table_type
    from {{ source('target_info_schema','columns') }} as a
    where
        a.column_name != concat('SKEY_' ,a.table_name)
        and (a.column_name like 'SKEY_%'
            or a.column_name like '%_KEY')
        and a.table_schema like 'DBT_DM_%'
    {# /* only apply to data model objects */ #}
)

,primary_keys as (
    select
        {{ std_cols }}
        ,'primary_key' as key_type
        ,split_part(a.table_name ,'_' ,1) as table_type
    from {{ source('target_info_schema','columns') }} as a
    where
        a.column_name = concat('SKEY_' ,a.table_name)
        and a.table_schema like 'DBT_DM_%'
    {# /* only apply to data model objects */ #}
)

,attributes as (
    select
        {{ std_cols }}
        ,a.data_type as key_type
        ,split_part(a.table_name ,'_' ,1) as table_type
    from {{ source('target_info_schema_core','columns') }} as a
    where
        a.table_schema not in ('INFORMATION_SCHEMA' ,'INFO_HS' ,'PUBLIC' ,'DBT_TEST_REGRESSION' ,'DBT_TEST_AUDIT' ,'DBT_TEST_BIST')
        and not (a.column_name like 'SKEY_%'
            or a.column_name like '%_KEY')
        and a.data_type in ('TEXT' ,'BOOLEAN')
)

,editioning as (
    select
        {{ std_cols }}
        ,'editioning' as key_type
        ,'EDITIONING' as table_type
    from {{ source('target_info_schema','columns') }} as a
    where
        a.table_schema like ('DBT_INGEST%')
        {%- if not is_enabled_fpim_uat() %}
            and a.table_schema not in ('DBT_INGEST_EBS_FPIM_UAT')
        {% endif -%}
        and a.column_name = 'ZD_EDITION_NAME'
)

,ssid as (
    select
        {{ std_cols }}
        ,'ssid' as key_type
        ,'ingest' as table_type
    from {{ source('target_info_schema','columns') }} as a
    where
        a.table_schema like ('DBT_INGEST_EBS%')
        {%- if not is_enabled_fpim_uat() %}
            and a.table_schema not in ('DBT_INGEST_EBS_FPIM_UAT')
        {% endif -%}
        and a.column_name = 'SSID'
)

,all_objects as (
    select * from foreign_keys
    union all
    select * from primary_keys
    union all
    select * from attributes
    union all
    select * from editioning
    union all
    select * from ssid
)

{# /* Defines the expected case based on reference data file */ #}
,expected_cases as (
    select * from {{ ref('dbt_expected_test_types') }}
)
/*
,exceptions as (
    select
        *
        ,true as exclude_case
    from 'EXPECTED_TEST_CASES_EXCEPTION_LIST'

)
 */
select
    a.table_catalog
    ,a.table_schema
    ,a.table_name
    ,a.column_name
    ,e.test_type
    ,a.object_full_name
    ,e.table_type
    ,a.key_type
  --  ,coalesce(ex.exclude_case ,false) as exclude_case
from expected_cases as e
inner join all_objects as a
    on
        a.table_type = e.table_type
        and a.key_type = e.key_type
        /*
left join exceptions as ex
    on
        ex.table_schema = a.table_schema
        and ex.table_name = a.table_name
        and ex.column_name = a.column_name
        and ex.test_type = e.test_type
*/




{#- /* End of File */ #}
