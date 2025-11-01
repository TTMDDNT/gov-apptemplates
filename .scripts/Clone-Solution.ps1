# Clone Solution Script
# Clones a solution from the online environment down to the local .temp folder

$projectRoot = "$PSScriptRoot\.."
. "${projectRoot}\.scripts\Util.ps1"

# prompt for tenant name/auth profile
Write-Host ""
$tenantName = Read-Host "Enter the tenant name or auth profile"

# connect to the specified tenant
Write-Host ""
Write-Host "Connecting to tenant: $tenantName"
Connect-DataverseTenant -authProfile $tenantName

# prompt for environment name
Write-Host ""
$environmentName = Read-Host "Enter the environment name"

# connect to the specified environment
Write-Host ""
Write-Host "Connecting to environment: $environmentName"
Connect-DataverseEnvironment -envName $environmentName

# ask for the solution name to clone
Write-Host ""
$solutionName = Read-Host "Enter the name of the solution to clone"

# ensure .temp folder exists
$tempFolder = "$projectRoot\.temp"
if (-not (Test-Path $tempFolder)) {
    New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null
    Write-Host "Created .temp folder"
}

# check if solution folder already exists
$solutionFolder = "$tempFolder\$solutionName"
if (Test-Path $solutionFolder) {
    Write-Host "Warning: Solution folder '$solutionName' already exists in .temp"
    $overwrite = Read-Host "Do you want to overwrite it? (y/N)"
    if ($overwrite -ne "y" -and $overwrite -ne "Y") {
        Write-Host "Operation cancelled."
        return
    }
    Remove-Item -Path $solutionFolder -Recurse -Force
}

# clone the solution using pac cli
Write-Host ""
Write-Host "Cloning solution '$solutionName' to .temp folder..."
try {
    Set-Location $tempFolder
    pac solution clone --name $solutionName
    Write-Host ""
    Write-Host "Successfully cloned solution '$solutionName' to: $tempFolder\$solutionName" -ForegroundColor Green
}
catch {
    Write-Host "Error cloning solution: $_" -ForegroundColor Red
}
finally {
    Set-Location $projectRoot
}