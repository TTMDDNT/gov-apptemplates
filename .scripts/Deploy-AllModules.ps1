<#
.SYNOPSIS
Deploy all modules as managed solutions to a selected Dataverse tenant/environment.

.DESCRIPTION
This script connects to a Dataverse tenant and environment using the shared
functions in `Util.ps1`, then deploys every folder inside the `modules`
directory as a managed solution. The deployment order ensures `core` is
installed first, followed by `process-and-tasking`, and then the remaining
modules in alphabetical order.

.NOTES
Uses: Connect-DataverseTenant, Connect-DataverseEnvironment, Deploy-Solution
from `.scripts\Util.ps1` (same helpers used by `Ship-Module.ps1`).
#>

[CmdletBinding(SupportsShouldProcess=$true)]

$projectRoot = "$PSScriptRoot\.."
. "${projectRoot}\.scripts\Util.ps1"
Write-Host "Connecting to Dataverse tenant and environment..." -ForegroundColor Cyan
Connect-DataverseTenant

# retrieve the signed-in tenant name for display/use (same as Ship-Module.ps1)
$tenantName = Get-TenantName
if ($tenantName) { Write-Host "Selected Tenant: $tenantName" }
else { Write-Host "Selected Tenant: (unknown)" }

$envName = Connect-DataverseEnvironment
Write-Host "Selected Environment: $envName"

# Confirm the user has created the connections and the settings file under .config\<tenant>\<env>.json
$settingsRel = "$tenantName\$envName.json"
$settingsPath = Join-Path $projectRoot ".config"
$settingsPath = Join-Path $settingsPath $settingsRel

if (-not (Test-Path $settingsPath)) {
    $answer = Read-Host "Settings file not found at '$settingsPath'. Have you created the connections and the settings file for the target environment under the .config folder? (Y/N)"
    if ($answer -notmatch '^[Yy]') {
        Write-Host "Aborting: please create the settings file at '$settingsPath' and ensure your Dataverse connections are available before running this script." -ForegroundColor Red
        return
    }
} else {
    $confirm = Read-Host "Found settings file at '$settingsPath'. Proceed with deployments? (Y/N)"
    if ($confirm -notmatch '^[Yy]') {
        Write-Host "Aborted by user." -ForegroundColor Yellow
        return
    }
}

$excludeFolders = '__pycache__', '.scripts'

function Deploy-FromFolder {
    param (
        [string]$folderPath,
        [string[]]$orderedFirst = @()
    )

    Write-Host "Collecting modules from: $folderPath" -ForegroundColor Cyan
    if (-not (Test-Path $folderPath)) {
        Write-Host "Modules folder not found: $folderPath" -ForegroundColor Yellow
        return
    }

    $allModules = Get-ChildItem -Path $folderPath -Directory -Exclude $excludeFolders | Select-Object -ExpandProperty Name

    # Build final list preserving the required order when provided
    $toDeploy = @()
    foreach ($m in $orderedFirst) {
        if ($allModules -contains $m) {
            $toDeploy += $m
        } else {
            Write-Host "Note: ordered module '$m' not found in $folderPath; skipping." -ForegroundColor Yellow
        }
    }

    $remaining = $allModules | Where-Object { $orderedFirst -notcontains $_ } | Sort-Object
    $toDeploy += $remaining

    if ($toDeploy.Count -eq 0) {
        Write-Host "No modules found in: $folderPath" -ForegroundColor Yellow
        return
    }

    Write-Host "Deployment order:" -ForegroundColor Green
    $toDeploy | ForEach-Object { Write-Host " - $_" }

    foreach ($module in $toDeploy) {
        Write-Host "`nDeploying module: $module" -ForegroundColor Cyan
        $modulePath = Join-Path $folderPath $module
        if (-not (Test-Path $modulePath)) {
            Write-Host "Module folder missing: $modulePath" -ForegroundColor Yellow
            continue
        }

        # Guard against $PSCmdlet being $null (can happen when dot-sourced); default to proceeding
        $shouldProceed = $true
        if ($PSCmdlet) {
            $shouldProceed = $PSCmdlet.ShouldProcess($module, "Deploy managed solution")
        }

        if ($shouldProceed) {
            # Pass settings file (tenant\env.json) like Ship-Module.ps1
            Deploy-Solution $modulePath -Managed -AutoConfirm -Settings "$tenantName\$envName.json"
        }
    }
}

# First: deploy cross-module folder (ensure core and process-and-tasking are first)
$crossFolder = Join-Path $projectRoot 'cross-module'
$orderedFirst = @('core', 'process-and-tasking')
Deploy-FromFolder -folderPath $crossFolder -orderedFirst $orderedFirst

# Then: deploy modules folder (no special ordering beyond alphabetical)
$modulesFolder = Join-Path $projectRoot 'modules'
Deploy-FromFolder -folderPath $modulesFolder

Write-Host "All deployments processed." -ForegroundColor Green
