# Common Scripts Ready 

# local managed -> online environment as UNMANAGED to DEV environment
# use this script to deploy the latest umanaged solution to dev environment
# will not deploy the managed solution to the development environment, use Deploy-Module for that

$projectRoot = "$PSScriptRoot\.."
. "${projectRoot}\.scripts\Util.ps1"

Write-Host "Warning - This operation will overwrite the unmanaged solution in your environment." -ForegroundColor Yellow
if ($true -eq (Confirm-Next "Proceed (y/n)?")) {

    # select deployment configuration once
    Write-Host ""
    $deploymentConfig = Select-Deployment

    # connect to the selected tenant once
    Write-Host ""
    Write-Host "Connecting to tenant: $($deploymentConfig.Tenant)"
    Connect-DataverseTenant -authProfile $deploymentConfig.Tenant

    # main loop for module selection and deployment
    do {
        Write-Host ""
        Write-Host "=== Module Selection ===" -ForegroundColor Cyan

        # ask which type of module
        $ipTypeOptions = @("cross-module", "modules", "portals", "Exit")
        $ipType = Select-ItemFromList $ipTypeOptions
        
        if ($ipType -eq "Exit") {
            break
        }

        $baseFolder = "$projectRoot\$ipType"

        # ask for which module to push (import)
        Write-Host ""
        $excludeFolders = "__pycache__", ".scripts"
        $folderNames = Get-ChildItem -Path "$projectRoot\$ipType" -Directory -Exclude $excludeFolders | Select-Object -ExpandProperty Name
        $moduleOptions = $folderNames + @("Back to module type selection", "Exit")
        $module = Select-ItemFromList $moduleOptions

        if ($module -eq "Exit") {
            break
        } elseif ($module -eq "Back to module type selection") {
            continue
        }

        # determine target environment based on ipType and module name
        $targetEnv = if ($ipType -eq "cross-module") {
            "GOV UTILITY APPS"
        } elseif ($ipType -eq "portals") {
            if ($module -eq "core-portal") {
                "GOV CORE PORTAL"
            } else {
                "GOV PORTALS"
            }
        } else {
            "GOV APPS"
        }

        # connect to the determined environment
        Write-Host ""
        Write-Host "Connecting to environment: $targetEnv"
        Connect-DataverseEnvironment -envName $targetEnv

        # deploy the selected module
        Write-Host ""
        Write-Host "Deploying module: $module" -ForegroundColor Green
        Deploy-Solution "$baseFolder\$module" -AutoConfirm -Settings "$($deploymentConfig.Tenant)\$targetEnv.json"
        
        # confirm completion
        Write-Host ""
        Write-Host "'$module' complete" -ForegroundColor Cyan
        
    } while ($true)

    Write-Host ""
    Write-Host "Module deployment session completed." -ForegroundColor Green
}
