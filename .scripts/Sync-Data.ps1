# Generate the Schema File via the Configuration Migration Tool
# pac tool cmt

# Select the table(s) and field(s) that you want to include in the export

# Save the schema file under a folder in sample-data

$projectRoot = "$PSScriptRoot\.."
. "${projectRoot}\.scripts\Util.ps1"

Connect-DataverseTenant
Connect-DataverseEnvironment

# ask which type of ip
Write-Host ""
$ipType = Select-ItemFromList "agents", "cross-module", "modules"

# ask for which module to sync
Write-Host ""
$excludeFolders = "__pycache__", ".scripts"
$folderNames = Get-ChildItem -Path "$projectRoot\$ipType" -Directory -Exclude $excludeFolders | Select-Object -ExpandProperty Name
$module = Select-ItemFromList $folderNames

$modulePath = "${projectRoot}/${ipType}/${module}/sample-data"

# Ensure the sample-data directory exists
if (-not (Test-Path $modulePath)) {
    New-Item -ItemType Directory -Path $modulePath -Force
    Write-Host "Created directory: $modulePath"
}

pac data export --schemaFile "$modulePath/schema.xml" --dataFile "$modulePath/data.zip" -o