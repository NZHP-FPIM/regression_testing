#######################################################################
#
#   FileName:   common_functions.ps1
#   Author:     Jared Church <jared.church@healthsourcenz.co.nz>
#
#   Purpose:    Encapsulate common operations
#
#######################################################################

function global:bii-cloud-regression() {
    param (
        [switch]$dontAsk,
        [switch]$cloneOnly,
        [switch]$skipClone,
        [switch]$prod
    )

    "Running linting over files changed since main branch - require these be cleaned" | Write-Warning
    bii-sql-lint2

    git status
    write-output "########### Only Committed objects will be included in test"

    # Auto accept if dontask or cloneonly flags are set
    if ( $dontAsk ) {
        $continue='y'
    } else {
        $continue=Read-Host "Continue (Y/n)"
    }

    $gitBranch=(git branch --show-current)
    if ( $continue.toLower()[0] -eq "y" -or $continue -eq "" ) {

        write-output "az pipelines run --name `"Regression`" --branch $gitBranch"
        $data=az pipelines run --name "Regression" --branch $gitBranch --variables skipClone=$skipClone prod=$prod

        $id=($data | ConvertFrom-Json).id

        write-output "https://dev.azure.com/hsnzbii/bi/_build/results?buildId=$($id)&view=logs"
        if ( -not $env:CODESPACES ) {
            start-process "https://dev.azure.com/hsnzbii/bi/_build/results?buildId=$($id)&view=logs"
        
        }
    } else {
        write-debug "Stop Execution"
    }

}

function global:bii-dbt-regression() {
    <#
    .SYNOPSIS
    runs our regression test
    .DESCRIPTION
    - clones the database
    - runs a dbt build (transform selector)
    - builds regression test objects

    Arguments
     -prod          Use prod as the gold database not acceptance (default=acceptance)
     -Append        Will append to the log file rather than replacing it

     -fullIngest    Runs a full ingest process as part of regression (default=off)
     -ingestTime    Will delay the start of ingest actions until this time (timestamp object - get-date)
     -transformTime Will delay the start of transform actions until this time (timestamp object - get-date)

     -skipClone     Run without doing a fresh clone from gold database
     -transcriptOff Do no log regression.txt

     -transformSelector For testing purposes allow different selector than standard

     -overrideTestBranch -  Prod regressions expected to run against branch origin/main
                            and is tested - this allows an override that will stop
                            that testing
    #>
    param (
        $transformSelector="transform",
        [switch] $skipClone,
    #    [switch] $cloneOnly,
        [switch] $transcriptOff,
        [switch] $prod,
        [switch] $overrideTestBranch,
        [switch] $fullIngest=$false,
        $ingestTime=$null,
        $transformTime=$null,
        [switch] $Append
    )

    $startTime=get-date

    $transcript="./regression.txt"

    . $PSScriptRoot/other/dbt-regression.ps1

    if ( -Not $transcriptOff ) {
        $params=@{ Append = $Append }
        start-transcript @params $transcript
    }

    $params = @{
        transformSelector = $transformSelector
        skipClone = $skipClone
    #    cloneOnly = $cloneOnly
        prod = $prod
        overrideTestBranch = $overrideTestBranch
        fullIngest = $fullIngest
        ingestTime = $ingestTime
        transformTime = $transformTime
    }
    dbt-regression @params | Out-Default

    if ( -Not $transcriptOff ) {
        write-output "`n`n`n"
        write-output "Results Summary"
        write-output "==============="
        $res=Select-String ' INFO: ' $transcript
        $res+=Select-String 'Done. PASS=' $transcript
        ($res | Sort-Object LineNumber).Line
    }

    write-output ('Hours Taken: ' + [math]::round(((get-date)-$startTime).TotalHours,2))

    if ( -Not $transcriptOff ) {
        stop-transcript
    }

}


function write-message() {
    <#
    .SYNOPSIS
    Puts some formatting around logging steps in scripts
    .DESCRIPTION
    Includes a timestamp at start of line along with message
    Mainly this is done for consistency of logging message 
    #>
    param (
        [string] $message,
        [switch] $nonewline
    )

    write-host -NoNewLine ("[{0}]: {1}" -f (get-date),$message)
    if ( ! $nonewline ) {
        write-host ""
    }
}

function global:bii-dbt-fpim-uat() {
    <#
    .SYNOPSIS
    Sets up environment variable for enable/disable on fpim uat inclusion
    .DESCRIPTION
    Note that this is only valid in a dev/acceptance environment.
    This should always be disabled in prod.

    Default behaviour is to disable
    #>
    param ( 
        [switch]$off,
        [switch]$on
    )

    if ( $off ) {
        $env:FPIM_UAT_ENABLED=$null
    } else {
        $env:FPIM_UAT_ENABLED="True"
    }
}


function bii-dbt-missing-test-cases() {

    dbt build -s +./tests/bist/missing_test_cases.sql > $null 2>&1
    dbt build -s +./tests/bist/missing_test_cases.sql

}


function global:bii-identify-regression-build() {
    <#
    .SYNOPSIS
        Attempts to build a dbt command to do the minimum necessary build to
        support regression test.

        Will accept a specific commit to check against, or find the last commit
        which is common ancestor for current branch and main (noting warning) if
        latest on main (at midnight this morning) is different from that common
        ancestor

    .PARAMETER commit
        a git commit hash to use instead of searching for latest on main (before
        midnight last night)

    .PARAMETER excludePredecessors
        Controls whether build should run from after ingest objects forward or just
        from changed objects forward

    #>
    [CmdletBinding()]
    param (
        [string] $commit = $null,
        [switch] $excludePredecessors = $false
    )

    . $PSScriptRoot\other\identify-regression-build.ps1

    $params=@{
        commit = $commit
        excludePredecessors = $excludePredecessors
    }

    identify-regression-build @params
}

### End of File
