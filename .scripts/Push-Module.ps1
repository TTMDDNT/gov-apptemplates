# Common Scripts Ready 

# local managed -> online environment as UNMANAGED to DEV environment
# use this script to deploy the latest umanaged solution to dev environment
# will not deploy the managed solution to the development environment, use Deploy-Module for that

$projectRoot = "$PSScriptRoot\.."
. "${projectRoot}\.scripts\Util.ps1"

Write-Host "Warning - This operation will overwrite the unmanaged solution in your environment."
if ($true -eq (Confirm-Next "Proceed (y/n)?")) {

    # ask which type of module
    $ipType = Select-ItemFromList "cross-module", "modules"
    $baseFolder = "$projectRoot\$ipType"

    # ask for which module to push (import)
    Write-Host ""
    $excludeFolders = "__pycache__", ".scripts"
    $folderNames = Get-ChildItem -Path "$projectRoot\$ipType" -Directory -Exclude $excludeFolders | Select-Object -ExpandProperty Name
    $module = Select-ItemFromList $folderNames

    # Default tenant (can be accepted by pressing Enter or overridden by typing a different name)
    $defaultTenant = "GOV APPS"
    $tenantInput = Read-Host "Tenant name [$defaultTenant] (press Enter to accept or type a different name)"
    if ([string]::IsNullOrWhiteSpace($tenantInput)) {
        $tenantName = $defaultTenant
    }
    else {
        $tenantName = $tenantInput.Trim()
    }
    Write-Host "Using tenant: $tenantName"
    Connect-DataverseTenant $tenantName

    # Choose default environment based on module, allow user to accept or override
    if (($module -eq "core") -or ($module -eq "process-and-tasking")) {
        $defaultEnv = "GOV UTILITY APPS"
    }
    else {
        $defaultEnv = "GOV APPS"   
    }

    $envInput = Read-Host "Environment name [$defaultEnv] (press Enter to accept or type a different name)"
    if ([string]::IsNullOrWhiteSpace($envInput)) {
        $envName = $defaultEnv
    }
    else {
        $envName = $envInput.Trim()
    }

    Write-Host "Using environment: $envName"
    pac org select --environment $envName
    Deploy-Solution "$baseFolder\$module" -AutoConfirm -Settings "$tenantName\$envName.json"
}
