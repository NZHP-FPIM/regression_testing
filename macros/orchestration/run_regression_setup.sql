-- Regression setup: clone production DB and run upgrade, with branch-derived target DB
-- Co-authored with CoCo
{# /*
--  Filename: run_regression_setup.sql
--
--  Purpose:
--      Replaces the PowerShell clone-db + upgrade steps.
--      Derives the target database name from the git branch (via env var)
--      so each feature branch gets its own isolated regression database.
--
--      Call via: dbt run-operation run_regression_setup
--
--      Optionally override source database:
--        dbt run-operation run_regression_setup --args "{ from_db: PROD }"
--
--      For production regression (clone from prod):
--        dbt run-operation run_regression_setup --args "{ use_prod: true }"
--
--  Branch-derived database naming:
--      Uses env var DBT_CLOUD_GIT_BRANCH (dbt Cloud CI) or GIT_BRANCH (generic).
--      Produces: regression_<from_db>_<sanitized_branch_name>
--      e.g., branch "feature/my-fix" with from_db "PROD" → "REGRESSION_PROD_FEATURE_MY_FIX"
--
--      If no branch env var is set, falls back to target.database from the profile.
*/ #}

{% macro run_regression_setup(from_db=none, use_prod=none, skip_clone=none, verbose=false) %}

    {# /* Resolve parameters from vars if not explicitly passed */ #}
    {% set use_prod = use_prod if use_prod is not none else var('regression_use_prod', false) %}
    {% set skip_clone = skip_clone if skip_clone is not none else var('regression_skip_clone', false) %}

    {% if from_db is none %}
        {% if use_prod %}
            {% set from_db = var('prod_db') %}
        {% else %}
            {% set from_db = var('qa_db') %}
        {% endif %}
    {% endif %}

    {# /* Derive branch-specific target database name */ #}
    {% set to_db = regression_testing.get_regression_target_db(from_db=from_db) %}

    {{ log('=== Regression Setup ===', true) }}
    {{ log('from_db: ' ~ from_db, true) }}
    {{ log('to_db: ' ~ to_db, true) }}
    {{ log('use_prod: ' ~ use_prod, true) }}
    {{ log('skip_clone: ' ~ skip_clone, true) }}

    {# /* Step 1: Clone the database family */ #}
    {% if not skip_clone %}
        {{ log('--- Step 1: Clone Database ---', true) }}
        {{ clone_db(from_db=from_db, to_db=to_db, verbose=verbose) }}
    {% else %}
        {{ log('--- Step 1: Clone Database SKIPPED ---', true) }}
    {% endif %}

    {{ log('=== Regression Setup Complete ===', true) }}

{% endmacro %}


{% macro get_regression_target_db(from_db=none) %}
    {# /*
    --  Derives the regression target database name from the git branch.
    --  Checks env vars in order:
    --    1. DBT_CLOUD_GIT_BRANCH (dbt Cloud CI jobs)
    --    2. GIT_BRANCH (generic CI/CD or local override)
    --    3. BUILD_SOURCEBRANCHNAME (Azure DevOps - matches original PowerShell)
    --  Falls back to target.database if no branch env var is available.
    --
    --  Naming convention: REGRESSION_<FROM_DB>_<SANITIZED_BRANCH>
    --  Sanitization: replaces non-alphanumeric chars with underscores, uppercases.
    */ #}

    {% set branch = env_var('DBT_CLOUD_GIT_BRANCH', '') %}
    {% if not branch %}
        {% set branch = env_var('GIT_BRANCH', '') %}
    {% endif %}
    {% if not branch %}
        {% set branch = env_var('BUILD_SOURCEBRANCHNAME', '') %}
    {% endif %}

    {% if branch %}
        {# /* Sanitize branch name: replace non-alphanumeric with underscore */ #}
        {% set sanitized = modules.re.sub('[^a-zA-Z0-9]', '_', branch) %}
        {% set to_db = 'REGRESSION_' ~ from_db ~ '_' ~ sanitized | upper %}
        {{ log('Derived regression DB from branch "' ~ branch ~ '": ' ~ to_db, true) }}
    {% else %}
        {# /* No branch env var available — fall back to profile target database */ #}
        {% set to_db = env_var('DBT_TARGET_DB') %}
        {{ log('No branch env var found, using target.database: ' ~ to_db, true) }}
    {% endif %}

    {{ return(to_db) }}

{% endmacro %}
