# Highlight

#### Update VNet configuration

- Referring to [Official Prerequisites](https://docs.microsoft.com/en-us/azure/api-management/compute-infrastructure#update-vnet-configuration), if modifying VNet integration, the subnet must be different from the one currently used for the instance hosted on the stv1 platform, and a network security group must be attached. In fact, this apply to stv2 platform as well
- [Cannot VNet Connection External for API Management](https://docs.microsoft.com/en-us/answers/questions/737110/cannot-vnet-connection-external-for-api-management.html)

#### Associate NSG to APIM with VNet Integration with certain rules

- The recommended configuration for API Management subnet that allows inbound management traffic on port 3443 only from the set of Azure IP addresses encompassed by the ApiManagement service tag.
- [Common network configuration issues](https://docs.microsoft.com/en-us/azure/api-management/api-management-using-with-vnet?tabs=stv2#-common-network-configuration-issues)
- [Virtual network configuration reference: API Management(stv2)](https://docs.microsoft.com/en-us/azure/api-management/virtual-network-reference?tabs=stv2)

#### Integrate API Management in an internal virtual network with Application Gateway

- [Official Procedure](https://docs.microsoft.com/en-us/azure/api-management/api-management-howto-integrate-internal-vnet-appgateway)
- [Some WAF rules need to be disabled](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-integrate-internal-vnet-appgateway#expose-the-developer-portal-and-management-endpoint-externally-through-application-gateway)

#### **-PublicIpAddressId** parameter

Supported since Az Module v8.1.0

# Known Issue

### 1. Fail to change VNet Integration

> Changing VNet Integration type from External to Internal OR Internal to External with same virtual network and public IP address

```PowerShell
Invalid parameter: When updating `subnetResourceId` to `/subscriptions/<subscription_id>/resourcegroups/network/providers/microsoft.network/virtualnetworks/vnet-hub-prd-eas-001/subnets/snet-apim-002` in API Management service deployment with Virtual Network configured `Internal`, the Public IP Address property in location `East Asia`, must be a different from `/subscriptions/<subscription_id>/resourcegroups/APIM/providers/Microsoft.Network/publicIPAddresses/pip-apim` and should not match any of the existing location(s) (East Asia), as we need to create a new deployment to avoid downtime.
```

**Solution**

> Example for External to Internal 

1. Change VNet Integration from External to None
2. Wait 30 minutes to 1 hour for Gateway Instance(s) be completely removed at the backend 
3. Change VNet Integration from None to Internal

# Network

- [Azure API Management networking explained](https://techcommunity.microsoft.com/t5/azure-developer-community-blog/azure-api-management-networking-explained/ba-p/3274323)
- [API Management - Networking FAQs (Demystifying Series II)](https://techcommunity.microsoft.com/t5/azure-paas-blog/api-management-networking-faqs-demystifying-series-ii/ba-p/1502056)

# Az Module Information

### Instance Configuration

- [Set-AzApiManagement](https://docs.microsoft.com/en-us/powershell/module/az.apimanagement/set-azapimanagement)

### Virtual Network

- [Get-AzVirtualNetworkSubnetConfig](https://docs.microsoft.com/en-us/powershell/module/az.network/get-azvirtualnetworksubnetconfig)
- [New-AzApiManagementVirtualNetwork](https://docs.microsoft.com/en-us/powershell/module/az.apimanagement/new-azapimanagementvirtualnetwork)
- [Update-AzApiManagementRegion](https://docs.microsoft.com/en-us/powershell/module/az.apimanagement/update-azapimanagementregion)
- [PsApiManagementVirtualNetwork Class](https://docs.microsoft.com/en-us/dotnet/api/microsoft.azure.commands.apimanagement.models.psapimanagementvirtualnetwork)