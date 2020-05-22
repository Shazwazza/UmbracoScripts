function Build-Project
{
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(

        [Parameter(Mandatory)]
        [string] $ProjectFile,

        [Parameter(Mandatory)]
        [string] $MSBuildExe
    )

    & $MSBuildExe $ProjectFile
}

function Get-MSBuildExe
{
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory)]
        [string] $DestinationFolder,

        [Parameter(Mandatory)]
        [string] $NugetExe
    )

    (New-Item -ItemType Directory -Force -Path $DestinationFolder) | Out-Null
	(New-Item "$DestinationFolder\vswhere" -type directory -force) | Out-Null

    $path = "$DestinationFolder\vswhere"
	$vswhere = "$DestinationFolder\vswhere.exe"
	if (-not (test-path $vswhere))
	{
	   Write-Verbose "Download VsWhere..."
	   &$NugetExe install vswhere -OutputDirectory $path -Verbosity quiet
	   $dir = ls "$path\vswhere.*" | sort -property Name -descending | select -first 1
	   $file = ls -path "$dir" -name vswhere.exe -recurse
	   mv "$dir\$file" $vswhere   
	 }

	$MSBuild = &$vswhere -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe | select-object -first 1
	if (-not (test-path $MSBuild)) {
	    throw "MSBuild not found!"
	}

    return $MSBuild
}
