# Global Parameter
$SubscriptionId = ""
$apiManagementRG = "APIM"
$apiManagementName = "apim-core-eas-002"
$VNetRG = "Network"
$VNetName = "vnet-hub-prd-eas-001"
$SubnetName = "snet-apim-002"
$Location = "East Asia"
$Sku = "Developer" #Premium
$Capacity = 1 # Developer Tier allow 1 Unit only
$PublicIpRG = "APIM"
$PublicIpName = "pip-apim"

# Login
Connect-AzAccount

# Main
Set-AzContext -SubscriptionId $SubscriptionId

# Run the necessary section of scripts depending on the purpose
# Set to None
$apim = Get-AzApiManagement -ResourceGroupName $apiManagementRG -Name $apiManagementName
$apim.VpnType = "None"
Update-AzApiManagementRegion -ApiManagement $apim -Location $Location -Sku $Sku -Capacity $Capacity
Set-AzApiManagement -InputObject $apim

# Set to External
$PublicIpAddressId = Get-AzPublicIpAddress -ResourceGroupName $PublicIpRG -ResourceName $PublicIpName | select -ExpandProperty Id
$VNet = Get-AzVirtualNetwork -ResourceGroupName $VNetRG -Name $VNetName
$subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VNet -Name $SubnetName
$apimVirtualNetwork = New-AzApiManagementVirtualNetwork -SubnetResourceId $subnet.Id
$apim = Get-AzApiManagement -ResourceGroupName $apiManagementRG -Name $apiManagementName
$apim.VpnType = "External"
#$apim.VirtualNetwork = $apimVirtualNetwork # No need to specify if using Update-AzApiManagementRegion
Update-AzApiManagementRegion -ApiManagement $apim -Location $Location -Sku $Sku -Capacity $Capacity -VirtualNetwork $apimVirtualNetwork -PublicIpAddressId $PublicIpAddressId
Set-AzApiManagement -InputObject $apim

# Set to Internal
$PublicIpAddressId = Get-AzPublicIpAddress -ResourceGroupName $PublicIpRG -ResourceName $PublicIpName | select -ExpandProperty Id
$VNet = Get-AzVirtualNetwork -ResourceGroupName $VNetRG -Name $VNetName
$subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VNet -Name $SubnetName
$apimVirtualNetwork = New-AzApiManagementVirtualNetwork -SubnetResourceId $subnet.Id
$apim = Get-AzApiManagement -ResourceGroupName $apiManagementRG -Name $apiManagementName
$apim.VpnType = "Internal"
Update-AzApiManagementRegion -ApiManagement $apim -Location $Location -Sku $Sku -Capacity $Capacity -VirtualNetwork $apimVirtualNetwork -PublicIpAddressId $PublicIpAddressId
Set-AzApiManagement -InputObject $apim