#
# Press 'F5' to run this script. Running this script will load the ConfigurationManager
# module for Windows PowerShell and will connect to the site.
#
# This script was auto-generated at '2/17/2020 2:02:38 PM'.

# Uncomment the line below if running in an environment where script signing is 
# required.
#Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Site configuration
$SiteCode = "sitecode" # Site code 
$ProviderMachineName = "siteserver" # SMS Provider machine name

# Customizations
$initParams = @{}
#$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
#$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors

# Do not change anything below this line

# Import the ConfigurationManager.psd1 module 
if ((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}

# Connect to the site's drive if it is not already present
if ((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}

# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams

$PossibleCollections = "Imaging Applications",
"SW Available - Patch My PC Base Applications"

$Collection = $PossibleCollections | Out-GridView -Title "Select collection to use for deployment" -PassThru

#Select applications to deploy to $collection
$ApplicationsInFolder = @( Get-WMIObject -Namespace "root\SMS\Site_SiteCode" -ComputerName "siteserver" -Query "SELECT * FROM SMS_ApplicationLatest WHERE ObjectPath = '/Patch My PC' " | 
    Select-Object -Property LocalizedDisplayName, CI_ID, CI_UniqueID | 
    Sort-Object -Property LocalizedDisplayName |
    Out-GridView -Title "Select applications to deploy" -PassThru 
)

#Deploy selected applications to $collection
foreach ($application in $ApplicationsInFolder) {
    New-CMApplicationDeployment -Id $application.CI_ID -CollectionName $Collection -DeployAction Install -DeployPurpose Available -UserNotification DisplaySoftwareCenterOnly -Comment "Script-generated deployment to Users" -Verbose
}

#Select applications that will have a deployment to $collection removed
$AppstoRemoveDeployments = @( Get-WMIObject -Namespace "root\SMS\Site_SiteCode" -ComputerName "siteserver" -Query "SELECT * FROM SMS_ApplicationLatest WHERE ObjectPath = '/Patch My PC' " | 
    Select-Object -Property LocalizedDisplayName, CI_ID, CI_UniqueID | 
    Sort-Object -Property LocalizedDisplayName |
    Out-GridView -Title "Select applications of which the deployments will be removed" -PassThru 
)
 
#Removed deployment to selected applications
foreach ($application in $AppstoRemoveDeployments) {
    Get-CMApplicationDeployment -Name $application.LocalizedDisplayName | Remove-CMApplicationDeployment -Force -Verbose
}
