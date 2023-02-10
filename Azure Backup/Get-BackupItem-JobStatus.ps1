# Global Parameter
$TenantId = ""
$CsvOutputPath = "C:\Temp"
$StartDate = (Get-Date).AddDays(-1) # Retrieve Past 24 Hours

# Script Variable
$Global:BackupSummary = @()
$Global:BackupJobDetail = @()
$BackupItemVM = @()  
$RecoveryServicesVaults = @()
[int]$CurrentItem = 1
$ErrorActionPreference = "Continue"
if ($CsvOutputPath -notlike "*\") {$CsvOutputPath += "\"}

# Get Azure Subscription
$Global:Subscriptions = Get-AzSubscription -TenantId $TenantId | ? {$_.State -eq "Enabled" -and $_.Name -ne "Access to Azure Active Directory"}

# Main
foreach ($Subscription in $Global:Subscriptions) {
    Write-Host ("`n")
    Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black

    # Set current subscription
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id -TenantId $TenantId
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Global:Subscriptions.Count + " Subscription: " + $AzContext.Subscription.Name) -ForegroundColor Yellow
    $CurrentItem++

    # Get Recovery Services Vault(s) from current subscription
    $CurrentSubscriptionVaults = Get-AzRecoveryServicesVault

    if ($CurrentSubscriptionVaults -ne $null) {
        Write-Host "Retrieving Azure VM Information"
        $RecoveryServicesVaults += $CurrentSubscriptionVaults

        # Get Azure VM of current subscription
        $vms = Get-AzVM | ? {$_.ResourceGroupName -notlike "databricks-rg*"}
        Start-Sleep -Seconds 1
    }

    # Process each Recovery Services Vault(s)
    foreach ($CurrentSubscriptionVault in $CurrentSubscriptionVaults) {
        Write-Host ("`nRecovery Services Vault: " + $CurrentSubscriptionVault.Name) -ForegroundColor Cyan
        
        # Get Backup Item of Recovery Services Vault from current subscription
        $Containers = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -Status Registered -VaultId $CurrentSubscriptionVault.ID
        Write-Host ("Number of protected Azure VM(s) : " + $Containers.Count)
        
        foreach ($Container in $Containers) {
            $CurrentBackupItemVM = Get-AzRecoveryServicesBackupItem -Container $Container -WorkloadType AzureVM -VaultId $CurrentSubscriptionVault.ID

            # Name Handling
            $vmName = $CurrentBackupItemVM.VirtualMachineId.Substring($CurrentBackupItemVM.VirtualMachineId.IndexOf("Microsoft.Compute/virtualMachines/") + "Microsoft.Compute/virtualMachines/".Length)
            $ResourceGroupStartIndex = $CurrentBackupItemVM.VirtualMachineId.IndexOf("resourceGroups/") + "resourceGroups/".Length
            $ResourceGroupEndIndex = $CurrentBackupItemVM.VirtualMachineId.IndexOf("providers/Microsoft.Compute/")
            $vmRG = $CurrentBackupItemVM.VirtualMachineId.Substring($ResourceGroupStartIndex, $ResourceGroupEndIndex - $ResourceGroupStartIndex - 1)

            # Get VM Detail
            $vm = $vms | ? {$_.Id -eq $CurrentBackupItemVM.VirtualMachineId -or $_.Id -eq $CurrentBackupItemVM.SourceResourceId}
            if ($vm -eq $null) {
                $IsExist = "Source VM was deleted"
            } else {
                $IsExist = "Exist"
            }

            # Append VM Protected Information to Array
            $obj = New-Object -TypeName PSobject
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $AzContext.Subscription.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $AzContext.Subscription.Id
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SourceVmStatus" -Value $IsExist
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $vmRG
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceName" -Value $vmName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value "Azure VM"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $vm.Location
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ProtectionState" -Value $CurrentBackupItemVM.ProtectionState
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ProtectionStatus" -Value $CurrentBackupItemVM.ProtectionStatus
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ProtectionPolicyName" -Value $CurrentBackupItemVM.ProtectionPolicyName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "LastBackupStatus" -Value $CurrentBackupItemVM.LastBackupStatus
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "LastBackupTime (UTC)" -Value $CurrentBackupItemVM.LastBackupTime
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VaultName" -Value $CurrentSubscriptionVault.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VaultId" -Value $CurrentSubscriptionVault.Id
            $Global:BackupSummary += $obj

            $BackupItemVM += $CurrentBackupItemVM
        }

        # Get Backup Job of Recovery Services Vault from current subscription
        $CurrentBackupJobs = Get-AzRecoveryServicesBackupJob -BackupManagementType AzureVM -From $StartDate.ToUniversalTime() -VaultId $CurrentSubscriptionVault.ID

        foreach ($CurrentBackupJob in $CurrentBackupJobs) {
            $vmInfo = $Global:BackupSummary | ? {$_.ResourceName -eq $CurrentBackupJob.WorkloadName -and $_.ProtectionState -eq "Protected" -and $_.SourceVmStatus -eq "Exist"}
            [string]$Duration = $CurrentBackupJob.Duration.Hours.ToString() + ":" + $CurrentBackupJob.Duration.Minutes.ToString()

            $obj = New-Object -TypeName PSobject
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $vmInfo.ResourceGroup
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceName" -Value $CurrentBackupJob.WorkloadName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ProtectionPolicyName" -Value $vmInfo.ProtectionPolicyName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Operation" -Value $CurrentBackupJob.Operation
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Status" -Value $CurrentBackupJob.Status
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "StartTime (UTC)" -Value $CurrentBackupJob.StartTime
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "EndTime (UTC)" -Value $CurrentBackupJob.EndTime
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Duration (h:m)" -Value $Duration
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VaultName" -Value $CurrentSubscriptionVault.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VaultId" -Value $CurrentSubscriptionVault.Id
            $Global:BackupJobDetail += $obj
        }
        Start-Sleep -Seconds 1
    }
}

# Export
$Global:BackupSummary | sort ProtectionState, LastBackupStatus, "LastBackupTime (UTC)" -Descending | Export-Csv -Path ($CsvOutputPath + "BackupSummary.csv") -NoTypeInformation -Force -Confirm:$false
$Global:BackupJobDetail | sort "StartTime (UTC)" -Descending | Export-Csv -Path ($CsvOutputPath + "BackupJobDetail.csv") -NoTypeInformation -Force -Confirm:$false

# End
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`nCompleted"
Write-Host ("`nBackup detail of " + $BackupItemVM.Count + " protected Azure VM(s) from " + $RecoveryServicesVaults.Count + " Recovery Services Vaults are exported to " + $CsvOutputPath)
Start-Sleep -Seconds 1
Write-Host "`n"