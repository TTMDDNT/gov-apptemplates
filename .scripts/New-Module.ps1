
$projectRoot = "$PSScriptRoot\.."
. "${projectRoot}\.scripts\Util.ps1"

# ask which type of ip
$ipType = Select-ItemFromList "agents", "cross-module", "modules", "portals"

$friendlyName = Read-Host "Enter module name (spaces allowed)"

# Clean up folder name: replace non-alphanum with dash, collapse multiple dashes, trim
$solutionFolderName = $friendlyName -replace '[^a-zA-Z0-9]', '-'
$solutionFolderName = $solutionFolderName -replace '-+', '-'
$solutionFolderName = $solutionFolderName.Trim('-')
$solutionFolderName = $solutionFolderName.ToLower()

$pacFriendlyName = $friendlyName -replace '[^a-zA-Z0-9]', ''

# Build Proper-Cased, hyphenated name for the .cdsproj filename (e.g. "Government Financial" -> "Government-Financial")
$projectCasedHyphenName = $friendlyName -replace '[^a-zA-Z0-9]', '-'
$projectCasedHyphenName = $projectCasedHyphenName -replace '-+', '-'
$projectCasedHyphenName = $projectCasedHyphenName.Trim('-')

# Capitalize each token and join with hyphens
$tokens = $projectCasedHyphenName.Split('-') | Where-Object { $_ -ne '' }
$tokens = $tokens | ForEach-Object { if ($_.Length -gt 1) { $_.Substring(0,1).ToUpper() + $_.Substring(1).ToLower() } else { $_.ToUpper() } }
$projectCasedHyphenName = ($tokens -join '-')

$prefix = "msgov"
$publisherPrefix = $prefix

$solutionUniqueName = $friendlyName -replace '[^a-zA-Z0-9\-]', ''   # keep only letters, numbers, dashes
$solutionUniqueName = $solutionUniqueName.ToLower().Replace("-", "_")
$solutionUniqueName = "${prefix}_${solutionUniqueName}"

$publisherSchemaName = "msgovsolutions"
$publisherName = "Microsoft Government Solutions"
$friendlyPrefix = "Microsoft Gov"
$pacFriendlyPrefix = "MS-Gov"

# $solutionUniqueName = "${prefix}_${solutionUniqueName}"
$solutionPath = Join-Path -Path "$PSScriptRoot\.." -ChildPath "$ipType\$pacFriendlyName"

pac solution init --publisher-name $publisherSchemaName --publisher-prefix $publisherPrefix -o $solutionPath

# Only rename if the folder names are different
if ($pacFriendlyName -ne $solutionFolderName) {
    Rename-Item $solutionPath $solutionFolderName
}
$solutionPath = Join-Path -Path "$PSScriptRoot\.." -ChildPath "$ipType\$solutionFolderName"

Update-SolutionName $solutionPath/src/Other/Solution.xml "$friendlyPrefix - $friendlyName"
Update-SolutionUniqueName $solutionPath/src/Other/Solution.xml $solutionUniqueName
Update-SolutionPublisherName $solutionPath/src/Other/Solution.xml $publisherName
Update-SolutionProjectManaged "${solutionPath}\${pacFriendlyName}.cdsproj"
$projFileName = "$pacFriendlyPrefix-$projectCasedHyphenName.cdsproj"
Rename-Item -Path "${solutionPath}\${pacFriendlyName}.cdsproj" -NewName $projFileName

$importAnswer = Read-Host "Build and import into environment as unmanaged solution (y/n)?"

if ($importAnswer -eq 'y') {

    # select deployment configuration
    Write-Host ""
    $deploymentConfig = Select-Deployment

    # connect to the selected tenant
    Write-Host ""
    Write-Host "Connecting to tenant: $($deploymentConfig.Tenant)"
    Connect-DataverseTenant -authProfile $deploymentConfig.Tenant

    # determine target environment based on module type
    $targetEnv = switch ($ipType) {
        "agents" { "GOV APPS" }
        "cross-module" { "GOV UTILITY APPS" }
        "portals" { 
            if ($solutionFolderName -eq "core" -or $friendlyName.ToLower() -like "*core*") {
                "GOV CORE PORTAL"
            } else {
                "GOV PORTALS"
            }
        }
        default { "GOV APPS" }
    }

    # connect to the determined environment
    Write-Host ""
    Write-Host "Connecting to environment: $targetEnv"
    Connect-DataverseEnvironment -envName $targetEnv

    Deploy-Solution "${solutionPath}" -AutoConfirm
}