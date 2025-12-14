# PCF Control Utility Functions
# Core functions for PCF control development workflow

# Load main utility functions
. (Join-Path $PSScriptRoot "Util.ps1")

# Publisher configuration from Solution.xml
$script:PublisherConfig = @{
    UniqueName = "msgovsolutions"
    DisplayName = "Microsoft Government Solutions"
    Description = "Microsoft Government Solutions"
    CustomizationPrefix = "msgov"
    CustomizationOptionValuePrefix = "18844"
}

function Get-PCFControls {
    param(
        [string]$ProjectRoot,
        [string]$SolutionPath = $null
    )
    
    $controls = @()
    
    # If SolutionPath provided, look for PCF components in that solution
    if ($SolutionPath) {
        $componentsPath = Join-Path $SolutionPath "components"
        if (Test-Path $componentsPath) {
            $folders = Get-ChildItem $componentsPath -Directory
            foreach ($folder in $folders) {
                $pcfProjFiles = Get-ChildItem $folder.FullName -Filter "*.pcfproj" -ErrorAction SilentlyContinue
                if ($pcfProjFiles) {
                    $pcfProjFile = $pcfProjFiles[0]
                    # Get relative path (PowerShell 5.1 compatible)
                    $relativePath = $folder.FullName.Substring($ProjectRoot.Length + 1).Replace('\', '/')
                    $controls += @{
                        Name = $folder.Name
                        Path = $relativePath
                        FullPath = $folder.FullName
                        ProjectFile = $pcfProjFile.Name
                        Solution = Split-Path $SolutionPath -Leaf
                    }
                }
            }
        }
    }
    else {
        # Look in consolidated solution first
        $consolidatedPath = Join-Path $ProjectRoot "cross-module\pcf-controls"
        if (Test-Path $consolidatedPath) {
            $consolidatedControls = Get-PCFControls -ProjectRoot $ProjectRoot -SolutionPath $consolidatedPath
            $controls += $consolidatedControls
        }
        
        # Then look for legacy code-components (for backward compatibility)
        $codeComponentsPath = Join-Path $ProjectRoot "code-components"
        if (Test-Path $codeComponentsPath) {
            $folders = Get-ChildItem $codeComponentsPath -Directory
            foreach ($folder in $folders) {
                $pcfProjFiles = Get-ChildItem $folder.FullName -Filter "*.pcfproj" -ErrorAction SilentlyContinue
                if ($pcfProjFiles) {
                    $pcfProjFile = $pcfProjFiles[0]
                    $controls += @{
                        Name = $folder.Name
                        Path = "code-components/$($folder.Name)"
                        FullPath = $folder.FullName
                        ProjectFile = $pcfProjFile.Name
                        Solution = "Legacy"
                    }
                }
            }
        }
        
        # Look in other solutions that might have PCF components
        $searchPaths = @(
            "agents", "cross-module", "modules", "federal", "portals"
        )
        foreach ($searchPath in $searchPaths) {
            $basePath = Join-Path $ProjectRoot $searchPath
            if (Test-Path $basePath) {
                $solutionFolders = Get-ChildItem $basePath -Directory
                foreach ($solutionFolder in $solutionFolders) {
                    if ($solutionFolder.Name -ne "pcf-controls") { # Skip consolidated, already handled
                        $solutionControls = Get-PCFControls -ProjectRoot $ProjectRoot -SolutionPath $solutionFolder.FullName
                        $controls += $solutionControls
                    }
                }
            }
        }
    }
    
    return $controls
}

function Select-PCFControl {
    param([string]$ProjectRoot)
    
    $controls = Get-PCFControls $ProjectRoot
    
    if ($controls.Count -eq 0) {
        Write-Host "No PCF controls found in code-components folder" -ForegroundColor Yellow
        Write-Host "Controls should be located in: code-components/your-control-name/" -ForegroundColor Gray
        return $null
    }
    
    Write-Host "Available PCF Controls:" -ForegroundColor Cyan
    Write-Host ""
    
    $controlNames = $controls | ForEach-Object { $_.Name }
    $selectedName = Select-ItemFromList $controlNames
    
    $selectedControl = $controls | Where-Object { $_.Name -eq $selectedName }
    return $selectedControl
}

function Invoke-NpmCommand {
    param(
        [string]$Command, 
        [string]$Description,
        [string]$WorkingDirectory
    )
    
    Write-Host $Description -ForegroundColor Green
    Push-Location $WorkingDirectory
    try {
        Invoke-Expression "npm $Command"
        if ($LASTEXITCODE -ne 0) {
            throw "$Description failed"
        }
        return $true
    }
    catch {
        Write-Error "$Description failed: $_"
        return $false
    }
    finally {
        Pop-Location
    }
}

function Build-PCFSolution {
    param(
        [string]$ControlPath,
        [string]$Configuration = "Release"
    )
    
    $solutionPath = Join-Path $ControlPath "solution"
    if (!(Test-Path $solutionPath)) {
        throw "Solution path not found: $solutionPath"
    }
    
    Write-Host "Building Power Platform solution ($Configuration)..." -ForegroundColor Green
    Push-Location $solutionPath
    try {
        Write-Host "  Restoring packages..." -ForegroundColor Gray
        msbuild /t:restore /v:minimal /nologo
        if ($LASTEXITCODE -ne 0) { throw "Solution restore failed" }
        
        Write-Host "  Building solution..." -ForegroundColor Gray
        msbuild /t:rebuild /restore /p:Configuration=$Configuration /v:minimal /nologo
        if ($LASTEXITCODE -ne 0) { throw "Solution build failed" }
        
        Write-Host "  Packaging solution..." -ForegroundColor Gray
        msbuild /v:minimal /nologo
        if ($LASTEXITCODE -ne 0) { throw "Solution packaging failed" }
        
        Write-Host "Solution build completed successfully!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Solution build failed: $_"
        return $false
    }
    finally {
        Pop-Location
    }
}

function Get-PCFVersionInfo {
    param([string]$ControlPath)
    
    $versionInfo = @{
        PackageVersion = "Unknown"
        ManifestVersion = "Unknown"
        HasMismatch = $false
        Files = @()
    }
    
    try {
        # Get version from package.json
        $packageJsonPath = Join-Path $ControlPath "package.json"
        if (Test-Path $packageJsonPath) {
            $packageJson = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
            if ($packageJson.version) {
                $versionInfo.PackageVersion = $packageJson.version
                $versionInfo.Files += @{
                    Type = "package.json"
                    Path = $packageJsonPath
                    Version = $packageJson.version
                }
            }
        }
        
        # Get version from control manifest
        $manifestFiles = Get-ChildItem $ControlPath -Recurse -Name "ControlManifest.Input.xml"
        foreach ($manifestFile in $manifestFiles) {
            $manifestPath = Join-Path $ControlPath $manifestFile
            $manifestContent = Get-Content $manifestPath -Raw
            if ($manifestContent -match 'version="([^"]*)"') {
                $versionInfo.ManifestVersion = $matches[1]
                $versionInfo.Files += @{
                    Type = "ControlManifest.Input.xml"
                    Path = $manifestPath
                    Version = $matches[1]
                }
                break
            }
        }
        
        # Look for additional version files that might need updating
        # Check for .pcfproj files that might contain version info
        $pcfProjFiles = Get-ChildItem $ControlPath -Filter "*.pcfproj" -ErrorAction SilentlyContinue
        foreach ($pcfProj in $pcfProjFiles) {
            $content = Get-Content $pcfProj.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -and $content -match '<Version>([^<]*)</Version>') {
                $versionInfo.Files += @{
                    Type = "*.pcfproj"
                    Path = $pcfProj.FullName
                    Version = $matches[1]
                }
            }
        }
        
        # Check for version mismatch
        $versionInfo.HasMismatch = ($versionInfo.PackageVersion -ne $versionInfo.ManifestVersion)
        
        return $versionInfo
    }
    catch {
        Write-Warning "Failed to read version information from $ControlPath : $_"
        return $versionInfo
    }
}

