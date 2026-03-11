{# /*
--  Filename:   column_hash_compare.sql
--  Author:     Badi James < Badi.James@healthsourcenz.co.nz badij@acumenbi.co.nz >
--
--  Purpose:
--      This will use pre-hook to create a view that finds the mismatching columns and provides summary stats
--      on both the gold and test version of the columns for each object where the test 
--      version does not match the gold version, but the record counts and the primary
--      key columns do match.
--
--      gold_db = if target=acceptance then prod, else acceptance
--
*/ #}


{{ config(
    materialized="view",
    pre_hook="{{ 
        regression_testing.tr_column_comparisons(
            row_count_view=this.schema~'.primary_key_compare_b', 
            target_view=this.schema~'.'~this.name~'_b'
        ) 
    }}"
) }}

-- depends_on: {{ ref('primary_key_compare') }}
-- depends_on: {{ ref('columns_in_both') }}

select *
from
    {{ this }}_b
order by
    object_name
    ,column_name
    ,stat_name

{# /* End of File */ #}
