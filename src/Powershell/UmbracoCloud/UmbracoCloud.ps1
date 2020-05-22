function Move-BuildOutputToUmbracoCloud {

    <#
    .SYNOPSIS
        Deploys the build output of a Web Application project to Umbraco Cloud deployment repository.
    .DESCRIPTION
        Deploys the build output of a Web Application project to Umbraco Cloud deployment repository.
    .PARAMETER UmbCloudUrl
        The Umbraco Cloud Git deployment URL.
    .PARAMETER UmbCloudUsername
        The Umbraco Cloud Git username.
    .PARAMETER UmbCloudPassword
        The Umbraco Cloud Git password.
    .PARAMETER SourcePath
        The build output of the web application project to copy over to the Umbraco Cloud repository.
    .PARAMETER DestinationPath
        The folder to clone the Umbraco Cloud repository to which will be updated with the build output.
    #>
    [CmdletBinding(DefaultParameterSetName = 'None')]
    [Alias('Publish-ToUmbracoCloud')]
    param
    (
        [String] [Parameter(Mandatory = $true)]
        $UmbCloudUrl,
    
        [String] [Parameter(Mandatory = $true)]
        $UmbCloudUsername,
    
        [String] [Parameter(Mandatory = $true)]
        $UmbCloudPassword,
        
        [String] [Parameter(Mandatory = $true)]
        $SourcePath,
        
        [String] [Parameter(Mandatory = $true)]
        $DestinationPath
    )
    
    #Clone the Umbraco Cloud repository
    Write-Verbose "Cloning Umbraco Cloud repository $UmbCloudUrl to $DestinationPath..."
    Copy-CloudRepo -GitClonePath $DestinationPath -GitUsername $UmbCloudUsername -GitPassword $UmbCloudPassword -GitAddress $UmbCloudUrl
    
    #Copy the buildout to the Umbraco Cloud repository excluding the umbraco and umbraco_client folders
    Write-Verbose "Copying Build output to the Umbraco Cloud repository..."
    Get-ChildItem -Path $SourcePath | % { Copy-Item $_.fullname "$DestinationPath" -Recurse -Force -Exclude @("umbraco", "umbraco_client") }
    
    #Change location to the Path where the Umbraco Cloud repository is cloned
    Set-Location -Path $DestinationPath
    
    #Silence warnings about LF/CRLF
    Write-Verbose "Silence warnings about LF/CRLF"
    Invoke-Git "config core.safecrlf false"
    
    #Commit the build output to the Umbraco Cloud repository
    Invoke-Git "status"
    Invoke-Git "add -A"
    Write-Verbose "Committing changes to repository..."
    Invoke-Git "-c user.name=`"Umbraco Cloud`" -c user.email=`"support@umbraco.io`" commit -m `"Committing build output from VSTS`" --author=`"Umbraco Cloud <support@umbraco.io>`""
    
    #Push the added files to Umbraco Cloud
    Write-Verbose "Deploying to Umbraco Cloud..."
    Invoke-Git "push origin master"
    
    #Remove credentials from the configured remote
    Invoke-Git "remote set-url `"origin`" $UmbCloudUrl"
    
    Write-Verbose "Deployment finished"

}

