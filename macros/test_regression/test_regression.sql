{# /*
--  Filename:   test_regression.sql
--  Author:     Jared Church <jared.church@healthsourcenz.co.nz

--  Purpose:
--      Runs regression tasks
--
*/ #}

{% macro test_regression(
    target_table='DBT_TEST_REGRESSION.table_hash_test'
    ,verbose=false
) %}
    {% if execute %}
        {{ log("Row Comparisons",true) }}
        {{ tr_row_comparisons(verbose=false) }}
        {{ log("Table Comparisons",true) }}
        {{ regression_testing.tr_table_comparisons(target_table=target_table,verbose=false) }}
    {% endif %}
{% endmacro %}


{# End of File #}
