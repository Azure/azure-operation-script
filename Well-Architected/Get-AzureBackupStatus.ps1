# Script Variable
$Global:BackupStatus = @()
$Global:BackupStatusSummary = @()
$BackupItemVM = @()
$BackupItemSqlVM = @()
$BackupItemBlob = @()
[int]$CurrentItem = 1
$ErrorActionPreference = "Continue"

# Function to align the Display Name
function Rename-Location {
    param (
        [string]$Location
    )

    foreach ($item in $Global:NameReference) {
        if ($item.Location -eq $Location) {
            $Location = $item.DisplayName
        }
    }

    return $Location
}

# Disable breaking change warning messages
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value "true"

# Module
Import-Module ImportExcel

# Main
Write-Host ("`n" + "=" * 100)
Write-Host "`nGet Azure Backup Status" -ForegroundColor Cyan

#Region Data Collection
foreach ($Subscription in $Global:Subscriptions) {
    Write-Host ("`n")
    Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black

    # Set current subscription
	$AzContext = Set-AzContext -SubscriptionId $Subscription.Id
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Global:Subscriptions.Count + " Subscription: " + $Subscription.name) -ForegroundColor Yellow
    $CurrentItem++

    # Get Recovery Services Vault in subscription
    $RecoveryServicesVaults = Get-AzRecoveryServicesVault

    foreach ($RecoveryServicesVault in $RecoveryServicesVaults) {
        Write-Host ("Recovery Services Vault: " + $RecoveryServicesVault.Name)

        # Azure VM
        $Containers = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -Status Registered -VaultId $RecoveryServicesVault.ID
        foreach ($Container in $Containers) {
            $BackupItemVM += Get-AzRecoveryServicesBackupItem -Container $Container -WorkloadType AzureVM -VaultId $RecoveryServicesVault.ID
        }

        # SQL Server in Azure VM
        $Containers = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVMAppContainer -Status Registered -VaultId $RecoveryServicesVault.ID
        foreach ($Container in $Containers) {
            $BackupItemSqlVM += Get-AzRecoveryServicesBackupItem -Container $Container -WorkloadType MSSQL -VaultId $RecoveryServicesVault.ID
        }
    }

    # Get Backup Vault in subscription
    $BackupVaults = Get-AzResource | ? {$_.ResourceType -eq "Microsoft.DataProtection/BackupVaults"} 
    foreach ($BackupVault in $BackupVaults) {
        Write-Host ("Backup Vault: " + $BackupVault.Name)
        $BackupItemBlob += Get-AzDataProtectionBackupInstance -ResourceGroupName $BackupVault.ResourceGroupName -VaultName $BackupVault.Name
    }
}
#EndRegion Data Collection

#Region Virtual Machine
foreach ($Subscription in $Global:Subscriptions) {
    # Set current subscription for Az Module
	$AzContext = Set-AzContext -SubscriptionId $Subscription.Id

    # Get all Azure VM
    $vms = Get-AzVM | ? {$_.ResourceGroupName -notlike "databricks-rg*"}

    # Get Azure Backup Status
    foreach ($vm in $vms) {
        $Location = Rename-Location -Location $vm.Location

        if ($BackupItemVM.VirtualMachineId -contains $vm.Id -or $BackupItemVM.SourceResourceId -contains $vm.Id) {
            # Get Vault ID and Vault Name
            $VaultId = $BackupItemVM | ? {$_.VirtualMachineId -eq $vm.Id -or $_.SourceResourceId -eq $vm.Id} | select -ExpandProperty Id
            $VaultName = $VaultId.Substring($VaultId.IndexOf("/Microsoft.RecoveryServices/vaults/") + "/Microsoft.RecoveryServices/vaults/".Length)
            $VaultName = $VaultName.Substring(0, $VaultName.IndexOf("/"))
            $VaultId = $VaultId.Substring(0, $VaultId.IndexOf($VaultName) + $VaultName.Length)

            # Get Backup Healthiness
            $ProtectionStatus = $BackupItemVM | ? {$_.VirtualMachineId -eq $vm.Id -or $_.SourceResourceId -eq $vm.Id} | select -ExpandProperty ProtectionStatus

            $obj = New-Object -TypeName PSobject
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.Id
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $vm.ResourceGroupName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceName" -Value $vm.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value "Azure VM"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Location
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledBackup" -Value "Y"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ProtectionStatus" -Value $ProtectionStatus
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Database" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VaultName" -Value $VaultName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VaultId" -Value $VaultId
            $Global:BackupStatus += $obj
        } else {
            $obj = New-Object -TypeName PSobject
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.Id
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $vm.ResourceGroupName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceName" -Value $vm.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value "Azure VM"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Location
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledBackup" -Value "N"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ProtectionStatus" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Database" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VaultName" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VaultId" -Value "N/A"
            $Global:BackupStatus += $obj
        }
    }
}
#EndRegion Virtual Machine

