# Script Variable
$Global:ReplicationProtectedItems = @()

# Get Azure Subscription
$Subscriptions = Get-AzSubscription

# Main
Write-Host "`nCollecting Site Recovery Replication Protected Items`n" -ForegroundColor Yellow

foreach ($Subscription in $Subscriptions) {
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id
    $RecoveryServicesVaults = Get-AzRecoveryServicesVault

    foreach ($RecoveryServicesVault in $RecoveryServicesVaults) {
        # Set Vault Context
        Write-Host ("Processing Recovery Services Vault: " + $RecoveryServicesVault.Name + "`n") -ForegroundColor Yellow
        Set-AzRecoveryServicesAsrVaultContext -Vault $RecoveryServicesVault # Perform action 'Microsoft.RecoveryServices/vaults/extendedInformation/write' 

        # Retrieve Data
        $fabrics = Get-AzRecoveryServicesAsrFabric
        foreach ($fabric in $fabrics) {
            $ProtectionContainers = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $fabric

            foreach ($ProtectionContainer in $ProtectionContainers) {
                $Global:ReplicationProtectedItems += Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $ProtectionContainer
            }
        }
    }
}

# End
Write-Host "`nCompleted" -ForegroundColor Yellow;
Write-Host "`nCheck variable " -NoNewline;
Write-Host '$Global:ReplicationProtectedItems' -NoNewline -ForegroundColor Cyan;
Write-Host " to review`n"
Start-Sleep -Seconds 1
Write-Host "`n"