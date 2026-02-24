# $DebugPreference='Continue'
#######################################################################
#
#   Filename: install.ps1
#   Author:   Jared Church
#
#   Purpose:  does needed software installs
#
#######################################################################



. $PSScriptRoot\..\vault.ps1
. $PSScriptRoot\set-secrets.ps1
. $PSScriptRoot\set-netskope-env.ps1

function config-env() {
    param (
        $reqFile,
        $logDir
    )

    . $PSScriptRoot\lock-file.ps1

    # This is only dev environment - maybe acc/prod in future but this is 
    if ( -not @('VHAL1QLK001','VHAL1QLK003').contains($env:COMPUTERNAME) ) {
        "Set up netskope" | write-debug
        set-netskope-env
    }

    install-software -reqFile $reqFile

    set-secrets
    if ( test-fileage -file "$($logDir)\deprecation.log" ) {
        $fs=lock-file -file "$($logDir)\deprecation.log"
        warn-deprecated | tee-object "$($logDir)\deprecation.log"
        lock-file -ReleaseLock $fs
    }

}

function test-fileage() {
    param (
        $file,
        $maxAgeMins = 5,
        [switch] $aged = $false # allows to force response
    )

    if ( Test-Path $file ) {
        if ( ((get-date) - (get-item $file).LastWriteTime ) -gt (new-timespan -minutes $maxAgeMins) ) {
            $aged = $true
        }
    } else {
        # if file doesn't exist set the to extremely old
        $aged=$true
    }

    return $aged
}

function python-venv() {
    param (
        $logDir
    )
    
    "{0,-6} {1}" -f  "Start:",$MyInvocation.MyCommand.Name | write-debug
    # set this variable here, will be overwitten by Python Activate script, this code will prevent a powershell
    # error from occuring
    if ( -Not ( Test-Path variable:global:_PYTHON_VENV_PROMPT_PREFIX ) ) {
        Set-Variable -Name "_PYTHON_VENV_PROMPT_PREFIX" -Value 'test' -Scope Global
    }

    if ( -not ( test-path ".venv\Scripts\Activate.ps1" )) {
        write-warning "Creating new dev environment."
        python -m venv "$($Global:repoBaseDir)\.venv" | out-file "$($logDir)\python_venv.log"
    }

    . "$($Global:repoBaseDir)\.venv\Scripts\Activate.ps1"
    "{0,-6} {1}" -f  "End:",$MyInvocation.MyCommand.Name | write-debug

}



function warn-deprecated() {
    $deprecatedList=@("$($HOME)/.snowsql/passphrase.ps1", "$($HOME)/.ssh/proxy.ps1")

    $deprecatedList | foreach {
        if ( Test-Path $_ ) {
            write-output "*** Warning *** Please remove deprecated file - should no longer be in use"
            write-output "> remove-item $_"
        }
    }

    if ( git config --global --list | select-string proxy ) {
        write-host "Modify git config - remove proxy settings and replace with: (only applicable with netskope installed)"
        write-host @"
[http]
    sslBAckend = schannel
"@

        write-host "Command> git config --global --edit"
    }

}

function install-software() {
    # probably change this to just try the pip installs every time
    # they seem pretty quick now
    param (
        $reqFile
    )

    "pip install" | write-debug

    # tests whether there is anything in requirements.txt that is not already installed
    pip freeze | out-file -encoding ascii "$($env:TMP)\requirements.txt"
    if ( (get-item "$($env:TMP)\requirements.txt").length -ne 0 ) { 
        $test=compare-object -DifferenceObject (get-content "$($env:TMP)\requirements.txt" | sort-object) `
            -ReferenceObject (get-content $reqFile | sort-object) `
            | where-object -Property SideIndicator -eq "<="
    } else {
        # force install if no results in pip freeze
        $test=1
    }


    if ( $null -ne $test ) {
        write-warning "Installing Software. Please be patient, this will take a few minutes."
        # pip upgrade
        write-warning "Python venv: $($Global:repoBaseDir)\.venv"
        write-warning "pip upgrade"
        & "$($Global:repoBaseDir)\.venv\Scripts\python.exe" -m pip install --upgrade pip

        # pip-system-certs is required to allow python to trust the system certificates
        write-warning "pip install certs"
        pip install --upgrade --trusted-host pypi.org --trusted-host files.pythonhosted.org pip-system-certs==4.0

        # all other software
        write-warning "pip install $($reqFile)"
        pip install --upgrade -r $reqFile

    }
}

function config-dbt() {
    param (
        $profileFile
    )

    write-debug "dbt profiles Template Found: $(test-path $profileFile)"

    "dbt profiles" | write-debug
    New-Item -Force -Path "$($HOME)/.dbt" -ItemType Directory | out-null

    if ( -Not ( Test-Path "$($HOME)/.dbt/profiles.yml" ) ) {
        "Creating dbt profiles.yml" | write-warning
        copy-item $profileFile "$($HOME)/.dbt/profiles.yml"
    }
}

. "$($PSScriptRoot)/config-snowflake.ps1"

####################### SCRIPT #######################
set-location $global:repoBaseDir

if ( (git config core.editor) -eq "" ) {
    git config --global core.editor notepad.exe
}


python-venv -logDir "./.logs"
config-env -logDir "./.logs" -reqFile $global:bii.python_requirements_file
config-dbt -profileFile $global:bii.template_dbt_profiles
config-snowflake -configFile $global:bii.template_snowsql_config

### End of File
