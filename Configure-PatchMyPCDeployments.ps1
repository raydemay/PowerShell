# Site configuration
$SiteCode = "COE" # Site code 
$ProviderMachineName = "siteserver" # SMS Provider machine name

# Customizations
$initParams = @{}
#$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
#$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors

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

# Get most recent Patch My PC Software Update Group
# The script is designed to be run after the ADR completes, and the ADR evaluation schedule is "Occurs every 1 weeks on Monday effective 12/16/2019 6:00 AM"
# $RunDate is the date of the most recent SUG, meaning the script must run the same day as the ADR
$RunDate = Get-Date -Format "yyyy-MM-dd"

#Formats the SUG Name to search for
$SUGName = "Patch My PC Weekly - " + $RunDate 

# Find software update group and rename it
$PatchMyPCLatestSUG = Get-CMSoftwareUpdateGroup -Name "$($SUGName)*" -ForceWildcardHandling
Set-CMSoftwareUpdateGroup -Id $PatchMyPCLatestSUG.CI_ID -NewName $SUGName -Description $SUGName

# 30 second pause to let the cm database update
# The rest of the script doesn't seem to work without either pausing or moving the rename to the end
Start-Sleep 30

# Get Software Update Deployments
# This uses the CI_ID of the SUG rather than the name because there is an issue with this step looking for the new name
$CMSoftwareUpdateDeployment = Get-CMSoftwareUpdateDeployment -SmsObjectId $PatchMyPCLatestSUG.CI_ID

foreach ($deployment in $CMSoftwareUpdateDeployment) {
    $CMSoftwareUpdateDeploymentCollection = Get-CMCollection -Id "$($deployment.TargetCollectionID)"
                        
    # Hashtable of desired settings to fix deployment names and scheduling
    $CMSoftwareUpdateDeploymentArgs = @{
        'DeploymentName'           = $deployment.AssignmentName
        'NewDeploymentName'        = "$SUGName => $($CMSoftwareUpdateDeploymentCollection.Name)"; 
        'Description'              = "Software Update Group $SUGName Deployed To => Device Collection '$($CMSoftwareUpdateDeploymentCollection.Name)'"; 
        'TimeBasedOn'              = 'LocalTime'; 
        'AvailableDateTime'        = $deployment.StartTime.addMinutes( - ($deployment.StartTime.minute % 60)) # Rounds time down to nearest hour
        'DeploymentExpireDateTime' = $deployment.EnforcementDeadline.addMinutes( - ($deployment.EnforcementDeadline.minute % 60)); # Rounds time down to nearest hour
    }
            
    # Update existing Software Update Group deployment to Device Collection using imported / desired settings
    $deployment | Set-CMSoftwareUpdateDeployment @CMSoftwareUpdateDeploymentArgs -Verbose

}

Get-CMSoftwareUpdateGroup -Name "Patch My PC Weekly - *" -ForceWildcardHandling | Select-Object -First 1 | Remove-CMSoftwareUpdateGroup -Force

