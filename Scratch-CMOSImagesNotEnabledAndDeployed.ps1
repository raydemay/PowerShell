#region SCCM PSDrive
# Press 'F5' to run this script. Running this script will load the ConfigurationManager
# module for Windows PowerShell and will connect to the site.
#
# This script was auto-generated at '1/24/2019 3:43:18 PM'.

# Uncomment the line below if running in an environment where script signing is 
# required.
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Site configuration
$SiteCode = "Sitecode" # Site code 
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
#endregion

#region Find unused Operating System Image packages
# Find any operating system images that are not in a task sequence 
# **OR** are in a task sequence but the step is not enabled 
# **OR** are in a task sequence that isn't deployed

#Get all OS images in enabled and deployed task sequences
# First, get all task sequence deployments
$AllCMOSImagesEnabledAndDeployed = @(
            # First, get all task sequence deployments
            Get-CMTaskSequenceDeployment | 
            Sort-Object -Property PackageID -Unique | 
            #Get the PackageID of operating system images in the Apply Operating System Step, and only if the step is enabled
            ForEach-Object { Get-CMTaskSequenceStepApplyOperatingSystem -TaskSequenceId $_.PackageID } | Where-Object { $_.Enabled } | 
            Sort-Object -Property ImagePackageID -Unique |
            #Get the operating system images based on the package IDs 
            ForEach-Object { Get-CMOperatingSystemImage -Id $_.ImagePackageID }
            )

#Get all OS images where the object is not the same as the images that were retrieved and stored in $AllCMOSImagesEnabledandDeployed
#These images are the ones that are either not in a deployed task sequence or the task sequence step isn't enabled
$AllCMOSImagesNotEnabledAndDeployed = Get-CMOperatingSystemImage | Where-Object { $AllCMOSImagesEnabledAndDeployed.PackageID -notcontains $_.PackageID }

#Export a CSV with the names, descriptions, and package IDs of OS images not in an enabled or deployed task sequence
$AllCMOSImagesNotEnabledAndDeployed | 
    Select-Object -Property Name, Description, PackageID | 
    Export-Csv -Path .\desktop\AllCMOSImagesNotEnabledAndDeployed_$((Get-Date).ToString('MM-dd-yyyy')).csv -NoTypeInformation
$DeletedOSImages = $AllCMOSImagesNotEnabledAndDeployed | 
    Select-Object -Property Name, Description, PackageID | 
    Out-GridView -Title "Select Operating System Images to remove from SCCM" -PassThru | 
    Export-Csv  -Path .\desktop\RemovedOSImages_$((Get-Date).ToString('MM-dd-yyyy')).csv -NoTypeInformation
#endregion

#region Find and remove orphaned WIMS
# This section is finding orphaned WIMs in sccm-dp1 source directories
Set-Location C:
$SourceDirs = Get-ChildItem -Path "\\UNC-path-for-source-files" -Directory -Exclude Drivers, Imported-Task-Sequences, OSD_Diskpart_Scripts, OSDBackground, temp, UDI, USMT, Win10Customization, 'Windows_10_Customization--2.0', winpe-mount, Client* 
$AllOperatingSystemWIMs = Get-ChildItem -Path $SourceDirs -Recurse -File -filter *.wim | Select-Object -ExpandProperty FullName | Sort-Object 

Set-Location COE:
$AllOperatingSystemImages = Get-CMOperatingSystemImage | Select-Object -ExpandProperty PkgSourcePath
Set-Location c:
$AllUniqueOperatingSystemImagePaths = Get-Item -Path $AllOperatingSystemImages | Sort-Object -Unique 

$OrphanedWIMs = Compare-Object -ReferenceObject (Get-Item -Path $AllOperatingSystemWIMs) -DifferenceObject (Get-Item -Path $AllUniqueOperatingSystemImagePaths) -Property Name -PassThru
$OrphanedWIMs | Select-Object FullName | Export-CSV C:\Users\demay.9a\Desktop\orphanedWIMs_$((Get-Date).ToString('MM-dd-yyyy')).csv -NoTypeInformation
$DeletedWIMS = $OrphanedWIMs | 
    Select-Object FullName | 
    Out-GridView -Title "Select operating system WIM files to delete" -PassThru | 
    Export-CSV C:\Users\demay.9a\Desktop\wimstodelete_$((Get-Date).ToString('MM-dd-yyyy')).csv -NoTypeInformation
#endregion

<# Scratch work

$AllCMTaskSequences = Get-CMTaskSequence
$AllUniquePackageReferencesInCMTaskSequences = @($AllCMTaskSequences.References.Package) | Sort-Object -Unique
Get-CMOperatingSystemImage | Where-Object { $AllUniquePackageReferencesInCMTaskSequences -notcontains $_.PackageID} | Format-Table Name, Description 

$AllDeployedCMTaskSequences = Get-CMTaskSequence | Where-Object { $_ | Get-CMTaskSequenceDeployment }
$AllUniquePackageReferencesInDeployedCMTaskSequences = @($AllDeployedCMTaskSequences.References.Package) | Sort-Object -Unique
$FirstListOfCMOSImagesNotDeployed = Get-CMOperatingSystemImage | Where-Object { $AllUniquePackageReferencesInDeployedCMTaskSequences -notcontains $_.PackageID}
#>