# PCF Control Interactive Workflow
# Guides users through PCF control development tasks step by step

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path $PSScriptRoot -Parent

# Load utility functions
. (Join-Path $PSScriptRoot "PCFControl-Util.ps1")

function Show-Welcome {
    Clear-Host
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "   PCF Control Development Workflow   " -ForegroundColor Cyan  
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This tool will guide you through working with PCF controls." -ForegroundColor White
    Write-Host ""
}

function Select-Action {
    Write-Host "What would you like to do?" -ForegroundColor Yellow
    Write-Host ""
    
    $actions = @(
        "Create New Component",
        "Update Component Version",
        "Show Component Versions",
        "Bulk Version Management",
        "Debug Component",
        "Run Tests and Validation", 
        "List Available Controls",
        "Exit"
    )
    
    $selectedAction = Select-ItemFromList $actions
    return $selectedAction
}

function Get-VersionInput {
    param(
        [string]$CurrentVersion = $null,
        [switch]$AllowIncrement = $false
    )
    
    Write-Host ""
    Write-Host "Version Management:" -ForegroundColor Yellow
    
    if ($CurrentVersion) {
        Write-Host "Current version: $CurrentVersion" -ForegroundColor Gray
        if ($AllowIncrement) {
            Write-Host "Options:" -ForegroundColor Gray
            Write-Host "  1. Enter new version (e.g., 1.2.0)" -ForegroundColor Gray
            Write-Host "  2. Type 'patch' for patch increment (e.g., $CurrentVersion -> $(Get-IncrementedVersion $CurrentVersion 'patch'))" -ForegroundColor Gray
            Write-Host "  3. Type 'minor' for minor increment (e.g., $CurrentVersion -> $(Get-IncrementedVersion $CurrentVersion 'minor'))" -ForegroundColor Gray
            Write-Host "  4. Type 'major' for major increment (e.g., $CurrentVersion -> $(Get-IncrementedVersion $CurrentVersion 'major'))" -ForegroundColor Gray
            Write-Host "  5. Press Enter to skip" -ForegroundColor Gray
        }
    }
    
    $input = Read-Host "Enter version number, increment type, or press Enter to skip"
    
    if ([string]::IsNullOrWhiteSpace($input)) {
        return $null
    }
    
    # Handle increment shortcuts
    if ($CurrentVersion -and $AllowIncrement) {
        switch ($input.ToLower()) {
            "patch" { return Get-IncrementedVersion $CurrentVersion "patch" }
            "minor" { return Get-IncrementedVersion $CurrentVersion "minor" }
            "major" { return Get-IncrementedVersion $CurrentVersion "major" }
        }
    }
    
    # Validate version format (accept both 3-part and 4-part versions)
    if ($input -notmatch '^\d+\.\d+\.\d+(\.\d+)?$') {
        Write-Host "Invalid version format. Please use semantic versioning (e.g., 1.0.0 or 1.0.0.0)" -ForegroundColor Red
        return Get-VersionInput -CurrentVersion $CurrentVersion -AllowIncrement:$AllowIncrement
    }
    
    return $input
}

function Get-IncrementedVersion {
    param(
        [string]$Version,
        [string]$Type
    )
    
    # Handle both 3-part and 4-part version formats
    if ($Version -match '^(\d+)\.(\d+)\.(\d+)(\.(\d+))?$') {
        $major = [int]$matches[1]
        $minor = [int]$matches[2]
        $patch = [int]$matches[3]
        
        switch ($Type.ToLower()) {
            "major" { return "$($major + 1).0.0" }
            "minor" { return "$major.$($minor + 1).0" }
            "patch" { return "$major.$minor.$($patch + 1)" }
        }
    }
    
    return $Version
}

function ConvertTo-PCFVersion {
    param([string]$SemanticVersion)
    
    # Convert 3-part semantic version to 4-part PCF version
    if ($SemanticVersion -match '^(\d+)\.(\d+)\.(\d+)$') {
        return "$SemanticVersion.0"
    }
    
    # Already 4-part, return as-is
    return $SemanticVersion
}

