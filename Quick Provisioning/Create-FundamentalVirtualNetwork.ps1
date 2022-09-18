# Global Parameter
$Location = "East Asia"
$HubRG = "rg-hub-quicksample-eas-hub01"
$HubVNetName = "vnet-hub-quicksample-eas-001"
$SpokeRG = "rg-spoke-quicksample-eas-app01"
$SpokeVNetName = "vnet-spoke-quicksample-eas-001"
$EnablePeering = $false

# Main
$StartTime = Get-Date

#Region Resource Group
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`nProvision Resource Group ..." -ForegroundColor Cyan

# Create Resource Group if not exist
$IsExist = Get-AzResourceGroup -Name $HubRG -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($IsExist)) {
    New-AzResourceGroup -Name $HubRG -Location $Location | Out-Null
    Write-Host ("Resource Group " + $HubRG + " is created") 
} else {
    Write-Host ("Resource Group " + $HubRG + " already exist") -ForegroundColor Yellow
}

$IsExist = Get-AzResourceGroup -Name $SpokeRG -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($IsExist)) {
    New-AzResourceGroup -Name $SpokeRG -Location $Location | Out-Null
    Write-Host ("Resource Group " + $SpokeRG + " is created") 
} else {
    Write-Host ("Resource Group " + $SpokeRG + " already exist") -ForegroundColor Yellow
}
Start-Sleep -Seconds 2
#EndRegion Resource Group

#Region Virtual Network
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black

# Hub Virtual Network
$GatewaySubnet = New-AzVirtualNetworkSubnetConfig -Name GatewaySubnet -AddressPrefix "10.80.200.0/24"
Start-Sleep -Milliseconds 100
Write-Host "`nProvision Hub Virtual Network ..." -ForegroundColor Cyan
$HubVirtualNetwork = New-AzVirtualNetwork -ResourceGroupName $HubRG -Name $HubVNetName -Location $Location -AddressPrefix "10.81.0.0/22","10.80.200.0/24" -Subnet $GatewaySubnet
Write-Host "`Prepare Subnet: GatewaySubnet ..." -ForegroundColor Cyan
Write-Host "`Prepare Subnet: AzureFirewallSubnet ..." -ForegroundColor Cyan
Add-AzVirtualNetworkSubnetConfig -VirtualNetwork $HubVirtualNetwork -Name AzureFirewallSubnet -AddressPrefix "10.81.0.0/26" | Out-Null
Write-Host "`Prepare Subnet: AzureFirewallManagementSubnet ..." -ForegroundColor Cyan
Add-AzVirtualNetworkSubnetConfig -VirtualNetwork $HubVirtualNetwork -Name AzureFirewallManagementSubnet -AddressPrefix "10.81.0.64/26" | Out-Null
Write-Host "`Prepare Subnet: AzureBastionSubnet ..." -ForegroundColor Cyan
Add-AzVirtualNetworkSubnetConfig -VirtualNetwork $HubVirtualNetwork -Name AzureBastionSubnet -AddressPrefix "10.81.1.0/24" | Out-Null
Write-Host "`Prepare Subnet: VM ..." -ForegroundColor Cyan
Add-AzVirtualNetworkSubnetConfig -VirtualNetwork $HubVirtualNetwork -Name VM -AddressPrefix "10.81.2.0/24" | Out-Null
Start-Sleep -Milliseconds 100
Write-Host "Add Subnets to Hub Virtual Network ..." -ForegroundColor Cyan
$HubVirtualNetwork | Set-AzVirtualNetwork | Out-Null

# Spoke Virtual Network
Write-Host "`nPrepare Subnet: AppGatewaySubnet ..." -ForegroundColor Cyan
$SpokeSubnet1 = New-AzVirtualNetworkSubnetConfig -Name AppGatewaySubnet -AddressPrefix "10.81.20.64/26"
Start-Sleep -Milliseconds 200
Write-Host "`nProvision Spoke Virtual Network ..." -ForegroundColor Cyan
$SpokeVirtualNetwork = New-AzVirtualNetwork -ResourceGroupName $SpokeRG -Name $SpokeVNetName -Location $Location -AddressPrefix "10.81.20.0/22" -Subnet $SpokeSubnet1
#EndRegion Virtual Network

#Region Virtual Network Peering
if ($EnablePeering) {
    Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black

    # Get Virtual Network Instance
    $HubVNet = Get-AzVirtualNetwork -ResourceGroup $HubRG -Name $HubVNetName
    $SpokeVNet = Get-AzVirtualNetwork -ResourceGroup $SpokeRG -Name $SpokeVNetName

    # Setup Virtual Network Peering
    Write-Host ("`nAdd Peering between " + $HubVNet.Name + " and " + $SpokeVNet.Name) -ForegroundColor Cyan
    Add-AzVirtualNetworkPeering -Name ("Peered-to-" + $SpokeVNet.Name) -VirtualNetwork $HubVNet -RemoteVirtualNetworkId $SpokeVNet.Id -AllowForwardedTraffic | Out-Null
    Start-Sleep -Milliseconds 200
    Add-AzVirtualNetworkPeering -Name ("Peered-to-" + $HubVNet.Name) -VirtualNetwork $SpokeVNet -RemoteVirtualNetworkId $HubVNet.Id -AllowForwardedTraffic | Out-Null
    Start-Sleep -Seconds 15

    # Verification
    $Result = Get-AzVirtualNetworkPeering -ResourceGroupName $HubRG -VirtualNetworkName $HubVNet.Name -Name ("Peered-to-" + $SpokeVNet.Name) 
    if ($Result.PeeringState -ne "Connected") {
        Write-Host "Peering state is failed" -ForegroundColor Yellow
    } 
    Start-Sleep -Seconds 1
}
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
Remove-AzVirtualNetwork -ResourceGroupName $HubRG -Name $HubVNetName -Force -Confirm:$false
Remove-AzVirtualNetwork -ResourceGroupName $SpokeRG -Name $SpokeVNetName -Force -Confirm:$false
#EndRegion Decommission