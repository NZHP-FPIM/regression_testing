param (
    [switch]$Prod,
    [switch]$SkipClone
)

# Compute branch-safe regression DB
$gitBranch = $env:BUILD_SOURCEBRANCHNAME
$regressionDB = "regression_$($env:REGRESSION_PROD_DB)_$($gitBranch -replace '[^a-zA-Z0-9]', '_')"
Write-Host "Regression DB: $regressionDB"

# Export as env var for downstream scripts / dbt
$env:DBT_DATABASE = $regressionDB

# Load additional environment setup
. "$PSScriptRoot/_env/pipeline_env.ps1"

if ( $env:PROD -eq $true ) { $prod=$true } else { $prod=$false }
if ( $env:SKIPCLONE -eq $true ) { $skipClone=$true } else { $skipClone=$false }

$params = @{
    prod              = $prod
    skipClone         = $skipClone
    overrideTestBranch = $prod
}

$params | Write-Output

# Call the orchestration function
bii-dbt-regression @params
