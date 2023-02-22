# Global Parameter
$SubscriptionId = "" # Subscription Id of OS Disk and will provision Azure Image under same Subscription
$osDiskRG = "" # Resource Group Name of OS Disk
$osDiskName = "" # OS Disk Name of VM
$NewImageRG = ""
$NewImageName = ""
$Location = "" # Azure Resource Location of both OS Disk and Azure Image

# Login
Connect-AzAccount
Set-AzContext -SubscriptionId $SubscriptionId

# Main
$ManagedDiskID = "/subscriptions/$SubscriptionId/resourceGroups/$osDiskRG/providers/Microsoft.Compute/disks/$osDiskName"
$ImageConfig = New-AzImageConfig -Location $Location # -HyperVGeneration V2
$ImageConfig = Set-AzImageOsDisk -Image $ImageConfig -OsState Generalized -OsType Windows -ManagedDiskId $ManagedDiskID
New-AzImage -ResourceGroupName $NewImageRG -ImageName $NewImageName -Image $ImageConfig

# Logout
Disconnect-AzAccount