function Get-AllPCFVersionReferences {
    param([string]$ControlPath)
    
    $references = @()
    
    try {
        Write-Host "Scanning for version references in: $ControlPath" -ForegroundColor Gray
        
        # Core version files
        $packageJsonPath = Join-Path $ControlPath "package.json"
        if (Test-Path $packageJsonPath) {
            $references += @{
                File = "package.json"
                Path = $packageJsonPath
                Pattern = '"version":\s*"([^"]*)"'
                UpdatePattern = '"version": "{0}"'
                Description = "NPM package version"
            }
        }
        
        # Control manifest files
        $manifestFiles = Get-ChildItem $ControlPath -Recurse -Filter "ControlManifest.Input.xml" -ErrorAction SilentlyContinue
        foreach ($manifest in $manifestFiles) {
            $references += @{
                File = $manifest.Name
                Path = $manifest.FullName
                Pattern = 'version="([^"]*)"'
                UpdatePattern = 'version="{0}"'
                Description = "PCF control manifest version"
                IsControlManifest = $true
            }
        }
        
        # PCF project files
        $pcfProjFiles = Get-ChildItem $ControlPath -Filter "*.pcfproj" -ErrorAction SilentlyContinue
        foreach ($pcfProj in $pcfProjFiles) {
            $content = Get-Content $pcfProj.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -and $content -match '<Version>([^<]*)</Version>') {
                $references += @{
                    File = $pcfProj.Name
                    Path = $pcfProj.FullName
                    Pattern = '<Version>([^<]*)</Version>'
                    UpdatePattern = '<Version>{0}</Version>'
                    Description = "MSBuild project version"
                }
            }
        }
        
        # Note: Resource files (.resx) typically don't need version updates
        # as they are referenced by the manifest. Skipping to avoid XML declaration corruption.
        
        return $references
    }
    catch {
        Write-Warning "Failed to scan version references: $_"
        return $references
    }
}

function Update-PCFVersion {
    param(
        [string]$ControlPath,
        [string]$Version,
        [switch]$ShowAllReferences = $false
    )
    
    if (-not $Version) { return $true }
    
    Write-Host "Updating version to: $Version" -ForegroundColor Yellow
    
    try {
        $updateCount = 0
        $references = Get-AllPCFVersionReferences -ControlPath $ControlPath
        
        if ($ShowAllReferences) {
            Write-Host ""
            Write-Host "All version references found:" -ForegroundColor Cyan
            foreach ($ref in $references) {
                $currentContent = Get-Content $ref.Path -Raw -ErrorAction SilentlyContinue
                if ($currentContent -and $currentContent -match $ref.Pattern) {
                    $currentVersion = $matches[1]
                    Write-Host "  FILE: $($ref.File): $currentVersion" -ForegroundColor White
                    Write-Host "     $($ref.Description)" -ForegroundColor Gray
                }
            }
            Write-Host ""
        }
        
        # Update each reference
        foreach ($ref in $references) {
            try {
                $content = Get-Content $ref.Path -Raw -ErrorAction SilentlyContinue
                if ($content) {
                    # Special handling for control manifest to avoid XML declaration
                    if ($ref.IsControlManifest) {
                        if ($content -match '<control[^>]+version="([^"]*)"') {
                            $oldVersion = $matches[1]
                        } else {
                            continue
                        }
                    } elseif ($content -match $ref.Pattern) {
                        $oldVersion = $matches[1]
                    } else {
                        continue
                    }
                    
                    # Use 3-part semantic versions for all PCF files
                    $versionToUse = $Version
                    
                    if ($oldVersion -ne $versionToUse) {
                        # Perform the replacement based on the pattern
                        if ($ref.Pattern -eq '"version":\s*"([^"]*)"') {
                            # Special handling for JSON
                            $packageJson = Get-Content $ref.Path -Raw | ConvertFrom-Json
                            $packageJson.version = $versionToUse
                            $packageJson | ConvertTo-Json -Depth 10 | Set-Content $ref.Path
                        } elseif ($ref.IsControlManifest) {
                            # Special handling for control manifest to avoid XML declaration
                            $newContent = $content -replace '<control([^>]+)version="[^"]*"', "<control`$1version=""$versionToUse"""
                            $newContent | Set-Content $ref.Path
                        } else {
                            # Simple pattern replacement
                            $newContent = $content -replace $ref.Pattern, ($ref.UpdatePattern -f $versionToUse)
                            $newContent | Set-Content $ref.Path
                        }
                        
                        Write-Host "  OK: Updated $($ref.File): $oldVersion -> $versionToUse" -ForegroundColor Green
                        $updateCount++
                    } else {
                        Write-Host "  INFO: $($ref.File): Already at version $versionToUse" -ForegroundColor Gray
                    }
                }
            }
            catch {
                Write-Warning "Failed to update $($ref.File): $_"
            }
        }
        
        Write-Host ""
        if ($updateCount -gt 0) {
            Write-Host "SUCCESS: Updated $updateCount version references" -ForegroundColor Green
        } else {
            Write-Host "INFO: No version updates needed" -ForegroundColor Yellow
        }
        
        return $true
    }
    catch {
        Write-Error "Version update failed: $_"
        return $false
    }
}

