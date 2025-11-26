# Synchronizes a Power Pages site from the online environment down to your local copy

$projectRoot = "$PSScriptRoot\.."
. "${projectRoot}\.scripts\Util.ps1"

# ask for which portal to sync
Write-Host ""
$excludeFolders = "__pycache__", ".scripts"
$folderNames = Get-ChildItem -Path "$projectRoot\portals" -Directory -Exclude $excludeFolders | Select-Object -ExpandProperty Name
$portal = Select-ItemFromList $folderNames

# check if site folder exists and warn about overwriting changes
$downloadPath = "$projectRoot\portals\$portal\site"
if (Test-Path -Path $downloadPath) {
    Write-Host ""
    Write-Warning "CAUTION: This will overwrite all local changes in the site folder!"
    Write-Host "If you have local changes you want to keep, run Push-Portal first."
    Write-Host ""
    $confirm = Read-Host "Continue and overwrite local site folder? (y/N)"
    if ($confirm -notlike "y*") {
        Write-Host "Sync cancelled."
        exit 0
    }
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

# list available Power Pages sites
Write-Host ""
Write-Host "Fetching available Power Pages sites..."
$pagesList = pac pages list 2>&1 | Out-String
Write-Host $pagesList

# ask user to select which site to download
Write-Host ""
$webSiteId = Read-Host "Enter the Website ID to download"

# clear existing site content first to ensure a clean sync
if (Test-Path -Path $downloadPath) {
    Write-Host ""
    Write-Host "Clearing existing site content..."
    Remove-Item -Path $downloadPath -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null

# download the Power Pages site
Write-Host ""
Write-Host "Downloading Power Pages site to: $downloadPath"

# execute the download command
$downloadResult = pac pages download --path $downloadPath --webSiteId $webSiteId -mv Enhanced 2>&1 | Out-String
Write-Host $downloadResult

# flatten the folder structure - pac creates a subfolder with the portal's friendly name
Write-Host ""
Write-Host "Organizing downloaded files..."

# wait a moment for any file locks to release
Start-Sleep -Seconds 2

# find the generated subfolder - look for any directory that isn't a standard config folder
$generatedFolder = Get-ChildItem -Path $downloadPath -Directory | Where-Object { 
    $_.Name -notlike ".*" -and $_.Name -ne "content-snippets" 
} | Select-Object -First 1

if ($generatedFolder) {
    $generatedFolderName = $generatedFolder.Name
    $generatedFolderPath = $generatedFolder.FullName
    
    # copy all contents from the generated folder to the parent site folder
    Write-Host "Moving content from '$generatedFolderName' to site root..."
    Get-ChildItem -Path $generatedFolderPath -Force | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $downloadPath -Recurse -Force
    }
    
    # wait a moment for file operations to complete
    Start-Sleep -Seconds 2
    
    # remove the generated folder
    Remove-Item -Path $generatedFolderPath -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Power Pages site download complete!"
