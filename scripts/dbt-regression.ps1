function dbt-regression() {
    <#
    .SYNOPSIS
    runs our regression test
    .DESCRIPTION
    - clones the database
    - runs a dbt build (transform selector)
    - builds regression test objects

    - Does not do ingest, or exposures
    #>
    param (
        $transformSelector="transform",
        [switch] $skipClone,
    #    [switch] $cloneOnly,
        [switch] $prod,
        [switch] $fullIngest=$false,
        [switch] $overrideTestBranch,
        $ingestTime=$null,
        $transformTime=$null,
        $DebugPreference = 'SilentlyContinue'
    )

    . $PSScriptRoot/bii-log-message.ps1
    . $PSScriptRoot/delay-until.ps1
    . $PSScriptRoot/test-branch.ps1

    if ( $prod ) {
        $env:DBT_REGRESSION_FROM_DB = $env:REGRESSION_PROD_DB
        if ( -not $overrideTestBranch ) { 
            try { 
                test-branch -branch "origin/main"
            } catch {
                $continue=read-host "PROD Regresion not running against origin/main. Continue (y/N)"
                if ( "$($continue)".toLower() -ne "y" ) {
                    stop-transcript
                    throw $_
                }
            }
        }
    } else {
        $env:DBT_REGRESSION_FROM_DB = $env:REGRESSION_QA_DB
    }

    $transformSelectorExclTest="$($transformSelector)_exclude_tests"
    $logDir="$($global:logFileDir)/regression/$(get-date -Format 'yyyyMMdd_HHmmss')"
    New-Item -type directory $logDir -Force > $null

    log-information | tee-object -FilePath "$($logDir)/01_key_information.txt"
    clone-db | tee-object -FilePath "$($logDir)/01_cloning.txt"

    if ( -Not $cloneOnly ) {

        dbt-execution | tee-object -FilePath "$($logDir)/03_dbt_execution.txt"
        
        summary-output | tee-object -FilePath "$($logDir)/04_summary_output.txt"

        bii-log-message "Logs Stored Directory: $($logDir)"

        $env:DBT_REGRESSION_FROM_DB=$null
    }
}

function clone-db() {
    if ( -Not $skipClone ) {
        bii-log-message -message "### Clone"
        ### Need to add here something that selects prod as clone from and my dev as clone to
        dbt run-operation clone_db --args "{ from_db: $($env:DBT_REGRESSION_FROM_DB), verbose: true }"
    } else {
        bii-log-message -message "### Clone Skipped"
    }
}

function dbt-execution() {
    bii-log-message -message "### DB Upgrade"
    dbt run-operation upgrade_version

    bii-log-message -message "### DBT Artifacts"
    dbt run --select dbt_artifacts --vars "{'on_run_end_selector': 'regression: dbt_artifacts'}"

    bii-log-message -message "### Ingest"
    delay-until -date $ingestTime
    if ( $fullIngest ) {
        dbt build --select ./models/ingest --vars "{'on_run_end_selector': 'regression: ingest'}"
    } else {
        dbt build --select ./models/ingest --exclude ./models/ingest/ebs --vars "{'on_run_end_selector': 'regression: ingest'}"
    }

    bii-log-message -message "### Transform"
    delay-until -date $transformTime
    dbt build --selector $transformSelectorExclTest --vars "{'on_run_end_selector': 'regression: $($transformSelectorExclTest)'}"

    bii-log-message -message "### Built In Self Test"
    dbt test --selector $transformSelector --vars "{'on_run_end_selector': 'regression: $($transformSelector) - BIST'}"

    bii-log-message -message "### Regression Results"
    dbt build --selector regression --vars "{'on_run_end_selector': 'regression'}"


}

function log-information() {
    bii-log-message -message "Execution Dir: $((Get-Item .).FullName)"
    bii-log-message -message "Log Directory: $($logDir)"

    git branch --list (git rev-parse --abbrev-ref HEAD) -vv
    git log -1 $repoBaseDir
    git status
    
    bii-log-message -message "transformSelector = $($transformSelector)"
    bii-log-message -message "skipClone = $($skipClone)"
    bii-log-message -message "DBT_REGRESSION_FROM_DB = $($env:DBT_REGRESSION_FROM_DB)"
    bii-log-message -message "UAT enabled: env:FPIM_UAT_ENABLED=$($env:FPIM_UAT_ENABLED)"
    bii-log-message -message "logDir = $($logDir)"
    bii-log-message -message "Only does regression for transform, does not handle ingest or exposures"

}

function summary-output() {
    # standard database name extended with this for running these queries
    # I feel like this is a it messy and carries some tech debt around
    # the places that regrssion db name is defined - probably a risk area
    # and something that needs some clean up
    $regressionDB_ext="_core"

    $querySummary="select NUMBER_ROWS,TEST_NAME,CATEGORY,TEST_DETAILS from DBT_test_regression.regression_summary"
    $querySummaryNote='Regression Summary'
    $queryTableHash="select OBJECT_TEST from DBT_test_regression.TABLE_HASH_COMPARE where match = false"
    $queryTableHashNote='Table Hash Compare - Not match'
    $queryObjects="select TABLE_SCHEMA,TABLE_NAME,CHANGE From DBT_test_regression.objects_added_removed where table_schema like ''DBT_DM_%''"
    $queryObjectsNote='Changed Objects - Presentation Layer'
    $queryColumns="select TABLE_SCHEMA,TABLE_NAME,COLUMN_NAME,CHANGE,DATA_TYPE_WAS,DATA_TYPE_BECOMES From DBT_test_regression.columns_added_removed where table_schema like ''DBT_DM_%'' order by 1,2,3"
    $queryColumnsNote='Changed Columns - Presentation Layer'


    dbt run-operation echo_query_res --args "{ query: '$($querySummary)',   note: '$($querySummaryNote)', db_ext: '$($regressionDB_ext)' }" --quiet
    write-output ""
    dbt run-operation echo_query_res --args "{ query: '$($queryTableHash)',   note: '$($queryTableHashNote)', db_ext: '$($regressionDB_ext)' }" --quiet
    write-output ""
    dbt run-operation echo_query_res --args "{ query: '$($queryObjects)',   note: '$($queryObjectsNote)', db_ext: '$($regressionDB_ext)' }" --quiet
    write-output ""
    dbt run-operation echo_query_res --args "{ query: '$($queryColumns)',   note: '$($queryColumnsNote)', db_ext: '$($regressionDB_ext)' }" --quiet
    write-output ""
}

### End of File