function Test-PCFControl {
    param(
        [string]$ControlPath,
        [switch]$Fix,
        [switch]$SkipLint,
        [switch]$SkipBuild
    )
    
    Write-Host "=== PCF Control Testing & Validation ===" -ForegroundColor Cyan
    
    Push-Location $ControlPath
    try {
        $success = $true
        
        # Run linting
        if (!$SkipLint) {
            Write-Host "Running ESLint..." -ForegroundColor Green
            if ($Fix) {
                Write-Host "  Auto-fixing linting issues..." -ForegroundColor Yellow
                $success = $success -and (Invoke-NpmCommand "run lint:fix" "ESLint fix" $ControlPath)
            } else {
                $success = $success -and (Invoke-NpmCommand "run lint" "ESLint check" $ControlPath)
            }
        }
        
        # Build to verify compilation
        if (!$SkipBuild) {
            Write-Host "Building control to verify compilation..." -ForegroundColor Green
            $success = $success -and (Invoke-NpmCommand "run clean" "Clean build" $ControlPath)
            $success = $success -and (Invoke-NpmCommand "run build" "Build control" $ControlPath)
        }
        
        # Check TypeScript types
        Write-Host "Refreshing TypeScript types..." -ForegroundColor Green
        $success = $success -and (Invoke-NpmCommand "run refreshTypes" "TypeScript types" $ControlPath)
        
        if ($success) {
            Write-Host "All validations completed successfully!" -ForegroundColor Green
        }
        
        return $success
    }
    finally {
        Pop-Location
    }
}

function Start-PCFDebug {
    param([string]$ControlPath)
    
    Write-Host "=== Starting PCF Debug Session ===" -ForegroundColor Cyan
    
    Push-Location $ControlPath
    try {
        # Install dependencies if needed
        if (!(Test-Path "node_modules")) {
            $success = Invoke-NpmCommand "install" "Installing dependencies" $ControlPath
            if (!$success) { return $false }
        }
        
        # Clean and build
        $success = Invoke-NpmCommand "run clean" "Cleaning build" $ControlPath
        if (!$success) { return $false }
        
        $success = Invoke-NpmCommand "run build" "Building control" $ControlPath
        if (!$success) { return $false }
        
        Write-Host ""
        Write-Host "Starting development server..." -ForegroundColor Green
        Write-Host "Press Ctrl+C to stop the development server" -ForegroundColor Yellow
        Write-Host ""
        
        npm start
        return $true
    }
    finally {
        Pop-Location
    }
}

function Build-PCFRelease {
    param(
        [string]$ControlPath,
        [string]$Version,
        [string]$ProjectRoot,
        [switch]$SkipTest
    )
    
    Write-Host "=== PCF Control Release Build ===" -ForegroundColor Cyan
    
    try {
        # Run tests unless skipped
        if (!$SkipTest) {
            Write-Host "Running validation tests..." -ForegroundColor Green
            $testSuccess = Test-PCFControl -ControlPath $ControlPath
            if (!$testSuccess) {
                Write-Host "Tests failed. Release aborted." -ForegroundColor Red
                return $false
            }
        }
        
        # Update version if specified
        if ($Version) {
            $versionSuccess = Update-PCFVersion -ControlPath $ControlPath -Version $Version
            if (!$versionSuccess) { return $false }
        }
        
        # Build control
        $buildSuccess = Invoke-NpmCommand "run build" "Building PCF control" $ControlPath
        if (!$buildSuccess) { return $false }
        
        # Build solution
        $solutionSuccess = Build-PCFSolution -ControlPath $ControlPath -Configuration "Release"
        if (!$solutionSuccess) { return $false }
        
        # Create distribution
        $success = Create-PCFDistribution -ControlPath $ControlPath -ProjectRoot $ProjectRoot -Version $Version
        if (!$success) { return $false }
        
        Write-Host ""
        Write-Host "Release completed successfully!" -ForegroundColor Green
        if ($Version) {
            Write-Host "Version: $Version" -ForegroundColor Yellow
        }
        Write-Host "Distribution files available in: releases/controls/" -ForegroundColor Yellow
        
        return $true
    }
    catch {
        Write-Error "Release build failed: $_"
        return $false
    }
}

