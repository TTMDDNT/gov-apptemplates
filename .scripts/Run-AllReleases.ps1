<#
Simple wrapper to create releases for all modules under
cross-module and modules. Prompts for each module to confirm
the version (y/n) before building and copying artifacts.
#>

$projectRoot = Join-Path $PSScriptRoot ".."
. (Join-Path $projectRoot ".scripts\Util.ps1")

function Get-NewFileNameLocal($originalName, $newVersion) {
    if (-not [string]::IsNullOrEmpty($newVersion)) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($originalName)
        $extension = [System.IO.Path]::GetExtension($originalName)
        return "{0} - {1}{2}" -f $baseName, $newVersion, $extension
    }
    return $originalName
}

$ipTypes = @('cross-module','modules')
$excludeFolders = '__pycache__', '.scripts'

foreach ($ipType in $ipTypes) {
    $baseFolder = Join-Path $projectRoot $ipType
    if (-not (Test-Path $baseFolder)) { continue }

    $folderNames = Get-ChildItem -Path $baseFolder -Directory -Exclude $excludeFolders | Select-Object -ExpandProperty Name
    foreach ($module in $folderNames) {
        $moduleFolder = Join-Path -Path $baseFolder -ChildPath $module
        $solutionFilePath = Join-Path -Path $moduleFolder -ChildPath 'src\Other\Solution.xml'

        if (-not (Test-Path $solutionFilePath)) {
            Write-Host "Skipping ${ipType}\${module} - Solution.xml not found" -ForegroundColor Yellow
            continue
        }

        try {
            $currentVersion = Read-SolutionVersion $solutionFilePath
        }
        catch {
            $err = $_.ToString()
            Write-Host "Failed to read version for ${ipType}\${module}: $err" -ForegroundColor Red
            continue
        }

        $confirm = Read-Host "[${ipType}\${module}] Version number is $currentVersion, OK? (y/n)"
        if ($confirm -ne 'y') {
            Write-Host "Skipping ${ipType}\${module} per user response." -ForegroundColor Cyan
            continue
        }

        # Call the parameterized New-Release script for this module.
        Write-Host "Running New-Release for ${ipType}\${module}..."
        & "${projectRoot}\.scripts\New-Release.ps1" -IpType $ipType -Module $module -AutoConfirm
        if ($LASTEXITCODE -ne 0) {
            Write-Host "New-Release script returned exit code $LASTEXITCODE for ${ipType}\${module}" -ForegroundColor Red
            continue
        }
        Write-Host "Completed ${ipType}\${module}." -ForegroundColor Green
    }
}

Write-Host 'All done.' -ForegroundColor Green