function Invoke-PackageAutoUpgrade {

    <#
    .SYNOPSIS
        Checks for package updates and if there are any will upgrade the source code repository and submit a Pull Requet.
    .DESCRIPTION
        Checks for package updates and if there are any will upgrade the source code repository and submit a Pull Requet.
    .PARAMETER PackageName
        The Nuget package name to check for upgrades.
    .PARAMETER ProjectFile
        The full path to the sln or csproj file to upgrade.
    .PARAMETER PackageFile
        The virtual path to the packages.config file to check for ugprades on the GitHub repository.
    .PARAMETER GitHubOwner
        The GitHub owner name.
    .PARAMETER GitHubRepository
        The GitHub repository name.
    .PARAMETER GitHubAccessToken
        The GitHub access token.
    .PARAMETER DoNotCommit
        Flag if set will not commit changes and therefor not push or create a PR
    .PARAMETER DoNotPush
        Flag if set will not push committed changes and therefor not create a PR
    .PARAMETER DoNotPR
        Flag if set will not create a PR from the pushed and committed changes
    #>
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param
    (
        [String] [Parameter(Mandatory = $true)]
        $PackageName,
    
        [String] [Parameter(Mandatory = $true)]
        $ProjectFile,

        # TODO: don't explicitly pass this in, if its an sln file we need to loop over the csproj files and automatically detect, 
        # same with a csproj we should auto-detect this path, but that might be difficult to do since we don't know how the repo is structured.
        # For now, this is fine.
        [String] [Parameter(Mandatory = $true)]
        $PackageFile,
    
        [String] [Parameter(Mandatory = $true)]
        $GitHubOwner,
    
        [String] [Parameter(Mandatory = $true)]
        $GitHubRepository,
    
        [String] [Parameter(Mandatory = $true)]
        $GitHubAccessToken,

        [switch]
        $DoNotCommit,
        [switch]
        $DoNotPush,
        [switch]
        $DoNotPR
    )
    
    # Variables
    
    $buildFolder = $PSScriptRoot
    $tempFolder = "$env:temp\UmbracoCloudPs"
    $repoRoot = (Get-Item $buildFolder).Parent
    
    try {
        # Get version in GitHub
        Write-Verbose "Getting latest version of $PackageName from GitHub"
        $packageVersion = Get-CurrentPackageVersion -OwnerName $GitHubOwner -RepositoryName $GitHubRepository -AccessToken $GitHubAccessToken -PackageFile $PackageFile -PackageName $PackageName
        if (!$packageVersion) {
            Throw "Could not determine package version, cannot continue"
        }
        Write-Verbose "Latest local version of $PackageName is $packageVersion"
    
        # Get the latest version from Nuget
    
        Write-Verbose "Getting latest version of $PackageName from Nuget"
        $nuget = Get-NugetExe -DestinationFolder $tempFolder
        $latest = Get-LatestPackageVersion -PackageName $PackageName
        if (!$packageVersion) {
            Throw "Could not determine package version, cannot continue"
        }
        Write-Verbose "Latest nuget version of $PackageName is $latest"
    
        # Compare versions, next we need to run nuget + PR
        $hasUpgrade = Get-UpgradeAvailable -SourceVersion $packageVersion -DestVersion $latest
    
        if ($hasUpgrade -eq $true) {
            Write-Verbose "An upgrade is available!"
    
            $branchName = "$PackageName-upgrade-$latest";
    
            Write-Verbose "Checking if a PR is already created..."
            $pr = Get-PullRequest -OwnerName $GitHubOwner -RepositoryName $GitHubRepository -AccessToken $GitHubAccessToken -BranchName $branchName
            if ($pr) {
                throw "A Pull Request already exists for this upgrade"
            }
    
            $msbuild = Get-MSBuildExe -DestinationFolder $tempFolder -NugetExe $nuget
            Write-Verbose "MSBuild found at $msbuild"
            $msbuildPath = (Get-Item $msbuild).Directory.FullName
    
            Write-Verbose "Creating Git Branch '$branchName' ..."
            $branchExists = Get-GitBranchExists -BranchName $branchName
            if ($branchExists -eq $true) {
                Write-Verbose "Branch $branchName already exists, updating to branch"
                Switch-GitBranch -BranchName $branchName
                # throw "Branch $branchName already exists"
            }
            else {
                New-GitBranch -BranchName $branchName
            }
        
            Write-Verbose "Upgrading project..."
            Update-NugetPackage -PackageName $PackageName -PackageVersion $latest -ProjectFile $ProjectFile -RootGitDirectory $($repoRoot.FullName) -NugetExe $nuget -MSBuildPath $msbuildPath
    
            # Write-Verbose "Building project..."
            # Build-Project -MSBuildExe $msbuild -ProjectFile $ProjectFile
    
            # TODO: Potentially we need to revert all /Config/* files because this will overright them and we dont want to commit those changes
            # However in some cases we might want to see what those changes are so for now we'll leave it up to the developer to review the changes
            # and revert what they want.
            # This all depends on the Nuget behavior IgnoreAll, etc...

            if ($false -eq $DoNotCommit) {
                Write-Verbose "Committing changes..."
                Add-GitChanges -Message "Updated files for the $PackageName $latest Nuget upgrade"
            
                if ($false -eq $DoNotPush) {
                    Write-Verbose "Pushing changes..."
                    Push-GitChanges -BranchName $branchName
            
                    if ($false -eq $DoNotPR) {
                        Write-Verbose "Creating pull request..."                
                        $pr = New-PullRequest -OwnerName $GitHubOwner -RepositoryName $GitHubRepository -AccessToken $GitHubAccessToken -PackageVersion $latest -PackageName $PackageName -BranchName $branchName
                    }
                }
            }
        }
        else {
            Write-Verbose "Nothing to upgrade"
        }
    }
    finally {
        # Clear temp files
        Remove-Item $tempFolder -Recurse
    }
}