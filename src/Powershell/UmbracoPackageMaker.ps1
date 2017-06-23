############################################################### 
# Input parameters define the version number for the build, if using a pre-release version
# number, then enter it including the dash, example "-beta", if not using a pre-release version
# then don't enter anything for that value.
###############################################################

param (
	[Parameter(Mandatory=$true)]
	[ValidatePattern("^\d\.\d\.(?:\d\.\d$|\d$)")]
	[string]
	$ReleaseVersionNumber,
	[Parameter(Mandatory=$true)]
	[string]
	[AllowEmptyString()]
	$PreReleaseName
)

###############################################################
# Define some file/folder paths, this assumes that you have output a createdPackages.config
# from Umbraco's package creator in the back office. You will need to do that first to create
# the initial package file and copy that template into the $BuildFolder
###############################################################

# Define the build folder path
$BuildFolder = Join-Path -Path $RepoRoot -ChildPath "build";
# Define the createdPackages.config path
$CreatedPackagesConfig = Join-Path -Path $BuildFolder -ChildPath "createdPackages.config"
# Define the build output (release) folder path
$ReleaseFolder = Join-Path -Path $BuildFolder -ChildPath "Releases\v$ReleaseVersionNumber$PreReleaseName";

# Delete the release folder contents if it exists
if ((Get-Item $ReleaseFolder -ErrorAction SilentlyContinue) -ne $null)
{
	Write-Warning "$ReleaseFolder already exists on your local machine. It will now be deleted."
	Remove-Item $ReleaseFolder -Recurse
}

###############################################################
# DO THE UMBRACO PACKAGE BUILD 
###############################################################

# Load in the XML from the file
$CreatedPackagesConfigXML = [xml](Get-Content $CreatedPackagesConfig)
# Set the version number in createdPackages.config
$CreatedPackagesConfigXML.packages.package.version = "$ReleaseVersionNumber"
$CreatedPackagesConfigXML.Save($CreatedPackagesConfig)

#copy the orig manifest to temp location to be updated to be used for the package
$PackageManifest = Join-Path -Path $BuildFolder -ChildPath "packageManifest.xml"
New-Item -ItemType Directory -Path $TempFolder
Copy-Item $PackageManifest "$TempFolder\package.xml"
$PackageManifest = (Join-Path -Path $TempFolder -ChildPath "package.xml")

# Set the data in packageManifest.config
$PackageManifestXML = [xml](Get-Content $PackageManifest)
$PackageManifestXML.umbPackage.info.package.version = "$ReleaseVersionNumber"
$PackageManifestXML.umbPackage.info.package.name = $CreatedPackagesConfigXML.packages.package.name
$PackageManifestXML.umbPackage.info.package.license.set_InnerXML($CreatedPackagesConfigXML.packages.package.license.get_InnerXML())
$PackageManifestXML.umbPackage.info.package.license.url = $CreatedPackagesConfigXML.packages.package.license.url
$PackageManifestXML.umbPackage.info.package.url = $CreatedPackagesConfigXML.packages.package.url
$PackageManifestXML.umbPackage.info.author.name = $CreatedPackagesConfigXML.packages.package.author.get_InnerXML()
$PackageManifestXML.umbPackage.info.author.website = $CreatedPackagesConfigXML.packages.package.author.url

#clear the files from the manifest
$NewFilesXML = $PackageManifestXML.CreateElement("files")

#package the files ... This will lookup all files in the file system that need to be there and update
# the package manifest XML with the correct data along with copying these files to the  temp folder 
# so they can be zipped with the package

Function WritePackageFile ($f)
{
	Write-Host $f.FullName -foregroundcolor cyan
	$NewFileXML = $PackageManifestXML.CreateElement("file")
	$NewFileXML.set_InnerXML("<guid></guid><orgPath></orgPath><orgName></orgName>")
	$GuidName = ([guid]::NewGuid()).ToString() + "_" + $f.Name
	$NewFileXML.guid = $GuidName	
	$NewFileXML.orgPath = ReverseMapPath $f
	$NewFileXML.orgName = $f.Name
	$NewFilesXML.AppendChild($NewFileXML)
	Copy-Item $f.FullName "$TempFolder\$GuidName"
}
Function ReverseMapPath ($f)
{
	$resultPath = "~"+ $f.Directory.FullName.Replace($WebProjFolder, "").Replace("\","/")	
	Return $resultPath
}
Function MapPath ($f)
{
	$resultPath = Join-Path -Path $WebProjFolder -ChildPath ($f.Replace("~", "").Replace("/", "\"))
	Return $resultPath
}
foreach($FileXML in $CreatedPackagesConfigXML.packages.package.files.file)
{
	$File = Get-Item (MapPath $FileXML)
    if ($File -is [System.IO.DirectoryInfo]) 
    {
        Get-ChildItem -path $File -Recurse `
			| Where-Object { $_ -isnot [System.IO.DirectoryInfo]} `
			| ForEach-Object { WritePackageFile($_) } `
		    | Out-Null	
    }
	else {
		WritePackageFile($File)| Out-Null	
	}
}
$PackageManifestXML.umbPackage.ReplaceChild($NewFilesXML, $PackageManifestXML.SelectSingleNode("/umbPackage/files")) | Out-Null
$PackageManifestXML.Save($PackageManifest)

#finally zip the package
$DestZIP = "$ReleaseFolder\Articulate.zip" 
Add-Type -assembly "system.io.compression.filesystem"
[io.compression.zipfile]::CreateFromDirectory($TempFolder, $DestZIP) 

###############################################################
# Finished creating the Umbraco package format as a zip file
###############################################################
