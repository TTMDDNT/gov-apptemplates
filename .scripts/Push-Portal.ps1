# Pushes a Power Pages site from your local copy back to the online environment

$projectRoot = "$PSScriptRoot\.."
. "${projectRoot}\.scripts\Util.ps1"

# ask for which portal to push
Write-Host ""
$excludeFolders = "__pycache__", ".scripts"
$folderNames = Get-ChildItem -Path "$projectRoot\portals" -Directory -Exclude $excludeFolders | Select-Object -ExpandProperty Name
$portal = Select-ItemFromList $folderNames

# verify that the site folder exists
$sitePath = "$projectRoot\portals\$portal\site"
if (-not (Test-Path -Path $sitePath)) {
    Write-Error "Site folder not found at: $sitePath"
    Write-Error "Please run Sync-Portal first to download the site."
    exit 1
}

# select deployment configuration
Write-Host ""
$deploymentConfig = Select-Deployment

# connect to the selected tenant
Write-Host ""
Write-Host "Connecting to tenant: $($deploymentConfig.Tenant)"
Connect-DataverseTenant -authProfile $deploymentConfig.Tenant

# determine target environment for portals
$targetEnv = if ($portal -eq "core-portal" -or $portal -like "*core*") {
    "GOV CORE PORTAL"
} else {
    "GOV PORTALS"
}

# connect to the determined environment
Write-Host ""
Write-Host "Connecting to environment: $targetEnv"
Connect-DataverseEnvironment -envName $targetEnv

# upload the Power Pages site
Write-Host ""
Write-Host "Uploading Power Pages site from: $sitePath"
Write-Host ""

# execute the upload command with enhanced data model (v2)
$uploadResult = pac pages upload --path $sitePath --modelVersion 2 2>&1 | Out-String
Write-Host $uploadResult

Write-Host ""
Write-Host "Power Pages site upload complete!"
