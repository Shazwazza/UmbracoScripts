function Get-NugetExe {
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory)]
        [string] $DestinationFolder
    )

    (New-Item -ItemType Directory -Force -Path $DestinationFolder) | Out-Null

    $sourceNugetExe = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
    $nugetExePath = Join-Path $DestinationFolder "nuget.exe"

    if (-not (Test-Path $nugetExePath -PathType Leaf)) {
        Invoke-WebRequest $sourceNugetExe -OutFile $nugetExePath
    }

    return $nugetExePath
}

function Update-NugetPackage {
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory)]
        [string] $PackageName,

        [Parameter(Mandatory)]
        [string] $PackageVersion,

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
    if ($projFile.Exists -eq $false) {
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
    if ($nugetResult -eq $true) {
        # Then we can do a nuget update
        Invoke-NugetUpdate -NugetExe "$NugetExe" -PackageName "$PackageName" -PackageVersion "$PackageVersion" -ProjectFile "$ProjectFile" -NugetConfigFile "$nugetConfigFilePath" -PackagesPath "$packagesPath" -MSBuildPath "$MSBuildPath" -Safe:$Safe
    }
}

function Invoke-NugetRestore {
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

    if ($LASTEXITCODE -eq 0) {
        return $true
    }
    else {
        throw "An error occurred, quitting"
    }
}

function Invoke-NugetUpdate {
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory)]
        [string] $NugetExe,

        [Parameter(Mandatory)]
        [string] $PackageName,

        [Parameter(Mandatory)]
        [string] $PackageVersion,

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

    # Get all csproj files that we are upgrading
    $csProjs = Get-CSProjFilesForUpdate -PackageName $PackageName -PackageVersion $PackageVersion -ProjectFile $ProjectFile

    Write-Verbose "Running Nuget update..."

    if ($Safe) {
        & $NugetExe update "$ProjectFile" -ConfigFile "$NugetConfigFile" -RepositoryPath "$PackagesPath" -Id $PackageName -Version $PackageVersion -FileConflictAction IgnoreAll -NonInteractive -MSBuildPath "$MSBuildPath" -safe -Verbosity detailed
    }
    else {
        & $NugetExe update "$ProjectFile" -ConfigFile "$NugetConfigFile" -RepositoryPath "$PackagesPath" -Id $PackageName -Version $PackageVersion -FileConflictAction IgnoreAll -NonInteractive -MSBuildPath "$MSBuildPath" -Verbosity detailed
    }

    if (!($LASTEXITCODE -eq 0)) {
        throw "An error occurred, quitting"
    }

    # Run the install.ps1 scripts in the nuget tools for each project updated
    foreach($csProj in $csProjs) {
        Write-Verbose "Finding tools/install.ps1 for $csProj"
        Invoke-NugetToolsScripts -PackagesPath $PackagesPath -PackageName $PackageName -PackageVersion $PackageVersion -CsProjFile $csProj
    }    
}

