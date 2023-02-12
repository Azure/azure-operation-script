# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

# Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.

# Quick Start

1. Review [Connection](https://github.com/Azure/azure-operation-script/tree/dev/Connection)
1. Fork a repository or download the necessary script to local computer
1. Check out the master branch
1. Install the PowerShell Module and Azure CLI (Optional)
1. Modify the script (Optional)
1. Execute the script

# Instruction

### Prerequisites

> The version stated below is the baseline only, recommend to install newer version

> Azure Cloud Shell require to install PowerShell Module **ImportExcel** and **PnP.PowerShell** only

| Item | Name | Version | Installation | 
| - | - | - | - | 
| 1 | PowerShell | 5.1 <br /> 7.2.2 | [docs.microsoft.com](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows)  | 
| 2 | Az Module | 9.3.0 | [PowerShell Gallery](https://www.powershellgallery.com/packages/Az) |
| 3 | Az.DataProtection Module | 0.3.0 | [PowerShell Gallery](https://www.powershellgallery.com/packages/Az.DataProtection) |
| 4 | Azure Active Directory V2 Module (AzureAD) | 2.0.2.140 | [PowerShell Gallery](https://www.powershellgallery.com/packages/AzureAD) |
| 5 | Azure CLI | 2.35.0 | [docs.microsoft.com](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) |
| 6 | ImportExcel | 7.4.2 | [PowerShell Gallery](https://www.powershellgallery.com/packages/ImportExcel) |
| 7 | PnP.PowerShell | 1.11.0 | [PowerShell Gallery](https://www.powershellgallery.com/packages/PnP.PowerShell) |

### Installation

```PowerShell
# Run the command to verify the installed module
Get-InstalledModule

# Run as Administrator to install for Powershell 7
Install-Module -Name Az -RequiredVersion 9.3.0 -Confirm:$false -Force
Install-Module -Name Az.DataProtection -RequiredVersion 0.3.0 -Confirm:$false -Force
Install-Module -Name ImportExcel -RequiredVersion 7.4.2 -Confirm:$false -Force
Install-Module -Name PnP.PowerShell -RequiredVersion 1.11.0 -Confirm:$false -Force

# Run as Administrator to install for Powershell 5.1
Install-Module -Name AzureAD -RequiredVersion 2.0.2.140 -Confirm:$false -Force
Install-Module -Name ImportExcel -RequiredVersion 7.4.2 -Confirm:$false -Force
```

### Script Parameter

- Variable under **# Global Parameter** is expected to modify
- Variable under **# Script Variable** is expected NOT to modify
- Comment **Login** section in the script if using [Connect-To-Cloud.ps1](https://github.com/Azure/azure-operation-script/blob/dev/Connection/Connect-To-Cloud.ps1) to login Azure

### Subscription Management

Most of the scripts support to retrieve information or modify configuration from multiple subscriptions. There is a simple foreach loop to iterate through the subscriptions in the scripts.

```PowerShell
foreach ($Subscription in $Global:Subscriptions) {
  # ...
}
```

Below are the sample command to retrieve subscription(s) which will be assigned to variable **$Global:Subscriptions**

```PowerShell
# Exclude disabled or legacy subscription
$TenantId = "Tenant Id"
$Global:Subscriptions = Get-AzSubscription -TenantId $TenantId | ? {$_.State -eq "Enabled" -and $_.Name -ne "Access to Azure Active Directory"}
```

```PowerShell
# Get specific subscription
$TenantId = "Tenant Id"
$SubscriptionName = "Subscription Name"
$Global:Subscriptions = Get-AzSubscription -TenantId $TenantId | ? {$_.Name -like "*$SubscriptionName*" -and $_.State -eq "Enabled"} 
```

# Issue Log

### 1. AzureAD Module

> Encounter error using Connect-AzureAD due to the module is not compatible with PowerShell 7

```PowerShell
Could not load type 'System.Security.Cryptography.SHA256Cng' from assembly
```

**Workaround**

Use PowerShell 5.1

**Reference**

- [GitHub Issue Log 10473](https://github.com/PowerShell/PowerShell/issues/10473)
- [Microsoft Question 259835](https://docs.microsoft.com/en-us/answers/questions/259835/powershell-login-error.html)

### 2. Azure Application Gateway with Redirection Rule

> Fail to provision using following commands

```PowerShell
# Using RedirectConfiguration
$RedirectConfiguration = New-AzApplicationGatewayRedirectConfiguration -Name "DefaultRedirectConfiguration" -RedirectType Permanent -TargetUrl "http://8.8.8.8"
$RoutingRule = New-AzApplicationGatewayRequestRoutingRule -Name "DefaultRoutingRule"-RuleType Basic -HttpListener $HttpListener -RedirectConfiguration $RedirectConfiguration -BackendHttpSettings $BackendHttpSetting

# Using RedirectConfigurationId
$RedirectConfiguration = New-AzApplicationGatewayRedirectConfiguration -Name "DefaultRedirectConfiguration" -RedirectType Permanent -TargetUrl "http://8.8.8.8" -IncludePath $false -IncludeQueryString $false
$RoutingRule = New-AzApplicationGatewayRequestRoutingRule -Name "DefaultRoutingRule"-RuleType Basic -HttpListenerId $HttpListener.Id -RedirectConfigurationId $RedirectConfiguration.Id

# Above command encounter same error message
# New-AzApplicationGateway: Resource...agw-core-prd-sea-001/redirectConfigurations/DefaultRedirectConfiguration referenced by resource...agw-core-prd-sea-001/requestRoutingRules/DefaultRoutingRule was not found. Please make sure that the referenced resource exists, and that both resources are in the same region.
```

**Workaround**

Use Azure Portal to provision

### 3. PnP Online

> Unable to login using Connect-PnPOnline

```PowerShell
Connect-PnPOnline:
Line |
   2 |  Connect-PnPOnline -Url $SiteURL -Credentials $Cred
     |  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | AADSTS65001: The user or administrator has not consented to use the application with ID '31359c7f-bd7e-475c-86db-fdb8c937548e' named 'PnP Management Shell'. Send an interactive authorization request for this user and resource.
Trace ID: 246ce9c8-fee6-4efd-a68b-a837a9f85500
Correlation ID: 14f0e0fc-0bd6-44ec-beff-2af5f2472622
Timestamp: 2022-05-31 03:43:47Z
```

- [Fix Connect-PnPOnline : AADSTS65001: The user or administrator has not consented to use the application with ID '‘'31359c7f-bd7e-475c-86db-fdb8c937548e'](https://www.sharepointdiary.com/2021/08/fix-connect-pnponline-aadsts65001-user-or-administrator-has-not-consented-to-use-the-application.html)

```PowerShell
Connect-PnPOnline: Cannot find certificate with this thumbprint in the certificate store.
```
- [Azure function: Cannot find certificate with this thumbprint in the certificate](https://stackoverflow.com/questions/66386136/azure-function-cannot-find-certificate-with-this-thumbprint-in-the-certificate)
- [Granting access via Azure AD App-Only](https://docs.microsoft.com/en-us/sharepoint/dev/solution-guidance/security-apponly-azuread)

**Solution**

Refer to provided links to register the service principle with proper API permission assigned

### 4. Azure Automation Runbooks Job

> Turning into suspended mode when adding file to Sharepoint

- [Azure Automation Runbook job goes into suspended mode when adding file to Sharepoint](https://docs.microsoft.com/en-us/answers/questions/431771/azure-automation-runbook-job-goes-into-suspended-m.html)
- [Connect SPonline using pnp by Azure app registration](https://docs.microsoft.com/en-us/answers/questions/214757/connect-sponline-using-pnp-by-azure-app-registrati.html)
- [Add-PnPListItem - failing in RunBook on Azure Automation](https://github.com/pnp/PnP-PowerShell/issues/1541)

**Solution**

Refer to provided links to register the service principle with proper API permission assigned

# Appendix

### 1. Disable warning messages in Azure PowerShell

```PowerShell
# Disable breaking change warning messages
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value "true"

# SuppressAzurePowerShellBreakingChangeWarnings Variable may not work for specific Az command, add Common Parameters 'WarningAction' instead
# Example
Get-AzMetric -ResourceId $ResourceId -MetricName 'storage' -WarningAction SilentlyContinue
```

**Reference**

- [Configuration](https://docs.microsoft.com/en-us/powershell/azure/faq)
- [Common Parameters](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_commonparameters)
- [Add to PowerShell profile to execute this command when every PowerShell session start](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles#the-profile-files)

### 2. Enable Azure Preview Feature

> Allow updating Virtual Network Address Space without remove peering

```PowerShell
# Verify AllowUpdateAddressSpaceInPeeredVnets is registered per Subscription 
az feature show --namespace "Microsoft.Network" --name "AllowUpdateAddressSpaceInPeeredVnets"

# Register AllowUpdateAddressSpaceInPeeredVnets per Subscription 
az feature register --namespace "Microsoft.Network" --name "AllowUpdateAddressSpaceInPeeredVnets"

# Once 'AllowUpdateAddressSpaceInPeeredVnets' is registered, invoke to get the change propagated
az provider register -n Microsoft.Network
```

> Managed Disk with Zone redundant

```PowerShell
# Register
Register-AzProviderFeature -FeatureName "SsdZrsManagedDisks" -ProviderNamespace "Microsoft.Compute" 

# Verify
Get-AzProviderFeature -FeatureName "SsdZrsManagedDisks" -ProviderNamespace "Microsoft.Compute"  
```

> Image and Snapshot with Zone redundant

```PowerShell
# Register
Register-AzProviderFeature -FeatureName "ZRSImagesAndSnapshots" -ProviderNamespace "Microsoft.Compute" 

# Verify
Get-AzProviderFeature -FeatureName "ZRSImagesAndSnapshots" -ProviderNamespace "Microsoft.Compute"  
```

### 3. Differences between Windows PowerShell 5.1 and PowerShell 7.x

#### Multi-threading

> All scripts with Multi-threading Capability (Mainly apply to Well-Architected scripts) require PowerShell v7.* by using **Pipeline parallelization with ForEach-Object -Parallel**

**Reference**

- [Official Detail Guide](https://docs.microsoft.com/en-us/powershell/scripting/whats-new/differences-from-windows-powershell)
- [What's New in PowerShell 7.0](https://docs.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-70?view=powershell-7.2&viewFallbackFrom=powershell-7.1)
- [RunspaceFactory.CreateRunspacePool Method](https://docs.microsoft.com/en-us/dotnet/api/system.management.automation.runspaces.runspacefactory.createrunspacepool?view=powershellsdk-7.0.0)
- [Beginning Use of PowerShell Runspaces: Part 1](https://devblogs.microsoft.com/scripting/beginning-use-of-powershell-runspaces-part-1/)
- [PowerShellTaskRunner.cs](https://gist.github.com/rjmholt/02fe49189540acf0d2650f571f5176db)

#### Get-WmiObject

> WMI cmdlets have been replaced with the CIM cmdlets 

```PowerShell
# Example
Get-CimInstance -ClassName <ClassName>
```

**Reference**

- [Get-WmiObject not available](https://github.com/PowerShell/PowerShell/issues/15565)