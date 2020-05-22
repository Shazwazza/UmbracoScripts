function Get-CurrentPackageVersion
{
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory)]
        [string] $OwnerName,

        [Parameter(Mandatory)]
        [string] $RepositoryName,

        [Parameter(Mandatory)]
        [string] $AccessToken,

        [Parameter(Mandatory)]
        [string] $PackageFile,

        [Parameter(Mandatory)]
        [string] $PackageName
    )

    Add-Type -AssemblyName System.Xml.Linq

    # TODO: We could auth everything like this, else we can pass the access token to each method

    # $secureString = "ACCESSTOKENHERE" | ConvertTo-SecureString -AsPlainText -Force
    # $cred = New-Object System.Management.Automation.PSCredential "<username is ignored>", $secureString
    # Set-GitHubAuthentication -Credential $cred -SessionOnly

    Set-GitHubConfiguration -DisableTelemetry -DisableLogging

    $contentResult = Get-GitHubContent -OwnerName $OwnerName -RepositoryName $RepositoryName -Path $PackageFile -MediaType Raw -AccessToken $AccessToken    
    $xmlStream = New-Object System.IO.MemoryStream
    $xmlStream.Write($contentResult, 0, $contentResult.Length)
    $xmlStream.Position = 0
    $reader = New-Object System.Xml.XmlTextReader($xmlStream)
    $xml = [System.Xml.Linq.XDocument]::Load($reader)
    $reader.Dispose()
    $xmlStream.Dispose()

    # Write-Verbose "package.config output: $xml"

    $xpath = "string(//package[@id='$PackageName']/@version)"
    $packageVersion = [string][System.Xml.XPath.Extensions]::XPathEvaluate($xml, $xpath);    
    
    Write-Verbose "$PackageName version = $packageVersion"

    return $packageVersion.ToString()
}

function Get-PullRequest
{
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory)]
        [string] $OwnerName,

        [Parameter(Mandatory)]
        [string] $RepositoryName,

        [Parameter(Mandatory)]
        [string] $AccessToken,

        [Parameter(Mandatory)]
        [string] $BranchName
    )

    Set-GitHubConfiguration -DisableTelemetry -DisableLogging

    $pullRequests = Get-GitHubPullRequest -OwnerName $OwnerName -RepositoryName $RepositoryName -AccessToken $AccessToken -Head "$($OwnerName):$($BranchName)"
    return $pullRequests
}

function New-PullRequest
{
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory)]
        [string] $OwnerName,

        [Parameter(Mandatory)]
        [string] $RepositoryName,

        [Parameter(Mandatory)]
        [string] $AccessToken,

        [Parameter(Mandatory)]
        [string] $PackageVersion,

        [Parameter(Mandatory)]
        [string] $PackageName,

        [Parameter(Mandatory)]
        [string] $BranchName
    )

    Set-GitHubConfiguration -DisableTelemetry -DisableLogging

    $prParams = @{
        OwnerName = $OwnerName
        Repository = $RepositoryName
        Title = "$PackageName $PackageVersion Update"
        Head = "$($OwnerName):$($BranchName)"
        Base = 'master'
        Body = "The Friendly Upgrade Bot has an update ready for you."
        MaintainerCanModify = $true
        AccessToken = $AccessToken
    }
    $pr = New-GitHubPullRequest @prParams

    return $pr
}