# Common Scripts Ready 

# local managed -> online environment as UNMANAGED to DEV environment
# use this script to deploy the latest umanaged solution to dev environment
# will not deploy the managed solution to the development environment, use Deploy-Module for that

$projectRoot = "$PSScriptRoot\.."
. "${projectRoot}\.scripts\Util.ps1"

Write-Host "Warning - This operation will overwrite the unmanaged solution in your environment."
if ($true -eq (Confirm-Next "Proceed (y/n)?")) {

    # ask which type of ip
    $ipType = Select-ItemFromList "cross-module"
    $baseFolder = "$projectRoot\$ipType"

    # ask for which module to sync
    Write-Host ""
    $excludeFolders = "__pycache__", ".scripts"
    $folderNames = Get-ChildItem -Path "$projectRoot\$ipType" -Directory -Exclude $excludeFolders | Select-Object -ExpandProperty Name
    $module = Select-ItemFromList $folderNames

    Connect-DataverseTenant

    if (($ipType -eq "cross-module")) {
        $env = "GOV UTILITY APPS"
        pac org select --environment $env
        # Deploy-Solution "$baseFolder\$module" -AutoConfirm -Settings $env
        Deploy-Solution "$baseFolder\$module" -AutoConfirm

    }
}
