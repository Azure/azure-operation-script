# Global Parameter
$SubscriptionId = ""
$NsgName = ""
$NsgRG = ""
$Location = "East Asia"
$IsNsgProvisioned = $true
VNetType = "Internal"

# Login
Connect-AzAccount

# Main
Set-AzContext -SubscriptionId $SubscriptionId

if ($IsNsgProvisioned) {
    # Get the NSG instance
    $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $NsgRG -Name $NsgName 
} else {
    $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $NsgRG -Name $NsgName -Location $Location
    Start-Sleep -Seconds 5
}

# Add custom rule
if (VNetType -eq "External") {
    $nsg | Add-AzNetworkSecurityRuleConfig -Direction Inbound -Priority 120 -Access Allow -Name "AllowClientInbound" -Protocol TCP -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix VirtualNetwork -DestinationPortRange 80,443
}
$nsg | Add-AzNetworkSecurityRuleConfig -Direction Inbound -Priority 121 -Access Allow -Name "AllowManagementEndpointInbound" -Protocol TCP -SourceAddressPrefix ApiManagement -SourcePortRange * -DestinationAddressPrefix VirtualNetwork -DestinationPortRange 3443
$nsg | Add-AzNetworkSecurityRuleConfig -Direction Inbound -Priority 122 -Access Allow -Name "AllowAzureLoadBalancerInbound" -Protocol TCP -SourceAddressPrefix AzureLoadBalancer -SourcePortRange * -DestinationAddressPrefix VirtualNetwork -DestinationPortRange 6390
$nsg | Add-AzNetworkSecurityRuleConfig -Direction Outbound -Priority 120 -Access Allow -Name "AllowAzureStorageOutbound" -Protocol TCP -SourceAddressPrefix VirtualNetwork -SourcePortRange * -DestinationAddressPrefix Storage -DestinationPortRange 443
$nsg | Add-AzNetworkSecurityRuleConfig -Direction Outbound -Priority 121 -Access Allow -Name "AllowSqlEndpointOutbound" -Protocol TCP -SourceAddressPrefix VirtualNetwork -SourcePortRange * -DestinationAddressPrefix SQL -DestinationPortRange 1433
$nsg | Add-AzNetworkSecurityRuleConfig -Direction Outbound -Priority 122 -Access Allow -Name "AllowKeyVaultOutbound" -Protocol TCP -SourceAddressPrefix VirtualNetwork -SourcePortRange * -DestinationAddressPrefix AzureKeyVault -DestinationPortRange 443

# Update the NSG
$nsg | Set-AzNetworkSecurityGroup

# End
Write-Host "`nCompleted`n" -ForegroundColor Yellow