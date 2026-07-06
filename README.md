# Regression Testing Package Documentation

## Overview

This repository contains a dbt-based regression testing framework designed to compare the behavior of a current test environment against a gold/reference environment.

## Important setup warning

Regression testing in this repository is not a plug-and-play local command. The workflow expects a working environment that can provide secrets, database access, and pipeline variables before the clone and dbt stages can start. This process has been used alongside Azure Devops Pipelines.

Before using this package, make sure you have:

- a valid dbt profile in ~/.dbt/profiles.yml
- access to the source and target Snowflake databases
- permission to create or clone databases and apply grants
- a working Python environment and PowerShell runtime
- the required Azure DevOps or shell environment variables
- snowflake service account secrets

> Warning: If these prerequisites are missing, the regression run will fail before the actual dbt work begins. The example pipeline relies on these values being present in the environment or pipeline variable configuration.

## What the package does

The regression flow typically performs the following steps:

1. Clone a source database into a regression target database.
2. Run dbt operations for versioning and artifact capture.
3. Run ingest and transform dbt builds.
4. Execute built-in self tests.
5. Build regression comparison models and summarize differences.

## Repository structure

Key areas of the repository include:

- [macros](macros) — reusable dbt macros for cloning, versioning, regression comparisons, and environment toggles
- [models](models) — regression comparison models and staged data models
- [tests](tests) — built-in self-test SQL checks
- [scripts](scripts) — PowerShell automation for setup and regression execution
- [dbt_project.yml](dbt_project.yml) — dbt project configuration

## Prerequisites

Before using this package, the following should be available:

- dbt installed and configured
- Python with a virtual environment support
- PowerShell (for the .ps1 automation scripts)
- Network and access to the target data warehouse environment
- Appropriate database roles/permissions to clone databases and create objects
- A valid dbt profile for the project

## Required environment and configuration

### dbt profile

The project expects a dbt profile named `fdp_regression`.

A working dbt profile should be available at:

- `~/.dbt/profiles.yml`

### Environment variables

The regression scripts rely on several environment variables and values, including:

- `REGRESSION_QA_DB` — source database for non-prod regression runs
- `REGRESSION_PROD_DB` — source database for prod regression runs
- `DBT_REGRESSION_FROM_DB` — resolved source database used by the regression logic
- `FPIM_UAT_ENABLED` — toggles inclusion of FPIM UAT data in some flows

### Supporting configuration files

The setup script expects supporting configuration files and environment-specific helpers to be available. The repository scripts reference files such as:

- dbt profile templates
- Snowflake configuration templates
- Python requirements files
- environment-specific PowerShell helper files

## Installation and setup

The package includes a setup script in [scripts/install.ps1](scripts/install.ps1) that is intended to:

- create or activate a Python virtual environment
- install required Python packages
- configure dbt profiles
- configure Snowflake-related environment settings

Typical setup steps are:

1. Ensure the required environment variables and profile files are in place.
2. Run the installation script from a PowerShell session.
3. Verify that dbt can connect to the intended warehouse.

## Running regression tests

The main regression automation is handled by [scripts/dbt-regression.ps1](scripts/dbt-regression.ps1) and exposed through [scripts/common_functions.ps1](scripts/common_functions.ps1).


### Common execution options

The scripts support options such as:

- `-prod` for using the prod database as the gold/reference source
- `-skipClone` to skip the clone step
- `-fullIngest` to run a full ingest process
- `-ingestTime` and `-transformTime` to delay parts of the run
- `-overrideTestBranch` for special prod workflow cases

## Important package behavior

### Clone behavior

The clone logic is implemented through dbt macros in [macros/clone_env/clone_db.sql](macros/clone_env/clone_db.sql) and [macros/clone_env/clone_db.yml](macros/clone_env/clone_db.yml).

This workflow:

- creates or refreshes a target database
- clones relevant schemas and objects from a source database
- applies role and permission changes
- runs upgrade/version steps after clone operations

### Regression comparison outputs

Regression results are produced through macros and models such as:

- [macros/test_regression/test_regression.sql](macros/test_regression/test_regression.sql)
- [models/core/_regression_summary.sql](models/core/_regression_summary.sql)
- [models/core/table_hash_compare.sql](models/core/table_hash_compare.sql)
- [models/core/columns_added_removed.sql](models/core/columns_added_removed.sql)
- [models/core/objects_added_removed.sql](models/core/objects_added_removed.sql)

These outputs help identify differences in rows, columns, object presence, and hash-based comparisons between environments.

### Built-in self tests (BIST)

The repository includes tests under [tests/bist](tests/bist) for checks such as:

- missing primary keys
- missing test cases
- disallowed columns or objects
- stale or unexpected objects
- timetravel-related expectations

## Operational requirements and constraints

- Prod regression runs validate that the local branch matches `origin/main` unless explicitly overridden.
- The package assumes the environment has the appropriate permissions for cloning and managing databases.
- Some pathways are environment-specific and may rely on external helper scripts or templates.
- The project contains comments indicating some technical debt, especially around database naming and regression object placement.

## Logging and outputs

The regression scripts create timestamped log directories and write detailed output for key execution phases. Logs and summary results are intended to support troubleshooting and audit review.


### Additions to dbt_project.yml

## Schema Configurations:

-- regression test is only defined in dev and acceptance environments, it should never
-- be enabled on PROD environment

  regression_testing:
    +schema: test_regression
    enabled: "{{ target.name not in ['fdp_prod'] | as_bool }}"
    core:
      +tags: ["regression_test"]
      +database: "{{ target.database }}_core"
    stage:
      +tags: ["regression_test_stage"]
      +database: "{{ target.database }}_stage"

-- Configuring Tests

data_tests:
  +database: "{{ target.database }}_core"
  hsnz_bii:
    +schema: TEST_AUDIT
  regression_testing:
    bist:
      +tags: ["bist"]
      +schema: TEST_BIST


## Variables to define from snowflake:

vars:
  prod_db: name of production database
  qa_db: name of uat database
  prod_role: name of production service account role
  qa_role: name of uat service account role
  dev_role: name of developer role

## Recommended usage checklist

Before running regression testing, confirm that:

- the dbt profile is valid
- the target warehouse is reachable
- source and target databases are accessible
- you are checkout out on the correct branch to test
- permissions for clone and object creation are available
- variables defined in dbt_project.yml


## Summary

This package is a specialized dbt regression framework for validating warehouse changes against a known-good reference environment. It is most useful in environments where repeatable, database-level regression checks are required before promoting changes.