#Region SQL Server in Azure VM
foreach ($Subscription in $Global:Subscriptions) {
    # Set current subscription for Az Module
	$AzContext = Set-AzContext -SubscriptionId $Subscription.Id

    # Get SQL Server in Azure VM
    $vms = Get-AzResource | ? {$_.ResourceGroupName -notlike "databricks-rg*" -and $_.resourcetype -eq "Microsoft.SqlVirtualMachine/SqlVirtualMachines"} 

    # Get Azure Backup Status
    foreach ($vm in $vms) {
        $Location = Rename-Location -Location $vm.Location
        $ResourceId = $vm.ResourceId -replace "Microsoft.SqlVirtualMachine/SqlVirtualMachines", "Microsoft.Compute/virtualMachines"

        if ($BackupItemSqlVM.SourceResourceId -eq $ResourceId) {
            # Get Vault ID and Vault Name
            $VaultId = $BackupItemSqlVM | ? {$_.SourceResourceId -eq $ResourceId} | select -first 1 | select -ExpandProperty Id
            $VaultName = $VaultId.Substring($VaultId.IndexOf("/Microsoft.RecoveryServices/vaults/") + "/Microsoft.RecoveryServices/vaults/".Length)
            $VaultName = $VaultName.Substring(0, $VaultName.IndexOf("/"))
            $VaultId = $VaultId.Substring(0, $VaultId.IndexOf($VaultName) + $VaultName.Length)

            # Get Backup Healthiness
            $ProtectionStatus = $BackupItemSqlVM | ? {$_.SourceResourceId -eq $ResourceId} | select -ExpandProperty ProtectionStatus
            if ($ProtectionStatus.Count -gt 1) {
                $ProtectionStatus = ($ProtectionStatus -join ", ")
            } 

            # Backup Database
            $Database = $BackupItemSqlVM | ? {$_.SourceResourceId -eq $ResourceId} | select -ExpandProperty FriendlyName
            if ($Database.Count -gt 1) {
                $DatabaseFriendlyName = ($Database -join ", ")
            } else {
                $DatabaseFriendlyName = $Database
            }

            $obj = New-Object -TypeName PSobject
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.Id
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $vm.ResourceGroupName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceName" -Value $vm.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value "SQL Server in Azure VM"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Location
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledBackup" -Value "Y"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ProtectionStatus" -Value $ProtectionStatus
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Database" -Value $DatabaseFriendlyName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VaultName" -Value $VaultName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VaultId" -Value $VaultId
            $Global:BackupStatus += $obj
        } else {
            $obj = New-Object -TypeName PSobject
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.Id
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $vm.ResourceGroupName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceName" -Value $vm.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value "SQL Server in Azure VM"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Location
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledBackup" -Value "N"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ProtectionStatus" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Database" -Value $Database
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VaultName" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VaultId" -Value "N/A"
            $Global:BackupStatus += $obj
        }
    }
}
#EndRegion SQL Server in Azure VM

