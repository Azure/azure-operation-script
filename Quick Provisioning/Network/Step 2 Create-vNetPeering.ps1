# Global Parameter
$CsvFilePath = "./vnet-peer.csv"

# Script Variable
$CurrentSubscription = ""
$vnets = Import-Csv $CsvFilePath
$vnets = $vnets | Sort-Object VNet1Subscription, VNet1ResourceGroup, VNet1Name

# Disable breaking change warning messages
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value "true"

#Region Peering
foreach ($vnet in $vnets) {
    # Get Virtual Network Instance
    Write-Host ("`nAdding Peering between " + $vnet.VNet1Name.Trim() + " and " + $vnet.VNet2Name.Trim()) -ForegroundColor Cyan

    # Set current subscription for VNet1
    if ($CurrentSubscription -ne $vnet.VNet1Subscription.Trim()) {
        Set-AzContext -SubscriptionName $vnet.VNet1Subscription.Trim() | Out-Null
        $CurrentSubscription = $vnet.VNet1Subscription.Trim()
    }
    $VNet1 = Get-AzVirtualNetwork -ResourceGroup $vnet.VNet1ResourceGroup.Trim() -Name $vnet.VNet1Name.Trim()
    Start-Sleep -Milliseconds 100
    
    # Set current subscription for VNet2
    if ($CurrentSubscription -ne $vnet.VNet2Subscription.Trim()) {
        Set-AzContext -SubscriptionName $vnet.VNet2Subscription.Trim() | Out-Null
        $CurrentSubscription = $vnet.VNet2Subscription.Trim()
    }
    $VNet2 = Get-AzVirtualNetwork -ResourceGroup $vnet.VNet2ResourceGroup.Trim() -Name $vnet.VNet2Name.Trim()
    Start-Sleep -Milliseconds 100

    if (![string]::IsNullOrEmpty($vnet.AllowGatewayTransit) -and $vnet.AllowGatewayTransit -ne "N" -and $vnet.AllowGatewayTransit -ne "N/A") {
        # Add Peering for allow Gateway Transit and using Remote Gateway
        if ($vnet.AllowGatewayTransit -eq $vnet.VNet1Name) {
            Add-AzVirtualNetworkPeering -Name ("Peer-" + $vnet.VNet2Name) -VirtualNetwork $VNet1 -RemoteVirtualNetworkId $VNet2.Id -AllowGatewayTransit -AllowForwardedTraffic | Out-Null
            Add-AzVirtualNetworkPeering -Name ("Peer-" + $vnet.VNet1Name) -VirtualNetwork $VNet2 -RemoteVirtualNetworkId $VNet1.Id -UseRemoteGateways -AllowForwardedTraffic | Out-Null
        } else {
            Add-AzVirtualNetworkPeering -Name ("Peer-" + $vnet.VNet1Name) -VirtualNetwork $VNet2 -RemoteVirtualNetworkId $VNet1.Id -AllowGatewayTransit -AllowForwardedTraffic | Out-Null
            Add-AzVirtualNetworkPeering -Name ("Peer-" + $vnet.VNet2Name) -VirtualNetwork $VNet1 -RemoteVirtualNetworkId $VNet2.Id -UseRemoteGateways -AllowForwardedTraffic | Out-Null
        }
    } else {
        # Add Peering only
        Add-AzVirtualNetworkPeering -Name ("Peer-" + $vnet.VNet2Name) -VirtualNetwork $VNet1 -RemoteVirtualNetworkId $VNet2.Id -AllowForwardedTraffic | Out-Null
        Add-AzVirtualNetworkPeering -Name ("Peer-" + $vnet.VNet1Name) -VirtualNetwork $VNet2 -RemoteVirtualNetworkId $VNet1.Id -AllowForwardedTraffic | Out-Null
    }

    # Verify
    Start-Sleep -Seconds 1
    if ($CurrentSubscription -ne $vnet.VNet1Subscription.Trim()) {
        Set-AzContext -SubscriptionName $vnet.VNet1Subscription.Trim() | Out-Null
        $CurrentSubscription = $vnet.VNet1Subscription.Trim()
    }
    $Result = Get-AzVirtualNetworkPeering -ResourceGroupName $vnet.VNet1ResourceGroup.Trim() -VirtualNetworkName $vnet.VNet1Name.Trim() -Name ("Peer-" + $vnet.VNet2Name)
    if ($Result.PeeringState -eq "Connected") {
        Write-Host ("Peering is created successfully")
    } else {
        Write-Host ("Peering state is failed") -ForegroundColor Yellow
    }
}
#EndRegion Peering