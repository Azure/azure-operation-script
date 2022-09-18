# Global Parameter
$Location = "East Asia"
$HubRG = "rg-hub-quicksample-eas-hub01"
$HubVNetName = "vnet-hub-quicksample-eas-001"
$SpokeRG = "rg-spoke-quicksample-eas-app01"
$SpokeVNetName = "vnet-spoke-quicksample-eas-001"
$VngName = "vng-quickstart-prd-eas-001"
$GatewayType = "VPN" # ExpressRoute
$pipName = "pip-vng-quickstart-prd-eas-001"

# Main
$StartTime = Get-Date

# Get Virtual Network Instance
$HubVNet = Get-AzVirtualNetwork -ResourceGroup $HubRG -Name $HubVNetName
$SpokeVNet = Get-AzVirtualNetwork -ResourceGroup $SpokeRG -Name $SpokeVNetName

#Region Public IP Address
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`nProvision Public IP Address for Virtual Network Gateway ..." -ForegroundColor Cyan
$pip = New-AzPublicIpAddress -ResourceGroupName $HubRG -Name $pipName -AllocationMethod Static -Location $Location -Sku Standard -Zone (1,2,3)
Start-Sleep -Seconds 30
#EndRegion Public IP Address

#Region Virtual Network Gateway
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
$VngIpConfig = New-AzVirtualNetworkGatewayIpConfig -Name "VngIpConfig" -SubnetId ($HubVNet.Subnets | ? {$_.Name -eq "GatewaySubnet"}).Id -PublicIpAddressId $pip.Id
Start-Sleep -Milliseconds 200

# Require to provision in same resource group where Virtual Network with Gateway Subnet exist
# Public IP Address of VNG can be located in different resource group
if ($GatewayType -eq "ExpressRoute") {
    Write-Host "`nProvision ExpressRoute Virtual Network Gateway ..." -ForegroundColor Cyan
    $Vng = New-AzVirtualNetworkGateway -ResourceGroupName $HubRG -Name $VngName -Location $Location -IpConfigurations $VngIpConfig -GatewayType ExpressRoute -GatewaySku ErGw1AZ
    Start-Sleep -Seconds 30
} else {
    Write-Host "`nProvision VPN Virtual Network Gateway ..." -ForegroundColor Cyan
    $Vng = New-AzVirtualNetworkGateway -ResourceGroupName $HubRG -Name $VngName -Location $Location -IpConfigurations $VngIpConfig -GatewayType Vpn -GatewaySku VpnGw1AZ -VpnType "RouteBased"
    Start-Sleep -Seconds 30
}
#EndRegion Virtual Network Gateway

#Region Virtual Network Peering
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black

# Setup Virtual Network Peering
Write-Host ("`nAdd Peering between " + $HubVNet.Name + " and " + $SpokeVNet.Name) -ForegroundColor Cyan
Add-AzVirtualNetworkPeering -Name ("Peered-to-" + $SpokeVNet.Name) -VirtualNetwork $HubVNet -RemoteVirtualNetworkId $SpokeVNet.Id -AllowGatewayTransit -AllowForwardedTraffic | Out-Null
Start-Sleep -Milliseconds 200
Add-AzVirtualNetworkPeering -Name ("Peered-to-" + $HubVNet.Name) -VirtualNetwork $SpokeVNet -RemoteVirtualNetworkId $HubVNet.Id -UseRemoteGateways -AllowForwardedTraffic | Out-Null
Start-Sleep -Seconds 15

# Verification
$Result = Get-AzVirtualNetworkPeering -ResourceGroupName $HubRG -VirtualNetworkName $HubVNet.Name -Name ("Peered-to-" + $SpokeVNet.Name) 
if ($Result.PeeringState -ne "Connected") {
    Write-Host "Peering state is failed" -ForegroundColor Yellow
} 
Start-Sleep -Seconds 1
#EndRegion Virtual Network Peering

# End
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`n`nCompleted"
$EndTime = Get-Date
$Duration = $EndTime - $StartTime
Write-Host ("`nTotal Process Time: " + $Duration.Minutes + " Minutes " + $Duration.Seconds + " Seconds") -ForegroundColor White -BackgroundColor Black
Start-Sleep -Seconds 1
Write-Host "`n`n"

#Region Decommission
Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $HubRG | Remove-AzVirtualNetworkGatewayConnection -Force -Confirm:$false
Remove-AzVirtualNetworkGateway -ResourceGroupName $HubRG -Name $VngName -Force -Confirm:$false
Start-Sleep -Seconds 10
Remove-AzPublicIpAddress -ResourceGroupName $HubRG -Name $pipName -Force -Confirm:$false
Remove-AzResourceGroup -Name $HubRG -Force -Confirm:$false
Remove-AzResourceGroup -Name $SpokeRG -Force -Confirm:$false
#EndRegion Decommission