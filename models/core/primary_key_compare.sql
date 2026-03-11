{# /*
--  Filename:   primary_key_compare.sql
--  Author:     Badi James < Badi.James@healthsourcenz.co.nz badij@acumenbi.co.nz >
--
--  Purpose:
--      This will use pre-hook to create a view that compares row count and intersection 
--      of primary key values for each object where the test version does not match the 
--       gold version.
--
--      gold_db = if target=acceptance then prod, else acceptance
--
*/ #}


{{ config(
    materialized="view",
    pre_hook="{{ 
        regression_testing.tr_pk_len_comparisons(
            table_hash_test=this.schema~'.table_hash_compare_b', 
            target_view=this.schema~'.'~this.name~'_b'
        ) 
    }}"
) }}

-- depends_on: {{ ref('table_hash_compare') }}
-- depends_on: {{ ref('columns_in_both') }}

select *
from {{ this }}_b

{# /* End of File */ #}