#Region Blob Storage
foreach ($Subscription in $Global:Subscriptions) {
    # Set current subscription for Az Module
	$AzContext = Set-AzContext -SubscriptionId $Subscription.Id

    # Get all Blob Storage
    $StorageAccounts = Get-AzStorageAccount

    # Get Azure Backup Status
    foreach ($StorageAccount in $StorageAccounts) {
        $Location = Rename-Location -Location $StorageAccount.Location

        if ($BackupItemBlob.Property.DataSourceInfo.ResourceId -contains $StorageAccount.Id) {
            # Get Vault ID and Vault Name
            $VaultId = $BackupItemBlob | ? {$_.Property.DataSourceInfo.ResourceId -eq $StorageAccount.Id} | select -ExpandProperty Id
            $VaultId = $VaultId.Substring(0, $VaultId.IndexOf("/backupInstances/"))
            $VaultName = $VaultId.Substring($VaultId.IndexOf("/backupVaults/") + "/backupVaults/".Length)

            # Get Backup Healthiness
            $ProtectionStatus = $BackupItemBlob | ? {$_.Property.DataSourceInfo.ResourceId -eq $StorageAccount.Id} | select -ExpandProperty property | select -ExpandProperty CurrentProtectionState

            $obj = New-Object -TypeName PSobject
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.Id
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $StorageAccount.ResourceGroupName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceName" -Value $StorageAccount.StorageAccountName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value "Blob Storage"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Location
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledBackup" -Value "Y"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ProtectionStatus" -Value $ProtectionStatus
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Database" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VaultName" -Value $VaultName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VaultId" -Value $VaultId
            $Global:BackupStatus += $obj
        } else {
            $obj = New-Object -TypeName PSobject
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.Id
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $StorageAccount.ResourceGroupName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceName" -Value $StorageAccount.StorageAccountName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value "Blob Storage"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Location
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledBackup" -Value "N"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ProtectionStatus" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Database" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VaultName" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VaultId" -Value "N/A"
            $Global:BackupStatus += $obj
        }
    }
}
#EndRegion Blob Storage

#Region Export
if ($Global:BackupStatus.Count -ne 0) {
    # Prepare Azure Backup Status Summary
    $CountType = $Global:BackupStatus | group ResourceType, EnabledBackup | select Name, Count | sort Name
    foreach ($item in $CountType) {
        $ResourceType = $item.Name.Substring(0, $item.Name.IndexOf(","))
        $EnableStatus = $item.Name.Substring($item.Name.IndexOf(",") + 2)
        $ResourceTotal = $Global:BackupStatus | group ResourceType | ? {$_.Name -eq $ResourceType} | select -ExpandProperty Count

        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Resource Type" -Value $ResourceType 
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Enabled Backup" -Value $EnableStatus
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Subtotal" -Value $item.Count
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Total" -Value $ResourceTotal
        $Global:BackupStatusSummary += $obj
    }
    
    # Export to Excel File
    $Global:BackupStatusSummary  | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "BackupSummary" -TableName "BackupSummary" -TableStyle Medium16 -AutoSize -Append
    $Global:BackupStatus | sort ResourceType, SubscriptionName, ResourceGroup, ResourceName | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "BackupDetail" -TableName "BackupDetail" -TableStyle Medium16 -AutoSize -Append
} else {
    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value "Azure VM"
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Status" -Value "Resource is not found"
    $Global:BackupStatusSummary += $obj

    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value "SQL Server in Azure VM"
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Status" -Value "Resource is not found"
    $Global:BackupStatusSummary += $obj

    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value "Blob Storage"
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Status" -Value "Resource is not found"
    $Global:BackupStatusSummary += $obj

    # Export to Excel File
    $Global:BackupStatusSummary | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "ResourceNotFound" -TableName "ResourceNotFound" -TableStyle Light11 -AutoSize -Append
}
#EndRegion Export