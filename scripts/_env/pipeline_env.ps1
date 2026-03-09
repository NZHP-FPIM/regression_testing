#######################################################################
#
#   Filename:   regression_config.ps1
#   Author:     Jared Church
#
#   Purpose:
#       sets up the environment used in regression.yml pipeline
#
#   Future Development:
#       This is really a first pass and probably need some further
#       tidy up/improvement, it effectively replaces _env.ps1 so
#       should handle some of the complexities of multiple environments
#       for acceptance/production processes and also multiple dev
#       environments
#
#######################################################################

# Debug Information
$PSVersionTable | out-string | write-debug

"Define cmdlets" | write-debug
. $PSScriptRoot/../includes/common_functions.ps1

# These are environment variables that are pretty
# standard for regression - note that DBT_TARGET
# will normally be overridden by the pipeline execution
$env:DBT_TARGET="fdp_regression"
$env:FPIM_UAT_ENABLED=$false
$env:TEMP='/tmp'

# These global variables should tend towards using
# global:bii for the purpose of grouping them
# together - but this needs a bunch of clean up
# and I'd like to decommission on-prem environment
# first as a way to reduce complexity.
$global:logFileDir="/tmp"
$global:repoBaseDir="$($env:REPO_BASE)"
$global:bii = @{
    repoBaseDir="$($env:REPO_BASE)"
    logFileDir="/tmp"
}


### End of File
