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

# select deployment configuration
Write-Host ""
$deploymentConfig = Select-Deployment

# connect to the selected tenant
Write-Host ""
Write-Host "Connecting to tenant: $($deploymentConfig.Tenant)"
Connect-DataverseTenant -authProfile $deploymentConfig.Tenant

# retrieve the signed-in tenant name for display/use
$tenantName = $deploymentConfig.Tenant
Write-Host "Selected Tenant: $tenantName"

# Confirm the user has created the connections and the settings file under .config\<tenant>\<env>.json
$govUtilityEnv = "GOV UTILITY APPS"
$govAppsEnv = "GOV APPS"

$settingsFiles = @(
    "$tenantName\$govUtilityEnv.json",
    "$tenantName\$govAppsEnv.json"
)

$missingSettings = @()
foreach ($settingsRel in $settingsFiles) {
    $settingsPath = Join-Path $projectRoot ".config"
    $settingsPath = Join-Path $settingsPath $settingsRel
    if (-not (Test-Path $settingsPath)) {
        $missingSettings += $settingsPath
    }
}

if ($missingSettings.Count -gt 0) {
    Write-Host "Settings files not found at:" -ForegroundColor Red
    $missingSettings | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    $answer = Read-Host "Have you created the connections and the settings files for the target environments under the .config folder? (Y/N)"
    if ($answer -notmatch '^[Yy]') {
        Write-Host "Aborting: please create the settings files and ensure your Dataverse connections are available before running this script." -ForegroundColor Red
        return
    }
} else {
    Write-Host "Found all required settings files." -ForegroundColor Green
    $confirm = Read-Host "Proceed with deployments? (Y/N)"
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

        # determine target environment based on folder path
        $targetEnv = if ($folderPath -like "*cross-module*") {
            "GOV UTILITY APPS"
        } else {
            "GOV APPS"
        }

        # connect to the determined environment
        Write-Host "Connecting to environment: $targetEnv" -ForegroundColor Yellow
        Connect-DataverseEnvironment -envName $targetEnv

        # Guard against $PSCmdlet being $null (can happen when dot-sourced); default to proceeding
        $shouldProceed = $true
        if ($PSCmdlet) {
            $shouldProceed = $PSCmdlet.ShouldProcess($module, "Deploy managed solution")
        }

        if ($shouldProceed) {
            # Pass settings file (tenant\env.json) using the deployment config
            Deploy-Solution $modulePath -Managed -AutoConfirm -Settings "$($deploymentConfig.Tenant)\$targetEnv.json"
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
