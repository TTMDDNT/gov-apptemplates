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

# select environment: allow the user to type an environment to run
# Connect-DataverseEnvironment (which lists environments and prompts),
# or press Enter to auto-select the default environment for the chosen module.
Connect-DataverseTenant "GOV APPS"

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
    $envName = Connect-DataverseEnvironment
}
else {
    $inputEnv = Read-Host "Enter environment name to select (or press Enter to use default '$defaultEnv')"
    if ([string]::IsNullOrEmpty($inputEnv)) {
        pac org select --environment $defaultEnv
        $envName = $defaultEnv
    }
    else {
        # use the helper which will list and select (and can also use config overrides)
        $envName = Connect-DataverseEnvironment -envName $inputEnv
    }
}

Sync-Module "$baseFolder\$module"

Build-Solution "$baseFolder\$module"
