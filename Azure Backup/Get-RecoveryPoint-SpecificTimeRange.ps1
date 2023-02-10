# Script Variable
$BackupItemVM = @()  
$BackupItemVMRecoveryPoint = @() 
$StartDate = Get-Date -Year 2022 -Month 01 -Day 5 -Hour 23 -Minute 59
$EndDate = Get-Date -Year 2022 -Month 01 -Day 19 -Hour 23 -Minute 59

# Main
$RecoveryServicesVaults = Get-AzRecoveryServicesVault

# Get Backup Item of Recovery Services Vault from current subscription
foreach ($RecoveryServicesVault in $RecoveryServicesVaults) {
    Write-Host ("`nRecovery Services Vault: " + $RecoveryServicesVault.Name) -ForegroundColor Yellow
    Write-Host "Retrieving Azure VM Backup Item"

    # Type: Azure VM
    $Containers = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -Status Registered -VaultId $RecoveryServicesVault.ID
    foreach ($Container in $Containers) {
        $CurrentBackupItemVM = Get-AzRecoveryServicesBackupItem -Container $Container -WorkloadType AzureVM -VaultId $RecoveryServicesVault.ID
        $VMName = $CurrentBackupItemVM.VirtualMachineId.Substring($CurrentBackupItemVM.VirtualMachineId.IndexOf("/Microsoft.Compute/virtualMachines/") + "/Microsoft.Compute/virtualMachines/".Length)
        Write-Host $VMName

        $BackupItemVM += $CurrentBackupItemVM
        $BackupItemVMRecoveryPoint += Get-AzRecoveryServicesBackupRecoveryPoint -Item $CurrentBackupItemVM -StartDate $StartDate.ToUniversalTime() -EndDate $EndDate.ToUniversalTime() -VaultId $RecoveryServicesVault.ID
    }
}

# End
Write-Host "`nCompleted" -ForegroundColor Yellow
Write-Host ("`nCheck variable BackupItemVM to view the list of VM Backup")
Write-Host ("`nCheck variable BackupItemVMRecoveryPoint to view the list of VM Recovery Point")
Start-Sleep -Seconds 1
Write-Host "`n"