function Create-PCFDistribution {
    param(
        [string]$ControlPath,
        [string]$ProjectRoot,
        [string]$Version
    )
    
    Write-Host "Creating distribution packages..." -ForegroundColor Green
    
    try {
        $solutionsPath = Join-Path $ControlPath "solutions"
        $artifactFolder = Join-Path $solutionPath "bin\Release"
        $destinationFolder = Join-Path $ProjectRoot "releases\controls"
        
        if (!(Test-Path $destinationFolder)) {
            New-Item -Path $destinationFolder -ItemType Directory -Force | Out-Null
        }
        
        # Copy solution files
        $solutionFiles = Get-ChildItem $artifactFolder -Filter "*.zip" -ErrorAction SilentlyContinue
        if ($solutionFiles.Count -eq 0) {
            Write-Warning "No solution zip files found in: $artifactFolder"
            return $false
        }
        
        foreach ($file in $solutionFiles) {
            $destFile = $file.Name
            if ($Version) {
                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                $extension = [System.IO.Path]::GetExtension($file.Name)
                $destFile = "${baseName}_${Version}${extension}"
            }
            
            $destPath = Join-Path $destinationFolder $destFile
            Copy-Item $file.FullName $destPath
            Write-Host "  Created: releases/controls/$destFile" -ForegroundColor Gray
        }
        
        return $true
    }
    catch {
        Write-Error "Distribution creation failed: $_"
        return $false
    }
}

function Test-PacCLI {
    <#
    .SYNOPSIS
    Tests if PAC CLI is available and properly configured
    #>
    try {
        $pacOutput = pac help 2>$null
        if ($LASTEXITCODE -eq 0 -and $pacOutput -like "*Microsoft PowerPlatform CLI*") {
            $versionLine = $pacOutput | Where-Object { $_ -like "*Version:*" } | Select-Object -First 1
            if ($versionLine) {
                Write-Host "PAC CLI detected: $($versionLine.Trim())" -ForegroundColor Gray
            } else {
                Write-Host "PAC CLI detected and available" -ForegroundColor Gray
            }
            return $true
        }
    }
    catch {
        # Command not found
    }
    
    Write-Host "PAC CLI is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Please install Power Platform CLI from:" -ForegroundColor Yellow
    Write-Host "https://learn.microsoft.com/en-us/power-platform/developer/cli/introduction" -ForegroundColor Yellow
    return $false
}

function ConvertTo-PascalCase {
    <#
    .SYNOPSIS
    Converts hyphenated or spaced strings to PascalCase
    #>
    param([string]$InputString)
    
    # If no delimiters found, assume it's already in a valid format and just ensure first letter is uppercase
    if ($InputString -notmatch '[-_\s]+') {
        if ($InputString.Length -gt 0) {
            return $InputString.Substring(0,1).ToUpper() + $InputString.Substring(1)
        }
        return $InputString
    }
    
    # Split on hyphens, underscores, or spaces, then capitalize each word
    $words = $InputString -split '[-_\s]+'
    $pascalCase = ($words | ForEach-Object { 
        if ($_.Length -gt 0) {
            $_.Substring(0,1).ToUpper() + $_.Substring(1).ToLower()
        }
    }) -join ''
    
    return $pascalCase
}

function ConvertTo-FriendlyName {
    <#
    .SYNOPSIS
    Converts component names to user-friendly display format with proper spacing
    #>
    param([string]$InputString)
    
    # Simple approach: always split on hyphens, underscores, or spaces
    # For PascalCase without delimiters, we'll insert spaces before capital letters first
    $processedString = $InputString
    
    # If no delimiters found, insert spaces before capital letters (except first character)
    if ($InputString -notmatch '[-_\s]+' -and $InputString.Length -gt 1) {
        # Use a simple loop to insert spaces before uppercase letters
        $chars = $InputString.ToCharArray()
        $result = ""
        for ($i = 0; $i -lt $chars.Length; $i++) {
            if ($i -gt 0 -and [char]::IsUpper($chars[$i]) -and [char]::IsLower($chars[$i-1])) {
                $result += " "
            }
            $result += $chars[$i]
        }
        $processedString = $result
    }
    
    # Split on delimiters and clean up
    $words = $processedString -split '[-_\s]+' | Where-Object { $_.Trim().Length -gt 0 }
    
    # Capitalize each word and join with spaces
    $friendlyName = ($words | ForEach-Object { 
        $word = $_.Trim()
        if ($word.Length -gt 0) {
            $word.Substring(0,1).ToUpper() + $word.Substring(1).ToLower()
        }
    }) -join ' '
    
    return $friendlyName
}

