# Common Scripts Ready 

# local managed -> online environment as managed to downstream environments
# use this script to deploy the latest managed solution to downstream environments
# will not deploy the umanaged solution to the development environment, use Push-Module for that

$projectRoot = "$PSScriptRoot\.."
. "${projectRoot}\.scripts\Util.ps1"

# select deployment configuration
Write-Host ""
$deploymentConfig = Select-Deployment

# connect to the selected tenant
Write-Host ""
Write-Host "Connecting to tenant: $($deploymentConfig.Tenant)"
Connect-DataverseTenant -authProfile $deploymentConfig.Tenant

# Start the loop
do {
    # ask which type of ip
    Write-Host ""
    $ipType = Select-ItemFromList "cross-module", "modules"
    
    if ($ipType -ne "") {
        $baseFolder = "$projectRoot\$ipType"

        # determine target environment based on ipType
        if ($ipType -eq "cross-module") {
            $targetEnvKey = "GOV APPS"
            $targetEnv = $deploymentConfig.Environments."GOV APPS"
            Write-Host "Cross-module solutions will be deployed to: $targetEnv"
        } else {
            $targetEnvKey = "GOV ENTERPRISE APPS"
            $targetEnv = $deploymentConfig.Environments."GOV ENTERPRISE APPS"
            Write-Host "Module solutions will be deployed to: $targetEnv"
        }

        Write-Host ""
        Write-Host "Connecting to environment: $targetEnv"
        Connect-DataverseEnvironment -envName $targetEnv

        # ask for which module to deploy
        Write-Host ""
        $excludeFolders = "__pycache__", ".scripts"
        $folderNames = Get-ChildItem -Path "$projectRoot\$ipType" -Directory -Exclude $excludeFolders | Select-Object -ExpandProperty Name
        $module = Select-ItemFromList $folderNames

        if ($module -ne "") {
            # The Deploy-Solution function expects just the relative path from .config folder
            # It will construct the full path itself using Join-Path $PSScriptRoot '..\.config' $settingsFile
            $settingsRelativePath = "$($deploymentConfig.Tenant)\$targetEnvKey.json"
            Write-Host "Using settings relative path: $settingsRelativePath"
            
            # deploy the solution with the relative settings path
            Deploy-Solution "$baseFolder\$module" -Managed -AutoConfirm -Settings $settingsRelativePath
        }
    }
} while ($ipType -ne "" -and $module -ne "") # Continue looping until either selection is empty

Write-Host "Operation complete."
