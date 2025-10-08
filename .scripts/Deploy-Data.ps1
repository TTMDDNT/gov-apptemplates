# Deploy-Data.ps1
#
# Purpose:
#   Interactive helper to import sample data for a selected module into Dataverse
#   using the Power Platform CLI (pac). The script connects to the tenant and
#   environment, then asks which module type and which module to import sample
#   data from. It expects a `sample-data` folder within each module that
#   contains a `data.zip` file. Select 'quit' at any prompt to exit the script.
#
# Usage:
#   From the repository root run: .\.scripts\Deploy-Data.ps1
#
# Assumptions:
#   - `Connect-DataverseTenant` and `Connect-DataverseEnvironment` are defined
#     in `.scripts\Util.ps1` and will handle authentication.
#   - The repository contains top-level directories `cross-module` and
#     `modules` with module subfolders that include `sample-data`.
#   - `pac` (Power Platform CLI) is installed and available on PATH.

$projectRoot = "$PSScriptRoot\.."
. "${projectRoot}\.scripts\Util.ps1"

Connect-DataverseTenant
Connect-DataverseEnvironment

while ($true) {

    # ask which type of ip
    Write-Host ""
    $ipType = Select-ItemFromList "cross-module", "modules", "exit"
    if ($ipType -eq 'exit') { break }

    # ask for which module
    Write-Host ""
    $excludeFolders = "__pycache__", ".scripts"
    $folderNames = Get-ChildItem -Path "$projectRoot\$ipType" -Directory -Exclude $excludeFolders | Select-Object -ExpandProperty Name
    $choices = $folderNames + @('exit')
    $module = Select-ItemFromList $choices
    if ($module -eq 'exit') { break }

    $modulePath = "${projectRoot}/${ipType}/${module}/sample-data"

    pac data import --data $modulePath"/data.zip" --verbose
}