function Update-PCFSolutionXml {
    <#
    .SYNOPSIS
    Updates the Solution.xml file with proper PCF component configuration
    #>
    param(
        [string]$SolutionXmlPath,
        [hashtable]$ComponentDetails
    )
    
    if (!(Test-Path $SolutionXmlPath)) {
        Write-Warning "Solution.xml not found at: $SolutionXmlPath"
        return $false
    }
    
    try {
        Write-Host "Updating Solution.xml with proper configuration..." -ForegroundColor Green
        
        # Load the XML file
        [xml]$xmlContent = Get-Content $SolutionXmlPath
        
        # Update UniqueName
        $uniqueNameElement = $xmlContent.SelectSingleNode("/ImportExportXml/SolutionManifest/UniqueName")
        if ($uniqueNameElement) {
            $uniqueNameElement.InnerText = $ComponentDetails.SolutionName
            Write-Host "  Updated UniqueName: $($ComponentDetails.SolutionName)" -ForegroundColor Gray
        }
        
        # Update Solution LocalizedName (display name)
        $solutionNameElement = $xmlContent.SelectSingleNode("/ImportExportXml/SolutionManifest/LocalizedNames/LocalizedName")
        if ($solutionNameElement) {
            # Convert the original folder name to a friendly display name
            $friendlyComponentName = ConvertTo-FriendlyName $ComponentDetails.FolderName
            $displayName = "Microsoft Gov - PCF $friendlyComponentName"
            $solutionNameElement.SetAttribute("description", $displayName)
            Write-Host "  Updated Solution Name: $displayName" -ForegroundColor Gray
        }
        
        # Update Publisher LocalizedName (display name)
        $publisherNameElement = $xmlContent.SelectSingleNode("/ImportExportXml/SolutionManifest/Publisher/LocalizedNames/LocalizedName")
        if ($publisherNameElement) {
            $publisherNameElement.SetAttribute("description", $ComponentDetails.Publisher.DisplayName)
            Write-Host "  Updated Publisher Name: $($ComponentDetails.Publisher.DisplayName)" -ForegroundColor Gray
        }
        
        # Update Publisher Description
        $publisherDescElement = $xmlContent.SelectSingleNode("/ImportExportXml/SolutionManifest/Publisher/Descriptions/Description")
        if ($publisherDescElement) {
            $publisherDescElement.SetAttribute("description", $ComponentDetails.Publisher.Description)
            Write-Host "  Updated Publisher Description: $($ComponentDetails.Publisher.Description)" -ForegroundColor Gray
        }
        
        # Update CustomizationOptionValuePrefix
        $optionValuePrefixElement = $xmlContent.SelectSingleNode("/ImportExportXml/SolutionManifest/Publisher/CustomizationOptionValuePrefix")
        if ($optionValuePrefixElement) {
            $optionValuePrefixElement.InnerText = $ComponentDetails.Publisher.CustomizationOptionValuePrefix
            Write-Host "  Updated Option Value Prefix: $($ComponentDetails.Publisher.CustomizationOptionValuePrefix)" -ForegroundColor Gray
        }
        
        # Save the modified XML back to the file
        $xmlContent.Save($SolutionXmlPath)
        Write-Host "  Solution.xml updated successfully!" -ForegroundColor Green
        
        return $true
    }
    catch {
        Write-Error "Failed to update Solution.xml: $_"
        return $false
    }
}

function Select-TargetSolution {
    param([string]$ProjectRoot)
    
    Write-Host ""
    Write-Host "=== Select Target Solution ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Get available solutions
    $solutions = @()
    
    # Add consolidated solution
    $consolidatedPath = Join-Path $ProjectRoot "cross-module\pcf-controls"
    if (Test-Path $consolidatedPath) {
        $solutions += @{
            Name = "MS-Gov-PCF-Controls (Consolidated)"
            Path = $consolidatedPath
            ComponentsPath = "cross-module\pcf-controls\components"
            Type = "Consolidated"
        }
    }
    
    # Scan for other solutions with .cdsproj files
    $searchPaths = @("cross-module", "modules", "federal", "portals")
    foreach ($searchPath in $searchPaths) {
        $basePath = Join-Path $ProjectRoot $searchPath
        if (Test-Path $basePath) {
            $solutionFolders = Get-ChildItem $basePath -Directory
            foreach ($solutionFolder in $solutionFolders) {
                if ($solutionFolder.Name -ne "pcf-controls") { # Skip consolidated, already added
                    $cdsProjFiles = Get-ChildItem $solutionFolder.FullName -Filter "*.cdsproj" -ErrorAction SilentlyContinue
                    if ($cdsProjFiles) {
                        # Get relative path (PowerShell 5.1 compatible)
                        $relativePath = $solutionFolder.FullName.Substring($ProjectRoot.Length + 1).Replace('\', '/')
                        $solutions += @{
                            Name = "$($cdsProjFiles[0].BaseName)"
                            Path = $solutionFolder.FullName
                            ComponentsPath = "$relativePath\components"
                            Type = "Module"
                        }
                    }
                }
            }
        }
    }
    
    # Add legacy option for backward compatibility
    $codeComponentsPath = Join-Path $ProjectRoot "code-components"
    if (Test-Path $codeComponentsPath) {
        $solutions += @{
            Name = "Legacy (code-components)"
            Path = $codeComponentsPath
            ComponentsPath = "code-components"
            Type = "Legacy"
        }
    }
    
    if ($solutions.Count -eq 0) {
        Write-Host "No suitable solutions found. Please ensure you have a solution with a .cdsproj file." -ForegroundColor Red
        return $null
    }
    
    # Display options
    Write-Host "Available solutions:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $solutions.Count; $i++) {
        $solution = $solutions[$i]
        Write-Host "  [$($i + 1)] $($solution.Name) ($($solution.Type))" -ForegroundColor White
        Write-Host "      Path: $($solution.ComponentsPath)" -ForegroundColor Gray
    }
    
    # Get user choice
    Write-Host "\nDefault: Option 1 (Consolidated Solution) will be used if no input provided." -ForegroundColor Gray
    do {
        $choice = Read-Host "Select solution (1-$($solutions.Count)) [default: 1]"
        
        # Default to consolidated solution if no input
        if ([string]::IsNullOrWhiteSpace($choice)) {
            $choice = "1"
        }
        
        if ($choice -match '^[0-9]+$' -and [int]$choice -ge 1 -and [int]$choice -le $solutions.Count) {
            $selectedSolution = $solutions[[int]$choice - 1]
            Write-Host "Selected: $($selectedSolution.Name)" -ForegroundColor Green
            return $selectedSolution
        }
        Write-Host "Please enter a number between 1 and $($solutions.Count)." -ForegroundColor Red
    } while ($true)
}

