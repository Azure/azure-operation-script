# Global Parameter
$CsvFilePath = "./vnet-rt-association.csv"

# Script Variable
$CurrentSubscription = ""
$associations = Import-Csv $CsvFilePath
$associations = $associations | Sort-Object RTSubscription,RTResourceGroup,RTName

# Disable breaking change warning messages
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value "true"

#Region Associate
foreach ($association in $associations) {
    Write-Host ("`nAssociate subnet '" + $association.VNetSubnetName.Trim() + "' with route table '" + $association.RTName.Trim() + "'" ) -ForegroundColor Cyan

    # Set current subscription for Route Table
    if ($CurrentSubscription -ne $association.RTSubscription.Trim()) {
        Set-AzContext -SubscriptionName $association.RTSubscription.Trim() | Out-Null
        $CurrentSubscription = $association.RTSubscription.Trim()
    }
    $RouteTable = Get-AzRouteTable -ResourceGroupName $association.RTResourceGroup -Name $association.RTName

    # Set current subscription for Virtual Network
    if ($CurrentSubscription -ne $association.VNetSubscription.Trim()) {
        Set-AzContext -SubscriptionName $association.VNetSubscription.Trim() | Out-Null
        $CurrentSubscription = $association.VNetSubscription.Trim()
    }
    $VirtualNetwork = Get-AzVirtualNetwork -ResourceGroup $association.VNetResourceGroup.Trim() -Name $association.VNetName.Trim()
    $Subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VirtualNetwork -Name $association.VNetSubnetName.Trim()
    Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $VirtualNetwork -Name $association.VNetSubnetName.Trim() -AddressPrefix $Subnet.AddressPrefix -RouteTable $RouteTable | Set-AzVirtualNetwork | Out-Null
    Start-Sleep -Seconds 1
}
#EndRegion Associate