function Confirm-Action {
    param([string]$Message)
    
    Write-Host ""
    $response = Read-Host "$Message (y/N)"
    return ($response -eq 'y' -or $response -eq 'Y' -or $response -eq 'yes')
}

function Show-ControlInfo {
    param($Control)
    
    Write-Host ""
    Write-Host "Selected Control:" -ForegroundColor Cyan
    Write-Host "  Name: $($Control.Name)" -ForegroundColor White
    Write-Host "  Path: $($Control.Path)" -ForegroundColor Gray
    Write-Host ""
}

function Main {
    try {
        Show-Welcome
        
        while ($true) {
            # Step 1: Select what to do
            $action = Select-Action
            
            if ($action -eq "Exit") {
                Write-Host "Goodbye!" -ForegroundColor Green
                break
            }
            
            if ($action -eq "Create New Component") {
                Write-Host ""
                $success = New-PCFComponent -ProjectRoot $projectRoot
                
                Write-Host ""
                if ($success) {
                    Write-Host "Component created successfully!" -ForegroundColor Green
                } else {
                    Write-Host "Component creation failed or was cancelled." -ForegroundColor Red
                }
                
                Write-Host ""
                Write-Host "Returning to main menu..." -ForegroundColor Gray
                Start-Sleep -Seconds 1
                Clear-Host
                Show-Welcome
                continue
            }
            
            if ($action -eq "Update Component Version") {
                Write-Host ""
                $selectedControl = Select-PCFControl $projectRoot
                
                if (-not $selectedControl) {
                    Write-Host "No PCF controls available." -ForegroundColor Red
                    Write-Host "You can create a new component using the 'Create New Component' option." -ForegroundColor Yellow
                    Write-Host "Press any key to return to main menu..." -ForegroundColor Gray
                    $null = Read-Host
                    Clear-Host
                    Show-Welcome
                    continue
                }
                
                Show-ControlInfo $selectedControl
                
                # Get current version information
                $versionInfo = Get-PCFVersionInfo -ControlPath $selectedControl.FullPath
                
                Write-Host "Current Version Information:" -ForegroundColor Cyan
                Write-Host "  package.json: $($versionInfo.PackageVersion)" -ForegroundColor White
                Write-Host "  ControlManifest.Input.xml: $($versionInfo.ManifestVersion)" -ForegroundColor White
                
                if ($versionInfo.PackageVersion -ne $versionInfo.ManifestVersion) {
                    Write-Host "WARNING: Version mismatch detected!" -ForegroundColor Yellow
                }
                
                # Get new version
                $newVersion = Get-VersionInput -CurrentVersion $versionInfo.PackageVersion -AllowIncrement
                
                if ($newVersion) {
                    Write-Host ""
                    Write-Host "Will update version to: $newVersion" -ForegroundColor Yellow
                    Write-Host "Files to be updated:" -ForegroundColor Gray
                    Write-Host "  - package.json" -ForegroundColor Gray
                    Write-Host "  - ControlManifest.Input.xml" -ForegroundColor Gray
                    
                    if (Confirm-Action "Show all version references before updating?") {
                        Write-Host ""
                        Write-Host "All version references in component:" -ForegroundColor Cyan
                        $references = Get-AllPCFVersionReferences -ControlPath $selectedControl.FullPath
                        
                        foreach ($ref in $references) {
                            $content = Get-Content $ref.Path -Raw -ErrorAction SilentlyContinue
                            if ($content -and $content -match $ref.Pattern) {
                                $currentVersion = $matches[1]
                                Write-Host "  FILE: $($ref.File): $currentVersion" -ForegroundColor White
                                Write-Host "     $($ref.Description)" -ForegroundColor Gray
                            }
                        }
                        Write-Host ""
                    }
                    
                    if (Confirm-Action "Proceed with version update?") {
                        $success = Update-PCFVersion -ControlPath $selectedControl.FullPath -Version $newVersion -ShowAllReferences
                        
                        if ($success) {
                            Write-Host "Version updated successfully!" -ForegroundColor Green
                        } else {
                            Write-Host "Version update failed." -ForegroundColor Red
                        }
                    }
                } else {
                    Write-Host "Version update cancelled." -ForegroundColor Yellow
                }
                
                Write-Host ""
                Write-Host "Returning to main menu..." -ForegroundColor Gray
                Start-Sleep -Seconds 1
                Clear-Host
                Show-Welcome
                continue
            }
            
            if ($action -eq "Show Component Versions") {
                Write-Host ""
                Write-Host "PCF Component Version Report" -ForegroundColor Cyan
                Write-Host "============================" -ForegroundColor Cyan
                
                $controls = Get-PCFControls $projectRoot
                
                if ($controls.Count -eq 0) {
                    Write-Host "No PCF controls found" -ForegroundColor Yellow
                    Write-Host "Run 'Create New Component' to add your first PCF control" -ForegroundColor Gray
                } else {
                    # Group by solution for better organization
                    $groupedControls = $controls | Group-Object Solution
                    
                    foreach ($group in $groupedControls) {
                        $solutionName = if ($group.Name) { $group.Name } else { "Unknown" }
                        Write-Host ""
                        Write-Host "Solution: $solutionName" -ForegroundColor Yellow
                        Write-Host $("-" * 50) -ForegroundColor Gray
                        
                        foreach ($control in $group.Group) {
                            $versionInfo = Get-PCFVersionInfo -ControlPath $control.FullPath
                            
                            Write-Host "  Component: $($control.Name)" -ForegroundColor White
                            Write-Host "    Path: $($control.Path)" -ForegroundColor Gray
                            Write-Host "    package.json: $($versionInfo.PackageVersion)" -ForegroundColor Cyan
                            Write-Host "    manifest.xml: $($versionInfo.ManifestVersion)" -ForegroundColor Cyan
                            
                            # Check for version mismatches
                            if ($versionInfo.PackageVersion -ne $versionInfo.ManifestVersion) {
                                Write-Host "    WARNING: VERSION MISMATCH!" -ForegroundColor Red
                            } else {
                                Write-Host "    OK: Versions match" -ForegroundColor Green
                            }
                            Write-Host ""
                        }
                    }
                }
                
                Write-Host ""
                Write-Host "Press any key to return to main menu..." -ForegroundColor Gray
                $null = Read-Host
                Clear-Host
                Show-Welcome
                continue
            }
            
            if ($action -eq "Bulk Version Management") {
                Write-Host ""
                Write-Host "Bulk Version Management" -ForegroundColor Cyan
                Write-Host "======================" -ForegroundColor Cyan
                
                $controls = Get-PCFControls $projectRoot
                
                if ($controls.Count -eq 0) {
                    Write-Host "No PCF controls found" -ForegroundColor Yellow
                    Write-Host "Run 'Create New Component' to add your first PCF control" -ForegroundColor Gray
                } else {
                    Write-Host "Found $($controls.Count) PCF control(s)" -ForegroundColor Green
                    Write-Host ""
                    
                    # Show current versions and mismatches
                    $hasVersionMismatches = $false
                    $allVersions = @{}
                    
                    foreach ($control in $controls) {
                        $versionInfo = Get-PCFVersionInfo -ControlPath $control.FullPath
                        Write-Host "$($control.Name):" -ForegroundColor White
                        Write-Host "  package.json: $($versionInfo.PackageVersion)" -ForegroundColor Cyan
                        Write-Host "  manifest.xml: $($versionInfo.ManifestVersion)" -ForegroundColor Cyan
                        
                        if ($versionInfo.HasMismatch) {
                            Write-Host "  WARNING: Version mismatch!" -ForegroundColor Red
                            $hasVersionMismatches = $true
                        }
                        
                        # Track most common version
                        $version = $versionInfo.PackageVersion
                        if ($allVersions.ContainsKey($version)) {
                            $allVersions[$version]++
                        } else {
                            $allVersions[$version] = 1
                        }
                        Write-Host ""
                    }
                    
                    # Suggest most common version as default
                    $mostCommonVersion = ($allVersions.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
                    
                    Write-Host "Bulk Update Options:" -ForegroundColor Yellow
                    Write-Host "1. Update all components to the same version" -ForegroundColor Gray
                    Write-Host "2. Fix version mismatches only" -ForegroundColor Gray
                    Write-Host "3. Show detailed version references" -ForegroundColor Gray
                    Write-Host "4. Cancel" -ForegroundColor Gray
                    Write-Host ""
                    
                    $choice = Read-Host "Select option (1-4)"
                    
                    switch ($choice) {
                        "1" {
                            Write-Host ""
                            $newVersion = Get-VersionInput -CurrentVersion $mostCommonVersion -AllowIncrement
                            
                            if ($newVersion) {
                                Write-Host ""
                                Write-Host "Will update ALL $($controls.Count) components to version: $newVersion" -ForegroundColor Yellow
                                
                                if (Confirm-Action "Proceed with bulk version update?") {
                                    $successCount = 0
                                    foreach ($control in $controls) {
                                        Write-Host ""
                                        Write-Host "Updating $($control.Name)..." -ForegroundColor Cyan
                                        $success = Update-PCFVersion -ControlPath $control.FullPath -Version $newVersion
                                        if ($success) { $successCount++ }
                                    }
                                    
                                    Write-Host ""
                                    Write-Host "SUCCESS: Updated $successCount of $($controls.Count) components" -ForegroundColor Green
                                }
                            }
                        }
                        "2" {
                            if ($hasVersionMismatches) {
                                Write-Host ""
                                Write-Host "Fixing version mismatches..." -ForegroundColor Yellow
                                
                                $fixCount = 0
                                foreach ($control in $controls) {
                                    $versionInfo = Get-PCFVersionInfo -ControlPath $control.FullPath
                                    if ($versionInfo.HasMismatch) {
                                        Write-Host "Fixing $($control.Name)..." -ForegroundColor Cyan
                                        # Use package.json version as source of truth
                                        $success = Update-PCFVersion -ControlPath $control.FullPath -Version $versionInfo.PackageVersion
                                        if ($success) { $fixCount++ }
                                    }
                                }
                                
                                Write-Host ""
                                Write-Host "SUCCESS: Fixed version mismatches in $fixCount components" -ForegroundColor Green
                            } else {
                                Write-Host ""
                                Write-Host "SUCCESS: No version mismatches found!" -ForegroundColor Green
                            }
                        }
                        "3" {
                            Write-Host ""
                            foreach ($control in $controls) {
                                Write-Host "=== $($control.Name) ===" -ForegroundColor Cyan
                                $references = Get-AllPCFVersionReferences -ControlPath $control.FullPath
                                
                                foreach ($ref in $references) {
                                    $content = Get-Content $ref.Path -Raw -ErrorAction SilentlyContinue
                                    if ($content -and $content -match $ref.Pattern) {
                                        $version = $matches[1]
                                        Write-Host "  FILE: $($ref.File): $version" -ForegroundColor White
                                        Write-Host "     $($ref.Description)" -ForegroundColor Gray
                                        Write-Host "     Path: $($ref.Path)" -ForegroundColor DarkGray
                                    }
                                }
                                Write-Host ""
                            }
                        }
                        "4" {
                            Write-Host "Bulk version management cancelled." -ForegroundColor Yellow
                        }
                        default {
                            Write-Host "Invalid option selected." -ForegroundColor Red
                        }
                    }
                }
                
                Write-Host ""
                Write-Host "Returning to main menu..." -ForegroundColor Gray
                Start-Sleep -Seconds 1
                Clear-Host
                Show-Welcome
                continue
            }
            
            if ($action -eq "List Available Controls") {
                Write-Host ""
                Write-Host "Available PCF Controls:" -ForegroundColor Cyan
                $controls = Get-PCFControls $projectRoot
                
                if ($controls.Count -eq 0) {
                    Write-Host "No PCF controls found" -ForegroundColor Yellow
                    Write-Host "Run 'Create New Component' to add your first PCF control" -ForegroundColor Gray
                } else {
                    # Group by solution for better organization
                    $groupedControls = $controls | Group-Object Solution
                    
                    foreach ($group in $groupedControls) {
                        $solutionName = if ($group.Name) { $group.Name } else { "Unknown" }
                        Write-Host "  Solution: $solutionName" -ForegroundColor Yellow
                        
                        foreach ($control in $group.Group) {
                            Write-Host "    - $($control.Name)" -ForegroundColor White
                            Write-Host "      Path: $($control.Path)" -ForegroundColor Gray
                            Write-Host "      Project: $($control.ProjectFile)" -ForegroundColor Gray
                            Write-Host ""
                        }
                    }
                    
                    Write-Host "Development Commands:" -ForegroundColor Yellow
                    Write-Host "  Create New: New-PCFComponent '$projectRoot'" -ForegroundColor Gray
                    Write-Host "  Development: Start-PCFDebug 'path/to/control'" -ForegroundColor Gray
                    Write-Host "  Testing: Test-PCFControl 'path/to/control'" -ForegroundColor Gray
                    Write-Host ""
                    Write-Host "Build & Release (use standard scripts):" -ForegroundColor Yellow
                    Write-Host "  Build: .\\.scripts\\Build-Module.ps1 (select cross-module → pcf-controls)" -ForegroundColor Gray
                    Write-Host "  Release: .\\.scripts\\New-Release.ps1 (select cross-module → pcf-controls)" -ForegroundColor Gray
                    Write-Host ""
                    Write-Host "For interactive development workflow: .\\.scripts\\PCFControl.ps1" -ForegroundColor Cyan
                }
                
                Write-Host ""
                Write-Host "Press any key to return to main menu..." -ForegroundColor Gray
                $null = Read-Host
                Clear-Host
                Show-Welcome
                continue
            }
            
            # Step 2: Select which control to work with
            Write-Host ""
            $selectedControl = Select-PCFControl $projectRoot
            
            if (-not $selectedControl) {
                Write-Host "No PCF controls available." -ForegroundColor Red
                Write-Host "You can create a new component using the 'Create New Component' option." -ForegroundColor Yellow
                Write-Host "Press any key to return to main menu..." -ForegroundColor Gray
                $null = Read-Host
                Clear-Host
                Show-Welcome
                continue
            }
            
            Show-ControlInfo $selectedControl
            
            # Step 3: Execute the selected action
            $success = $false
            
            switch ($action) {
                "Start Development (Debug Mode)" {
                    Write-Host "This will start the development server with hot reload." -ForegroundColor Yellow
                    Write-Host "You can make changes to your control and see them immediately." -ForegroundColor Gray
                    
                    if (Confirm-Action "Start development server?") {
                        $success = Start-PCFDebug -ControlPath $selectedControl.FullPath
                    }
                }
                
                "Run Tests and Validation" {
                    Write-Host "This will run ESLint, TypeScript validation, and build verification." -ForegroundColor Yellow
                    
                    $fix = $false
                    if (Confirm-Action "Auto-fix linting issues?") {
                        $fix = $true
                    }
                    
                    $success = Test-PCFControl -ControlPath $selectedControl.FullPath -Fix:$fix
                }
                

            }
            
            # Show result
            Write-Host ""
            if ($success) {
                Write-Host "Operation completed successfully!" -ForegroundColor Green
            } else {
                Write-Host "Operation failed or was cancelled." -ForegroundColor Red
            }
            
            # Return to main menu
            Write-Host ""
            Write-Host "Returning to main menu..." -ForegroundColor Gray
            Start-Sleep -Seconds 1
            Clear-Host
            Show-Welcome
            continue
        }
    }
    catch {
        Write-Host ""
        Write-Host "An error occurred: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = Read-Host
    }
}

# Run the main workflow
Main