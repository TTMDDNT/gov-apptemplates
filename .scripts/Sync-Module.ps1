# Common Scripts Ready

# Synchronizes changes from the online environment down to your local copy

$projectRoot = "$PSScriptRoot\.."
. "${projectRoot}\.scripts\Util.ps1"

# ask which type of module
Write-Host ""
$moduleType = Select-ItemFromList "cross-module", "modules"
$baseFolder = "$projectRoot\$moduleType"

# ask for which module to sync
Write-Host ""
$excludeFolders = "__pycache__", ".scripts"
$folderNames = Get-ChildItem -Path "$projectRoot\$moduleType" -Directory -Exclude $excludeFolders | Select-Object -ExpandProperty Name
$module = Select-ItemFromList $folderNames

# Default tenant (press Enter to accept or type a different name)
$defaultTenant = "GOV APPS"
$tenantInput = Read-Host "Tenant name [$defaultTenant] (press Enter to accept or type a different name)"
if ([string]::IsNullOrWhiteSpace($tenantInput)) {
    $tenantName = $defaultTenant
}
else {
    $tenantName = $tenantInput.Trim()
}
Write-Host "Using tenant: $tenantName"
Connect-DataverseTenant $tenantName

# determine default environment based on moduleType
if ($moduleType -eq "cross-module") {
    $defaultEnv = "GOV UTILITY APPS"
}
elseif ($moduleType -eq "modules") {
    $defaultEnv = "GOV APPS"
}
else {
    $defaultEnv = ""
}

Write-Host ""
if ([string]::IsNullOrEmpty($defaultEnv)) {
    # no sensible default, fall back to prompting through Connect-DataverseEnvironment
    Connect-DataverseEnvironment
}
else {
    $envInput = Read-Host "Environment name [$defaultEnv] (press Enter to accept or type a different name)"
    if ([string]::IsNullOrWhiteSpace($envInput)) {
        $envName = $defaultEnv
        Write-Host "Using environment: $envName"
        pac org select --environment $envName
    }
    else {
        $envName = $envInput.Trim()
        Write-Host "Using environment: $envName"
        # use the helper which will list and select (and can also use config overrides)
        Connect-DataverseEnvironment -envName $envName
    }
}

Sync-Module "$baseFolder\$module"

Build-Solution "$baseFolder\$module"
