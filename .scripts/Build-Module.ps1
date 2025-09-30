# Common Scripts Ready 

# Builds the module only, does not deploy

$projectRoot = "$PSScriptRoot\.."
. "${projectRoot}\.scripts\Util.ps1"

# ask which type of ip
$ipType = Select-ItemFromList "cross-module", "federal"
$baseFolder = "$projectRoot\$ipType"

# ask for which module to build
Write-Host ""
$excludeFolders = "__pycache__", ".scripts"
$folderNames = Get-ChildItem -Path "$projectRoot\$ipType" -Directory -Exclude $excludeFolders | Select-Object -ExpandProperty Name
$module = Select-ItemFromList $folderNames

$moduleFolder = "$baseFolder\$module"
Build-Solution $moduleFolder