function Get-PCFComponentDetails {
    <#
    .SYNOPSIS
    Prompts user for PCF component details with validation
    #>
    Write-Host "=== New PCF Component Details ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Component Name
    do {
        $userInput = Read-Host "Component name (e.g., 'test-component', 'enhanced-textbox', or 'CustomGrid')"
        if ([string]::IsNullOrWhiteSpace($userInput)) {
            Write-Host "Component name is required." -ForegroundColor Red
            continue
        }
        
        # Convert to PascalCase for PAC CLI compatibility
        $name = ConvertTo-PascalCase $userInput
        
        # Validate the converted name
        if ($name -notmatch '^[A-Za-z][A-Za-z0-9]*$') {
            Write-Host "Invalid component name. Please use letters, numbers, hyphens, or underscores only." -ForegroundColor Red
            Write-Host "Examples: test-component, enhanced-textbox, CustomGrid" -ForegroundColor Gray
            continue
        }
        
        # Show the conversion if it changed
        if ($userInput -ne $name) {
            Write-Host "  -> Folder name: $userInput" -ForegroundColor Gray
            Write-Host "  -> PAC CLI name: $name" -ForegroundColor Green
        } else {
            Write-Host "  -> Using: $name" -ForegroundColor Green
        }
        
        break
    } while ($true)
    
    # Namespace
    do {
        $defaultNamespace = "MSGov"
        $namespace = Read-Host "Namespace (default: $defaultNamespace)"
        if ([string]::IsNullOrWhiteSpace($namespace)) {
            $namespace = $defaultNamespace
        }
        if ($namespace -notmatch '^[A-Z][A-Za-z0-9]*$') {
            Write-Host "Namespace must start with an uppercase letter and contain only letters and numbers." -ForegroundColor Red
            continue
        }
        break
    } while ($true)
    
    # Template Type
    Write-Host ""
    Write-Host "Available templates:" -ForegroundColor Yellow
    $templates = @(
        @{ Name = "field"; Description = "Custom field control" },
        @{ Name = "dataset"; Description = "Data set control (grid/list)" }
    )
    
    for ($i = 0; $i -lt $templates.Count; $i++) {
        Write-Host "  [$($i + 1)] $($templates[$i].Name) - $($templates[$i].Description)" -ForegroundColor White
    }
    
    do {
        $templateChoice = Read-Host "Select template (1-$($templates.Count))"
        if ($templateChoice -match '^[0-9]+$' -and [int]$templateChoice -ge 1 -and [int]$templateChoice -le $templates.Count) {
            $template = $templates[[int]$templateChoice - 1].Name
            break
        }
        Write-Host "Please enter a number between 1 and $($templates.Count)." -ForegroundColor Red
    } while ($true)
    
    # Solution Name
    $defaultSolutionName = "$($script:PublisherConfig.CustomizationPrefix)_pcf$($userInput.Replace('-', '').Replace('_', '').ToLower())"
    $solutionName = Read-Host "Solution unique name (default: $defaultSolutionName)"
    if ([string]::IsNullOrWhiteSpace($solutionName)) {
        $solutionName = $defaultSolutionName
    }
    
    return @{
        FolderName = $userInput           # Original user input for folder name (e.g., "test-component")
        Name = $name                      # PascalCase version for PAC CLI (e.g., "TestComponent")
        Namespace = $namespace
        Template = $template
        SolutionName = $solutionName
        Publisher = $script:PublisherConfig
    }
}

