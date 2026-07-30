{#- /*
--  Filename: get_regression_db.sql
--  Author: Jared Church

--  Purpose:
--      Returns the name of the regression database where comparison
--      objects are stored (the _core suffixed database).
--
--      Derives the base database name from get_regression_target_db
--      (branch-aware) so the naming logic is in one place.
--
--      Falls back to target.database if no branch env var is set.

--  Technical Debt
--      none known

*/ -#}


{% macro get_regression_db(verbose=false) %}

    {% set base_db = regression_testing.get_regression_target_db(from_db=var('qa_db')) %}
    {% set regression_db = base_db ~ '_core' %}
    {{ log('Regression DB: ' ~ regression_db, verbose) }}
    {% set res = run_query('create database if not exists ' ~ regression_db) %}
    {{ return(regression_db) }}

{% endmacro %}


{#- /* End of File */ #}
