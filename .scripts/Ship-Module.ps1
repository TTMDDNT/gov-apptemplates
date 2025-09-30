# Common Scripts Ready 

# local managed -> online environment as managed to a single dedicated demo tenant / environment
# use this script to deploy the latest managed solution to a single dedicated demo tenant / environment

$projectRoot = "$PSScriptRoot\.."
. "${projectRoot}\.scripts\Util.ps1"

# ask which tenant to ship to
Connect-DataverseTenant
$envName = Connect-DataverseEnvironment
Write-Host "Selected Environment: $envName"

# Start the loop
do {
    # ask which type of ip
    Write-Host ""
    $ipType = Select-ItemFromList "cross-module", "federal"
    $baseFolder = "$projectRoot\$ipType"

    # ask for which module to ship
    Write-Host ""
    $excludeFolders = "__pycache__", ".scripts"
    $folderNames = Get-ChildItem -Path "$projectRoot\$ipType" -Directory -Exclude $excludeFolders | Select-Object -ExpandProperty Name
    $module = Select-ItemFromList $folderNames

    if ($module -ne "") {
        # deploy the solution
        # in future versions, this could be made smart enough to deploy the correct data models and other
        # dependencies, based on the app module you choose - for now, keeping this simple and manual
        Deploy-Solution "$baseFolder\$module" -Managed -AutoConfirm 
        
    }
} while ($module -ne "") # Continue looping until the input is an empty string

Write-Host "Operation complete."



