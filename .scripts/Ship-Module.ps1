# Common Scripts Ready 

# local managed -> online environment as managed to a single dedicated demo tenant / environment
# use this script to deploy the latest managed solution to a single dedicated demo tenant / environment

$projectRoot = "$PSScriptRoot\.."
. "${projectRoot}\.scripts\Util.ps1"

# ask which tenant to ship to (select profile)
Connect-DataverseTenant
# retrieve the signed-in tenant name for display/use (silent pac auth who parsing)
$tenantName = Get-TenantName
if ($tenantName) { Write-Host "Selected Tenant: $tenantName" }
else { Write-Host "Selected Tenant: (unknown)" }

$envName = Connect-DataverseEnvironment
Write-Host "Selected Environment: $envName"

# Start the loop
do {
    # ask which type of ip
    Write-Host ""
    $ipType = Select-ItemFromList "cross-module", "federal", "modules"
    $baseFolder = "$projectRoot\$ipType"

    # ask for which module to ship
    Write-Host ""
    $excludeFolders = "__pycache__", ".scripts"
    $folderNames = Get-ChildItem -Path "$projectRoot\$ipType" -Directory -Exclude $excludeFolders | Select-Object -ExpandProperty Name
    $module = Select-ItemFromList $folderNames

    if ($module -ne "") {
        # deploy the solution
        Deploy-Solution "$baseFolder\$module" -Managed -AutoConfirm -Settings "$tenantName\$envName.json"
        
    }
} while ($module -ne "") # Continue looping until the input is an empty string

Write-Host "Operation complete."



