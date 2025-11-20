# This script will build a module in GovCDM or Solution-Accelerators
# and then copy the unmanaged and managed solution artifacts into the module's releases folder

# This allows us to create distribution copies of the solution artifacts
# for anyone who does not want to or cannot perform the builds via the repo
# aka "The easy button"

# Be sure to set the version number you want in your online copy first,
# then synchronize that down to your local copy here
# and then run this script to create the solution artifacts

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('cross-module','modules','portals')]
    [string]$IpType,

    [Parameter(Mandatory=$false)]
    [string]$Module,

    [Parameter(Mandatory=$false)]
    [switch]$AutoConfirm
)

$projectRoot = Join-Path $PSScriptRoot ".."
. (Join-Path $projectRoot ".scripts\Util.ps1")

function Get-NewFileName ($originalName, $newVersion) {
    if (-not [string]::IsNullOrEmpty($newVersion)) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($originalName)
        $extension = [System.IO.Path]::GetExtension($originalName)
        return "{0} - {1}{2}" -f $baseName, $newVersion, $extension
    }
    return $originalName
}

function Copy-SolutionArtifact($sourceArtifact, $newVersion) {

    $sourceFile = Join-Path $artifactFolder $sourceArtifact
    # Use the artifact filename (not the full path) so Get-NewFileName returns exactly e.g.
    # "MS-Gov-Asset-Management - 1.0.0.0.zip" or "MS-Gov-Asset-Management_managed - 1.0.0.0.zip"
    $targetFile = Get-NewFileName $sourceArtifact $newVersion
    # Place the artifact directly in the module's releases folder (no per-solution subfolder)
    $intermediatePath = $distFolder
    $destinationPath = Join-Path -Path $intermediatePath -ChildPath $targetFile
    Write-Host "Copying:`n  $sourceFile`n-> $destinationPath"
    Copy-Item -Path $sourceFile -Destination $destinationPath
}

# ask which type of ip (if not provided as parameter)
if (-not $IpType) {
    $IpType = Select-ItemFromList "cross-module", "modules", "portals"
}
$baseFolder = "$projectRoot\$IpType"

# ask for which module to sync (if not provided as parameter)
if (-not $Module) {
    Write-Host ""
    $excludeFolders = "__pycache__", ".scripts"
    $folderNames = Get-ChildItem -Path "$projectRoot\$IpType" -Directory -Exclude $excludeFolders | Select-Object -ExpandProperty Name
    $Module = Select-ItemFromList $folderNames
}

# Set up some paths here
$moduleFolder = "$baseFolder\$Module"
$solutionFilePath = Join-Path $moduleFolder "src\Other\Solution.xml"
$distFolder = Join-Path $moduleFolder "releases"
$artifactFolder = Join-Path $moduleFolder "bin\Debug"
$cdsprojFile = Get-ChildItem -Path $moduleFolder -Filter "*.cdsproj" | Select-Object -First 1
$solutionName = $cdsprojFile.BaseName

# Confirm the version number
# Confirm the version number
$currentVersion = Read-SolutionVersion $solutionFilePath
if ($AutoConfirm.IsPresent) {
    $newVersion = $currentVersion
} else {
    $confirm = Read-Host "Version number is $currentVersion, OK? (y/n)"
    if ($confirm -ne "y") {
        Write-Host "Update the version number in your online copy, use Sync-Module to pull that change down, and run this script again. This is to ensure that your next sync will not overwrite the version number in your local copy."
        exit
    }
    $newVersion = $currentVersion
}
# $newVersion = Read-Host "Enter new version number (enter to keep current)"
# if (-not [string]::IsNullOrEmpty($newVersion)) {
#     Update-SolutionVersion $solutionFilePath $newVersion
# }
# else {
#     $newVersion = $currentVersion
# }

# Build the solution.zip artifacts (managed and unmanaged)
Build-Solution $moduleFolder

# Ensure the destination folder exists under the module (moduleFolder\releases\<solutionName>)
if (-not (Test-Path $distFolder)) {
    New-Item -Path $distFolder -ItemType Directory | Out-Null
}

# Copy the files
Copy-SolutionArtifact "${solutionName}.zip" $newVersion
Copy-SolutionArtifact "${solutionName}_managed.zip" $newVersion