function Initialize-PCFComponent {
    param(
        [hashtable]$ComponentDetails,
        [string]$ProjectRoot
    )
    
    Write-Host "=== Initializing PCF Component ===" -ForegroundColor Cyan
    
    try {
        # Determine target path based on solution type
        $targetSolution = $ComponentDetails.TargetSolution
        
        if (!$targetSolution) {
            throw "Target solution is not set in component details"
        }
        
        if ($targetSolution.Type -eq "Legacy") {
            # Legacy: create directly in code-components
            $componentsBasePath = Join-Path $ProjectRoot "code-components"
            $componentPath = Join-Path $componentsBasePath $ComponentDetails.FolderName
        }
        else {
            # Modern solutions: create in components subdirectory
            $componentsBasePath = Join-Path $targetSolution.Path "components"
            $componentPath = Join-Path $componentsBasePath $ComponentDetails.FolderName
        }
        
        # Ensure components directory exists
        if (!(Test-Path $componentsBasePath)) {
            New-Item -Path $componentsBasePath -ItemType Directory -Force | Out-Null
            Write-Host "Created components directory: $componentsBasePath" -ForegroundColor Gray
        }
        
        # Create component directory (using original folder name)
        if (Test-Path $componentPath) {
            Write-Host "Component directory already exists: $($ComponentDetails.FolderName)" -ForegroundColor Red
            return $false
        }
        
        New-Item -Path $componentPath -ItemType Directory -Force | Out-Null
        Write-Host "Created component directory: $($ComponentDetails.FolderName)" -ForegroundColor Gray
        
        # Initialize PCF project using PAC CLI
        Push-Location $componentPath
        try {
            Write-Host "Initializing PCF project with PAC CLI..." -ForegroundColor Green
            Write-Host "  Working directory: $componentPath" -ForegroundColor Gray
            Write-Host "  Component details:" -ForegroundColor Gray
            Write-Host "    Folder Name: $($ComponentDetails.FolderName)" -ForegroundColor Gray
            Write-Host "    Component Name: $($ComponentDetails.Name)" -ForegroundColor Gray
            Write-Host "    Namespace: $($ComponentDetails.Namespace)" -ForegroundColor Gray
            Write-Host "    Template: $($ComponentDetails.Template)" -ForegroundColor Gray
            
            # Create the PCF control
            $pacCommand = "pac pcf init --namespace $($ComponentDetails.Namespace) --name $($ComponentDetails.Name) --template $($ComponentDetails.Template)"
            Write-Host "  Running: $pacCommand" -ForegroundColor Gray
            
            # Capture both stdout and stderr for better error reporting
            $pacResult = & cmd /c "$pacCommand 2>&1"
            if ($LASTEXITCODE -ne 0) {
                Write-Host "PAC PCF init output:" -ForegroundColor Red
                $pacResult | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
                throw "PAC PCF init failed with exit code $LASTEXITCODE"
            }
            
            # Show success output
            if ($pacResult) {
                $pacResult | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
            }
            
            # Rename .pcfproj file to use PascalCase component name
            Write-Host "Renaming project file to use PascalCase..." -ForegroundColor Green
            $originalPcfProj = Join-Path $componentPath "$($ComponentDetails.FolderName).pcfproj"
            $newPcfProj = Join-Path $componentPath "$($ComponentDetails.Name).pcfproj"
            
            if (Test-Path $originalPcfProj) {
                if ($originalPcfProj -ne $newPcfProj) {
                    Rename-Item $originalPcfProj $newPcfProj
                    Write-Host "  Renamed: $($ComponentDetails.FolderName).pcfproj -> $($ComponentDetails.Name).pcfproj" -ForegroundColor Gray
                } else {
                    Write-Host "  Project file already has correct name: $($ComponentDetails.Name).pcfproj" -ForegroundColor Gray
                }
            } else {
                Write-Warning "Could not find expected .pcfproj file: $originalPcfProj"
            }
            
            # Install npm dependencies
            Write-Host "Installing npm dependencies..." -ForegroundColor Green
            npm install
            if ($LASTEXITCODE -ne 0) {
                throw "npm install failed"
            }
            
            # Standardize component source folder name to "component" for consistency
            # This must happen AFTER npm install as PAC CLI creates the component source folder during npm install
            Write-Host "Standardizing component source folder name..." -ForegroundColor Green
            
            # PAC CLI creates a folder with just the component name (not namespace.name)
            $originalComponentFolder = Join-Path $componentPath $ComponentDetails.Name
            $standardComponentFolder = Join-Path $componentPath "component"
            
            if (Test-Path $originalComponentFolder) {
                if ($originalComponentFolder -ne $standardComponentFolder) {
                    Rename-Item $originalComponentFolder "component"
                    Write-Host "  Renamed: $($ComponentDetails.Name) -> component" -ForegroundColor Gray
                } else {
                    Write-Host "  Component folder already standardized: component" -ForegroundColor Gray
                }
            } else {
                Write-Warning "Could not find expected component source folder: $originalComponentFolder"
                Write-Host "  Available folders:" -ForegroundColor Gray
                Get-ChildItem $componentPath -Directory | ForEach-Object { Write-Host "    - $($_.Name)" -ForegroundColor Gray }
            }
            
            # Add component to target solution
            if ($targetSolution.Type -eq "Legacy") {
                # Legacy mode: create individual solution in component folder
                Write-Host "Creating individual solution (Legacy mode)..." -ForegroundColor Green
                $solutionPath = Join-Path $componentPath "solution"
                New-Item -Path $solutionPath -ItemType Directory -Force | Out-Null
                
                Push-Location $solutionPath
                try {
                    # Create solution with publisher details
                    $solutionCommand = "pac solution init --publisher-name $($ComponentDetails.Publisher.UniqueName) --publisher-prefix $($ComponentDetails.Publisher.CustomizationPrefix)"
                    Write-Host "  Running: $solutionCommand" -ForegroundColor Gray
                    
                    $solutionResult = & cmd /c "$solutionCommand 2>&1"
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "PAC solution init output:" -ForegroundColor Red
                        $solutionResult | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
                        throw "PAC solution init failed with exit code $LASTEXITCODE"
                    }
                    
                    # Add PCF control to solution
                    $addCommand = "pac solution add-reference --path .."
                    Write-Host "  Running: $addCommand" -ForegroundColor Gray
                    
                    $addResult = & cmd /c "$addCommand 2>&1"
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "PAC solution add-reference output:" -ForegroundColor Red
                        $addResult | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
                        throw "PAC solution add-reference failed with exit code $LASTEXITCODE"
                    }
                    
                    # Update Solution.xml
                    $solutionXmlPath = Join-Path $solutionPath "src\Other\Solution.xml"
                    $xmlUpdateSuccess = Update-PCFSolutionXml -SolutionXmlPath $solutionXmlPath -ComponentDetails $ComponentDetails
                    if (!$xmlUpdateSuccess) {
                        Write-Warning "Solution.xml update failed, but component creation will continue"
                    }
                }
                finally {
                    Pop-Location
                }
            }
            else {
                # Modern mode: add to existing solution
                Write-Host "Adding component to existing solution: $($targetSolution.Name)..." -ForegroundColor Green
                
                # Find the .cdsproj file in the target solution
                $cdsProjFiles = Get-ChildItem $targetSolution.Path -Filter "*.cdsproj" -ErrorAction SilentlyContinue
                if (!$cdsProjFiles) {
                    throw "No .cdsproj file found in target solution: $($targetSolution.Path)"
                }
                
                $cdsProjPath = $cdsProjFiles[0].FullName
                Write-Host "  Solution project: $($cdsProjFiles[0].Name)" -ForegroundColor Gray
                
                # Add component reference to the solution project
                Push-Location $targetSolution.Path
                try {
                    # Get relative path from solution to component (PowerShell 5.1 compatible)
                    $relativePath = $componentPath.Substring($targetSolution.Path.Length + 1).Replace('\', '/')
                    $addCommand = "pac solution add-reference --path $relativePath"
                    Write-Host "  Running: $addCommand" -ForegroundColor Gray
                    
                    $addResult = & cmd /c "$addCommand 2>&1"
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "PAC solution add-reference output:" -ForegroundColor Red
                        $addResult | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
                        throw "PAC solution add-reference failed with exit code $LASTEXITCODE"
                    }
                    
                    Write-Host "  Successfully added component to solution" -ForegroundColor Gray
                }
                finally {
                    Pop-Location
                }
            }
            
            Write-Host "PCF component initialized successfully!" -ForegroundColor Green
            return $true
        }
        finally {
            Pop-Location
        }
    }
    catch {
        Write-Error "PCF component initialization failed: $_"
        
        # Clean up on failure
        if (Test-Path $componentPath) {
            Write-Host "Cleaning up failed initialization..." -ForegroundColor Yellow
            Remove-Item $componentPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        return $false
    }
}

