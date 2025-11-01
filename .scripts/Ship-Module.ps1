# Common Scripts Ready 

# local managed -> online environment as managed to a single dedicated demo tenant / environment
# use this script to deploy the latest managed solution to a single dedicated demo tenant / environment

$projectRoot = "$PSScriptRoot\.."
. "${projectRoot}\.scripts\Util.ps1"

# select deployment configuration
Write-Host ""
$deploymentConfig = Select-Deployment

# connect to the selected tenant
Write-Host ""
Write-Host "Connecting to tenant: $($deploymentConfig.Tenant)"
Connect-DataverseTenant -authProfile $deploymentConfig.Tenant

# allow user to select target environment from the deployment config
Write-Host ""
Write-Host "Available Environments:"
$envNames = $deploymentConfig.Environments.PSObject.Properties.Name
$selectedEnvKey = Select-ItemFromList $envNames
$targetEnv = $deploymentConfig.Environments.$selectedEnvKey

Write-Host ""
Write-Host "Connecting to environment: $targetEnv"
Connect-DataverseEnvironment -envName $targetEnv

# ask which type of ip once at the beginning
Write-Host ""
$ipType = Select-ItemFromList "cross-module", "modules"
$baseFolder = "$projectRoot\$ipType"

# Start the loop
do {
    # ask for which module to ship
    Write-Host ""
    $excludeFolders = "__pycache__", ".scripts"
    $folderNames = Get-ChildItem -Path "$projectRoot\$ipType" -Directory -Exclude $excludeFolders | Select-Object -ExpandProperty Name
    $module = Select-ItemFromList $folderNames

    if ($module -ne "") {
        # debug: show what we're working with
        Write-Host "Debug - deploymentConfig.Tenant: '$($deploymentConfig.Tenant)'"
        Write-Host "Debug - selectedEnvKey: '$selectedEnvKey'"
        
        # The Deploy-Solution function expects just the relative path from .config folder
        # It will construct the full path itself using Join-Path $PSScriptRoot '..\.config' $settingsFile
        $settingsRelativePath = "$($deploymentConfig.Tenant)\$selectedEnvKey.json"
        Write-Host "Using settings relative path: $settingsRelativePath"
        
        # deploy the solution with the relative settings path
        Deploy-Solution "$baseFolder\$module" -Managed -AutoConfirm -Settings $settingsRelativePath
    }
} while ($module -ne "") # Continue looping until the input is an empty string

Write-Host "Operation complete."



