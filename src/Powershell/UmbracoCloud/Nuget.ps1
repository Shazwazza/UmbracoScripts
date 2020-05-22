function Get-NugetExe
{
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory)]
        [string] $DestinationFolder
    )

    (New-Item -ItemType Directory -Force -Path $DestinationFolder) | Out-Null

    $sourceNugetExe = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
    $nugetExePath = Join-Path $DestinationFolder "nuget.exe"

    if (-not (Test-Path $nugetExePath -PathType Leaf)) 
    {
        Invoke-WebRequest $sourceNugetExe -OutFile $nugetExePath
    }

    return $nugetExePath
}

function Update-NugetPackage
{
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory)]
        [string] $PackageName,

        [Parameter(Mandatory)]
        [string] $ProjectFile,

        [Parameter(Mandatory)]
        [string] $RootGitDirectory,

        [Parameter(Mandatory)]
        [string] $NugetExe,

        [Parameter(Mandatory)]
        [string] $MSBuildPath,

        [switch] $Safe
    )

    $projFile = Get-Item $ProjectFile
    if ($projFile.Exists -eq $false){
        throw "The project file does not exist $ProjectFile"
    }

    Write-Verbose "Running Nuget restore/update for package $PackageName ..."

    $MSBuildPath = "$($MSBuildPath.TrimEnd('\\'))"

    $nugetConfigFile = Find-NugetConfig -CurrentDirectory $($projFile.Directory.FullName) -RootGitDirectory $RootGitDirectory
    $nugetConfigFilePath = $nugetConfigFile.FullName

    # The folder where packages will be downloaded to which by convention is always
    # in the /packages folder relative to the nuget.config file.
    $packagesPath = Join-Path $($nugetConfigFile.Directory.FullName) "packages"

    # First we need to do a nuget restore
    $nugetResult = Invoke-NugetRestore -NugetExe "$NugetExe" -ProjectFile "$ProjectFile" -NugetConfigFile "$nugetConfigFilePath" -PackagesPath "$packagesPath" -MSBuildPath "$MSBuildPath"
    if ($nugetResult -eq $true)
    {
        # Then we can do a nuget update
        Invoke-NugetUpdate -NugetExe "$NugetExe" -PackageName "$PackageName" -ProjectFile "$ProjectFile" -NugetConfigFile "$nugetConfigFilePath" -PackagesPath "$packagesPath" -MSBuildPath "$MSBuildPath" -Safe:$Safe
    }
}

function Invoke-NugetRestore
{
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory)]
        [string] $NugetExe,

        [Parameter(Mandatory)]
        [string] $ProjectFile,

        [Parameter(Mandatory)]
        [string] $NugetConfigFile,

        [Parameter(Mandatory)]
        [string] $PackagesPath,

        [Parameter(Mandatory)]
        [string] $MSBuildPath
    )

    if ((Get-Item $NugetExe).Exists -eq $false) {
        throw "The Nuget exe file does not exist $NugetExe"
    }  

    Write-Verbose "Running Nuget restore..."

    & $NugetExe restore "$ProjectFile" -ConfigFile "$NugetConfigFile" -PackagesDirectory "$PackagesPath" -Project2ProjectTimeOut 20 -NonInteractive -MSBuildPath "$MSBuildPath"

    if($LASTEXITCODE -eq 0) {
        return $true
    }
    else {
        throw "An error occurred, quitting"
    }
}

function Invoke-NugetUpdate
{
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory)]
        [string] $NugetExe,

        [Parameter(Mandatory)]
        [string] $PackageName,

        [Parameter(Mandatory)]
        [string] $ProjectFile,

        [Parameter(Mandatory)]
        [string] $NugetConfigFile,

        [Parameter(Mandatory)]
        [string] $PackagesPath,

        [Parameter(Mandatory)]
        [string] $MSBuildPath,

        [switch] $Safe
    )

    if ((Get-Item $NugetExe).Exists -eq $false) {
        throw "The Nuget exe file does not exist $NugetExe"
    }

    Write-Verbose "Running Nuget update..."

    # TODO: 'overwrite' is not right, but IgnoreAll and Ignore ends up deleting files!@
    # TODO: Try running the update/build against the SLN instead of just the csproj!

    if ($Safe) {
        & $NugetExe update "$ProjectFile" -ConfigFile "$NugetConfigFile" -RepositoryPath "$PackagesPath" -Id $PackageName -FileConflictAction overwrite -NonInteractive -MSBuildPath "$MSBuildPath" -safe
    }
    else {
        & $NugetExe update "$ProjectFile" -ConfigFile "$NugetConfigFile" -RepositoryPath "$PackagesPath" -Id $PackageName -FileConflictAction overwrite -NonInteractive -MSBuildPath "$MSBuildPath"
    }
    
    if($LASTEXITCODE -eq 0) {
        return $true
    }
    else {
        throw "An error occurred, quitting"
    }
}

function Find-NugetConfig
{
   [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory)]
        [string] $CurrentDirectory,

        [Parameter(Mandatory)]
        [string] $RootGitDirectory
    )

    $folder = Get-Item $CurrentDirectory

    Write-Verbose "Finding Nuget.config, current folder: $CurrentDirectory"

    $nugetConfigFiles = Get-ChildItem -Path $CurrentDirectory -Filter "NuGet.config"

    if ($nugetConfigFiles.Count -eq 0)
    {
        if ($CurrentDirectory.ToLower() -eq $RootGitDirectory.ToLower()) {
            throw "No Nuget.config file found in repository"
        }   

        # move up
        $parent = $folder.Parent;
        if ($null -eq $parent -or $parent.Exists -eq $false){
            throw "No Nuget.config file found on file system"
        }   

        # recurse
        return Find-NugetConfig -CurrentDirectory $parent.FullName -RootGitDirectory $RootGitDirectory
    }

    Write-Verbose "Found nuget config $($nugetConfigFiles[0].FullName)"
    return $nugetConfigFiles[0];
}

function Get-LatestPackageVersion
{
    <#
    .SYNOPSIS
        Gets the latest version of a package from a Nuget package repository
    .DESCRIPTION
        Gets the latest version of a package from a Nuget package repository
    .PARAMETER PackageName
        The package name to get the latest version for 
    #>
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory)]
        [string] $PackageName
    )

    $nugetOutput = & $nuget list "PackageId:$PackageName" -NonInteractive | Out-String

    $nugetVersions = $nugetOutput.Split([System.Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)

    $latestVersion = $nugetVersions |
        Sort-Object { ([semver] $_.Split(' ')[1]) } |
            Select-Object -Last 1
    $latestSemver = $latestVersion.Split(' ')[1]

    return $latestSemver
}

function Get-UpgradeAvailable
{
    <#
    .SYNOPSIS
        Compares to semver versions and returns $true if the DestVersion is greater than SourceVersion
    .DESCRIPTION
        Compares to semver versions and returns $true if the DestVersion is greater than SourceVersion
    .PARAMETER SourceVersion
        The source version
    .PARAMETER DestVersion
        The destination version    
    #>
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory)]
        [string] $SourceVersion,

        [Parameter(Mandatory)]
        [string] $DestVersion
    )

    $sourceSemver = [semver] $SourceVersion
    $destSemver = [semver] $DestVersion

    return $sourceSemver.CompareTo($destSemver).Equals(-1)
}