function New-PCFComponent {
    param(
        [string]$ProjectRoot,
        [hashtable]$TargetSolution = $null
    )
    
    Write-Host "=== Create New PCF Component ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This will create a new PCF component using the Power Platform CLI." -ForegroundColor White
    Write-Host "The component will be created with the Microsoft Government Solutions publisher configuration." -ForegroundColor Gray
    Write-Host ""
    
    # Check prerequisites
    if (!(Test-PacCLI)) {
        return $false
    }
    
    # Get target solution - default to consolidated solution for simplicity
    if (!$TargetSolution) {
        Write-Host ""
        Write-Host "=== Target Solution ===" -ForegroundColor Cyan
        
        # Default to consolidated solution
        $consolidatedPath = Join-Path $ProjectRoot "cross-module\pcf-controls"
        if (Test-Path $consolidatedPath) {
            $TargetSolution = @{
                Name = "MS-Gov-PCF-Controls (Consolidated)"
                Path = $consolidatedPath
                ComponentsPath = "cross-module\pcf-controls\components"
                Type = "Consolidated"
            }
            Write-Host "Using consolidated PCF solution: $($TargetSolution.Name)" -ForegroundColor Green
            Write-Host "Components will be added to: cross-module\pcf-controls\components\" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Note: To use a different solution, specify -TargetSolution parameter" -ForegroundColor Yellow
        }
        else {
            Write-Host "Error: Consolidated PCF solution not found at: $consolidatedPath" -ForegroundColor Red
            Write-Host "Please ensure the cross-module\pcf-controls solution exists." -ForegroundColor Red
            return $false
        }
    }
    
    # Validate target solution
    if (!$TargetSolution -or !$TargetSolution.Name -or !$TargetSolution.Path) {
        Write-Host "Error: Invalid target solution." -ForegroundColor Red
        return $false
    }
    
    Write-Host "Using target solution: $($TargetSolution.Name) ($($TargetSolution.Type))" -ForegroundColor Green
    
    # Get component details
    $componentDetails = Get-PCFComponentDetails
    $componentDetails["TargetSolution"] = $TargetSolution
    
    Write-Host ""
    Write-Host "Debug: TargetSolution before assignment: Name=$($TargetSolution.Name), Type=$($TargetSolution.Type)" -ForegroundColor Magenta
    Write-Host "Debug: TargetSolution after assignment: Name=$($componentDetails.TargetSolution.Name), Type=$($componentDetails.TargetSolution.Type)" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "Component Summary:" -ForegroundColor Yellow
    Write-Host "  Folder: $($componentDetails.FolderName)" -ForegroundColor White
    Write-Host "  Component Name: $($componentDetails.Name)" -ForegroundColor White
    Write-Host "  Namespace: $($componentDetails.Namespace)" -ForegroundColor White
    Write-Host "  Template: $($componentDetails.Template)" -ForegroundColor White
    Write-Host "  Target Solution: $($componentDetails.TargetSolution.Name)" -ForegroundColor White
    Write-Host "  Publisher: $($componentDetails.Publisher.DisplayName)" -ForegroundColor White
    Write-Host "  Path: $($componentDetails.TargetSolution.ComponentsPath)/$($componentDetails.FolderName)" -ForegroundColor Gray
    Write-Host ""
    
    $response = Read-Host "Create this component? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y' -and $response -ne 'yes') {
        Write-Host "Component creation cancelled." -ForegroundColor Yellow
        return $false
    }
    
    # Initialize the component
    $success = Initialize-PCFComponent -ComponentDetails $componentDetails -ProjectRoot $ProjectRoot
    
    if ($success) {
        Write-Host ""
        Write-Host "SUCCESS: PCF Component created successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "  1. Edit the control implementation in: code-components/$($componentDetails.FolderName)/component/" -ForegroundColor White
        Write-Host "  2. Run development server: .\\scripts\\PCFControl.ps1 -> Start Development" -ForegroundColor White
        Write-Host "  3. Build and test: .\\scripts\\PCFControl.ps1 -> Run Tests & Validation" -ForegroundColor White
        Write-Host ""
        Write-Host "Documentation: https://learn.microsoft.com/en-us/power-apps/developer/component-framework/" -ForegroundColor Cyan
    }
    
    return $success
}

# Standalone command functions for direct usage
function Show-PCFControls {
    param([string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent))
    
    $controls = Get-PCFControls $ProjectRoot
    
    if ($controls.Count -eq 0) {
        Write-Host "No PCF controls found in code-components folder" -ForegroundColor Yellow
        Write-Host "Controls should be located in: code-components/your-control-name/" -ForegroundColor Gray
    } else {
        Write-Host "Available PCF Controls:" -ForegroundColor Cyan
        foreach ($control in $controls) {
            Write-Host "  - $($control.Name)" -ForegroundColor White
            Write-Host "    Path: $($control.Path)" -ForegroundColor Gray
            Write-Host "    Project: $($control.ProjectFile)" -ForegroundColor Gray
            Write-Host ""
        }
    }
}

# Export functions for direct usage when script is dot-sourced
if ($MyInvocation.InvocationName -eq '&' -or $MyInvocation.InvocationName -eq '.') {
    # Script is being dot-sourced, export functions are available
    Write-Host "PCF Control Utility Functions Loaded:" -ForegroundColor Green
    Write-Host "  - Get-PCFControls" -ForegroundColor Gray
    Write-Host "  - Select-PCFControl" -ForegroundColor Gray  
    Write-Host "  - Test-PCFControl" -ForegroundColor Gray
    Write-Host "  - Start-PCFDebug" -ForegroundColor Gray
    Write-Host "  - Build-PCFRelease" -ForegroundColor Gray
    Write-Host "  - Show-PCFControls" -ForegroundColor Gray
    Write-Host "  - New-PCFComponent" -ForegroundColor Gray
    Write-Host "  - Update-PCFSolutionXml" -ForegroundColor Gray
    Write-Host "  - ConvertTo-FriendlyName" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Example: Show-PCFControls" -ForegroundColor Cyan
    Write-Host "Example: New-PCFComponent '$((Split-Path $PSScriptRoot -Parent))'" -ForegroundColor Cyan
}