function Invoke-NugetToolsScripts {
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory)]
        [string] $PackagesPath,

        [Parameter(Mandatory)]
        [string] $PackageName,

        [Parameter(Mandatory)]
        [string] $PackageVersion,

        [Parameter(Mandatory)]
        [string] $CsProjFile
    )

    # TODO: After running this we need to manually call the /tools/install.ps1 script - since we don't know what they will do we can filter this to only run
    # when it's the UmbracoCms. But to do that we need to pass in the correct params which is difficult to figure out. 
    # the script takes these params param($installPath, $toolsPath, $package, $project)
    # * installPath: $installPath is the path to the folder where the package is installed. By default: $(solutionDir)\packages
    #       ... which (for example): C:\Users\Shannon\Documents\_Projects\Shazwazza\Repo\shazwazza.com\src\packages\UmbracoCms.8.6.1
    # * $toolPath is the path to the \tools directory in the folder where the package is installed. By default: $(solutionDir)\packages\[packageId]-[version]\tools
    #       ... which (for example): C:\Users\Shannon\Documents\_Projects\Shazwazza\Repo\shazwazza.com\src\packages\UmbracoCms.8.6.1\tools
    # * $package is a reference to the package object 
    #       ... NOT USED FOR UMBRACO
    # * $project is a reference to the target EnvDTE project object. This object is defined here.
    #       ... $projectPath = (Get-Item $project.Properties.Item("FullPath").Value).FullName is used for UMBRACO
    #       ... which (for example): C:\Users\Shannon\Documents\_Projects\Shazwazza\Repo\shazwazza.com\src\Shazwazza.Web\
    # see https://stackoverflow.com/a/41999946/694494
    # The source file for the VS console nuget manager is here 
    # C:\Program Files (x86)\Microsoft Visual Studio\2019\Preview\Common7\IDE\CommonExtensions\Microsoft\NuGet\Modules\NuGet

    # first we need to construct the "installPath"
    $installPath = Join-Path $PackagesPath "$PackageName.$PackageVersion"
    if (!(Test-Path -Path $installPath)) {
        throw "Could not find the installed package folder at $installPath"
    }
    $toolsPath = Join-Path $installPath "tools"
    if (Test-Path -Path $toolsPath) {
        $installScript = Join-Path $toolsPath "install.ps1"
        if (Test-Path -Path $installScript) {
            # Ok, we can execute

            # The last step is to 'fake' the $project object
            $projectProperties = New-Object -TypeName PSObject
            $projectProperties | Add-Member -MemberType ScriptMethod -Name Item -Value {
                param([string]$val)
                return @{
                    # return the path of the project being updated
                    Value = (Get-Item $CsProjFile).Directory.FullName
                }
            }
            $project = New-Object -TypeName PSObject
            $project | Add-Member -MemberType NoteProperty -Name Properties -Value $projectProperties

            # Then we need to fake a $DTE object
            $itemOps = New-Object -TypeName PSObject
            $itemOps | Add-Member -MemberType ScriptMethod -Name OpenFile -Value {
                param([string]$val)
                # nop
            }
            $DTE = New-Object -TypeName PSObject
            $DTE | Add-Member -MemberType NoteProperty -Name ItemOperations -Value $itemOps

            Write-Verbose "Found tools/install.ps1 script in Nuget package. Executing script..."
            & $installScript $installPath $toolsPath $null $project | Out-Null
            Write-Verbose "tools/install.ps1 completed"
        }
    }
}

function Get-CSProjFilesForUpdate {

    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory)]
        [string] $PackageName,

        [Parameter(Mandatory)]
        [string] $PackageVersion,

        [Parameter(Mandatory)]
        [string] $ProjectFile
    )

    Add-Type -AssemblyName System.Xml.Linq

    # the project file can be an sln or a csproj. If it's an sln, get all csproj's for it
    # then check if they will be upgraded

    # Get all csproj's that were upgraded
    $csprojs = New-Object Collections.Generic.List[string]
    $fileExt = [System.IO.Path]::GetExtension($ProjectFile)
    if ($fileExt -eq ".sln") {
        $slnPath = (Get-Item $ProjectFile).Directory.FullName
        # read in sln file contents
        $slnContent = Get-Content -Path $ProjectFile -Raw
        # parse out all csproj's
        $regex = "^Project\(\`".+?, \`"(.+\.csproj)\`""
        $m = [regex]::Matches($slnContent, $regex, [System.Text.RegularExpressions.RegexOptions]::Multiline)
        # add all csproj's to the list
        foreach ($i in $m) {
            $csprojRelativePath = $i.Groups[1].Value;
            $csprojAbsPath = Join-Path -Path $slnPath -ChildPath $csprojRelativePath
            # get the packages.config file for this csproj to see if it references the package            
            $packagesConfig = (Get-Item $csprojAbsPath).Directory.GetFiles("packages.config")
            if ($packagesConfig.Length -gt 0){
                
                # if the version for this csproj doesn't match our target version then add it to the list
                $xml = [System.Xml.Linq.XDocument]::Load($packagesConfig[0].FullName)
                $xpath = "string(//package[@id='$PackageName']/@version)"
                $version = [string][System.Xml.XPath.Extensions]::XPathEvaluate($xml, $xpath);    
                
                if ($PackageVersion -ne $version){
                    $csprojs.Add($csprojAbsPath)
                }
            }            
        }
    }
    else {
        $csprojs.Add($ProjectFile)
    }

    Write-Verbose "The .csproj files being updated are $csprojs"

    return $csprojs
}

function Find-NugetConfig {
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

    if ($nugetConfigFiles.Count -eq 0) {
        if ($CurrentDirectory.ToLower() -eq $RootGitDirectory.ToLower()) {
            throw "No Nuget.config file found in repository"
        }   

        # move up
        $parent = $folder.Parent;
        if ($null -eq $parent -or $parent.Exists -eq $false) {
            throw "No Nuget.config file found on file system"
        }   

        # recurse
        return Find-NugetConfig -CurrentDirectory $parent.FullName -RootGitDirectory $RootGitDirectory
    }

    Write-Verbose "Found nuget config $($nugetConfigFiles[0].FullName)"
    return $nugetConfigFiles[0];
}

function Get-LatestPackageVersion {
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

function Get-UpgradeAvailable {
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