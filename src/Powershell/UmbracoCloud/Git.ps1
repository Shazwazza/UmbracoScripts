function Invoke-Git
{
    <#
    .Synopsis
        Invoke git, handling its quirky stderr that isn't error

    .PARAMETER IsBoolean
        If this switch is specified, then it will treat the $LASTEXITCODE as a boolean result
        and the method will return a boolean true if it is 0 or false if it is 1

    .Outputs
        Git messages

    .Example
        Invoke-Git push

    .Example
        Invoke-Git "add ."
    #>

    param(
        [Parameter(Mandatory)]
        [string] $Command,

        [switch] $IsBoolean
    )

    try {
        # I could do this in the main script just once, but then the caller would have to know to do that 
        # in every script where they use this function.
        $old_env = $env:GIT_REDIRECT_STDERR
        $env:GIT_REDIRECT_STDERR = '2>&1'

        Write-Verbose "Executing: git $Command ..."
        $output = Invoke-Expression "git $Command "

        if ($LASTEXITCODE -gt 0)
        {
            if ($IsBoolean)
            {
                return $false
            }

            # note: No catch below (only the try/finally). Let the caller handle the exception.
            Throw "Error Encountered executing: 'git $Command '"
        }
        else
        {
            if ($IsBoolean)
            {
                return $true
            }

            # because $output probably has miultiple lines (array of strings), by piping it to write-verbose we get multiple lines.
            # Cannot pipe Write-Information currently, see https://github.com/PowerShell/PowerShell/issues/2559
            $output | Write-Verbose
        }
    }
    # note: No catch here. Let the caller handle it.
    finally
    {
        $env:GIT_REDIRECT_STDERR = $old_env
    }
}

function Push-GitChanges
{
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory)]
        [string] $BranchName
    )

    Invoke-Git "push -u origin `"$BranchName`""

    return $?
}

function Add-GitChanges
{
    <#
    .SYNOPSIS
        Commit Git changes
    .DESCRIPTION
        Commit Git changes
    .PARAMETER Message
        The commit message
    #>
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory)]
        [string] $Message
    )

    Invoke-Git "add -A"
    Invoke-Git "commit -am `"$Message`" --author `"Friendly Upgrade Bot <upgrader@umbraco.io>`""
    return $?
}

function Switch-GitBranch
{
    <#
    .SYNOPSIS
        Checkout a Git branch
    .DESCRIPTION
        Checkout a Git branch
    .PARAMETER BranchName
        The branch name to checkout
    #>
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory)]
        [string] $BranchName
    )

    Invoke-Git "checkout `"$BranchName`""
    return $?
}

function Get-GitBranchExists
{
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory)]
        [string] $BranchName
    )

    $result = Invoke-Git -Command "show-ref --verify --quiet `"refs/heads/$($BranchName)`"" -IsBoolean
    return $result
}

function New-GitBranch
{
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory)]
        [string] $BranchName
    )

    Invoke-Git "branch $BranchName"
    if($LASTEXITCODE -eq 0) {
        Invoke-Git "checkout $BranchName"
        if($LASTEXITCODE -eq 0) {
            Invoke-Git "checkout $BranchName"
        } 
        else {
            throw "Git command failed"
        }
    } 
    else {
        throw "Git command failed"
    }
}

function Copy-CloudRepo
{
    <#
    .SYNOPSIS
        Clone an Umbraco Cloud repository
    .DESCRIPTION
        Clone an Umbraco Cloud repository
    .PARAMETER GitClonePath
        The physical path to clone the repository
    .PARAMETER GitUsername
        Username to use for authenticating
    .PARAMETER GitPassword
        Password to use for authenticating
    .PARAMETER GitAddress
        The Git endpoint
    #>
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory)]
        [string] $GitClonePath,

        [Parameter(Mandatory)]
        [string] $GitUsername,

        [Parameter(Mandatory)]
        [string] $GitPassword,

        [Parameter(Mandatory)]
        [string] $GitAddress
    )
    
    #Ensure the path that the Umbraco Cloud repository will be cloned to
    New-Item -ItemType Directory -Force -Path $GitClonePath

    Add-Type -AssemblyName System.Web

    $UsernameEncoded = [System.Web.HttpUtility]::UrlEncode($GitUsername)
    $UmbCloudPasswordEncoded = [System.Web.HttpUtility]::UrlEncode($GitPassword)
    $currentRemoteUri = New-Object System.Uri $GitAddress
    $newRemoteUrlBuilder = New-Object System.UriBuilder($currentRemoteUri)
    $newRemoteUrlBuilder.UserName = $UsernameEncoded 
    $newRemoteUrlBuilder.Password = $UmbCloudPasswordEncoded
    $gitAuthenticatedUrl = $newRemoteUrlBuilder.ToString()
    Invoke-Git "clone `"${gitAuthenticatedUrl}`" `"${GitClonePath}`""
}
