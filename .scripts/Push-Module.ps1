# Common Scripts Ready 

# local managed -> online environment as UNMANAGED to DEV environment
# use this script to deploy the latest umanaged solution to dev environment
# will not deploy the managed solution to the development environment, use Deploy-Module for that

$projectRoot = "$PSScriptRoot\.."
. "${projectRoot}\.scripts\Util.ps1"

Write-Host "Warning - This operation will overwrite the unmanaged solution in your environment."
if ($true -eq (Confirm-Next "Proceed (y/n)?")) {

    # ask which type of module
    $ipType = Select-ItemFromList "cross-module", "federal", "target"
    $baseFolder = "$projectRoot\$ipType"

    # ask for which module to push (import)
    Write-Host ""
    $excludeFolders = "__pycache__", ".scripts"
    $folderNames = Get-ChildItem -Path "$projectRoot\$ipType" -Directory -Exclude $excludeFolders | Select-Object -ExpandProperty Name
    $module = Select-ItemFromList $folderNames

    $tenantName = "GOV APPS"
    Connect-DataverseTenant $tenantName

    if (($module -eq "core") -or ($module -eq "process-and-tasking")) {
        $envName = "GOV UTILITY APPS"
    }
    else {
        $envName = "GOV APPS"   
    }

    pac org select --environment $envName
    Deploy-Solution "$baseFolder\$module" -AutoConfirm -Settings "$tenantName\$envName.json"
}
