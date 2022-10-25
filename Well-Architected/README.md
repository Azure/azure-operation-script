# Summary of Scope

- Get App Service and App Service Plan Configuration
   - Include Availability Zones, VNet Integration
- Get Azure Backup status of **Azure VM**, **SQL Server in Azure VM**, and **Azure Blob Storage**
- Get Azure SQL and Azure SQL Managed Instance Configuration
   - Include Availability Zones, Firewall Rule, Replication, Backup
- Get Diagnostic Setting
   - Only mainstream services support Diagnostic Log
- Get Storage Account and Azure Cache for Redis Configuration
   - Include Availability Zones, Networking, Firewall Rule
- Get Availability Zone Enabled Service  
- Get Classic Resource
- Get Unmanaged Disk

# QuickStart

1. Download all scripts to same local directory
1. Modify **Global Parameter**
1. Open a **Windows PowerShell** with **Version 7 or above**
1. Change current directory to where the script exist
1. Run the script either one of below method
   1. Directly execute **Run.ps1**
   1. Copy the content of **Run.ps1** and paste into **Windows PowerShell**
1. [Optional] Separately Login Azure using Az Module and Azure CLI in **Windows PowerShell** and retrieve the list of certain subscriptions

# Functionality

## Availability Zone

Get the Azure Services with **Availability Zones** enabled in the subscription of follow Azure Services:

- **Get-AZoneEnabledService.ps1**
  - Application Gateway
  - Event Hub (Namespace)
  - Azure Kubernetes Service (AKS)
  - Virtual Network Gateway
  - Recovery Services Vault
  - Storage Account
  - Virtual Machine
  - Virtual Machine Scale Set
  - Managed Disk
  - API Management
  - Azure Firewall
- **Get-AzureSql-Configuration.ps1**
  - Azure SQL Database
- **Get-AzureSqlMI-Configuration.ps1**
  - Azure SQL Managed Instance
- **Get-AppService.ps1**
  - App Service
  - Function App

**Reference**

- [Regions and Availability Zones in Azure](https://docs.microsoft.com/en-us/azure/availability-zones/az-overview#services-by-category)

# Deep Dive on resource type

## App Service

- [Zone Redundant](https://docs.microsoft.com/en-us/azure/app-service/how-to-zone-redundancy#how-to-deploy-a-zone-redundant-app-service)
- Private Endpoint is only used for [Incoming Flows](https://docs.microsoft.com/en-us/azure/app-service/networking/private-endpoint#conceptual-overview) to Web App, outgoing flows won't use Private Endpoint
- Require [Azure CLI version 2.31.0 or later](https://docs.microsoft.com/en-us/cli/azure/release-notes-azure-cli#december-07-2021) to retrieve the Zone redundant status

## Azure Kubernetes Service (AKS)

- In Summary Page, it indicates by node pool instead of Kubernetes Cluster instance 

## Storage Account

- [Allow blob public access](https://docs.microsoft.com/en-us/azure/storage/blobs/anonymous-read-access-prevent)
- [Allow Shared Key Access](https://docs.microsoft.com/en-us/azure/storage/common/shared-key-authorization-prevent)
- Private Endpoint
- Allow Public Network Access
- v1 is recommended to upgrade

## Azure SQL

**Get-AzureSql-Configuration.ps1**

- Capacity
- PITR
- LTR
- Backup Storage
- Replication
- Redundancy
- Usage
- Private Endpoint
- [Allow Public Network Access](https://docs.microsoft.com/en-us/azure/azure-sql/database/connectivity-settings#deny-public-network-access)
- Allow Azure Service Access
  - [New-AzureSqlDatabaseServerFirewallRule](https://docs.microsoft.com/en-us/powershell/module/servicemanagement/azure.service/new-azuresqldatabaseserverfirewallrule)
- [Outbound firewall rules](https://docs.microsoft.com/en-us/azure/azure-sql/database/outbound-firewall-rule-overview)

#### Limitation

- Support to identify a Replica Database, but not support to confirm whether a Database has enabled Geo-Replica
- Support to identify a Database is added to Failover Group, but not support to explicitly indicate Primary node and Secondary node of Failover Group

## Azure SQL Managed Instance

**Get-AzureSqlMI-Configuration.ps1**

- Capacity
- PITR
- LTR
- Backup Storage
- Replication
- Redundancy
- Usage
- Private Endpoint
- [Public Endpoint](https://docs.microsoft.com/en-us/azure/azure-sql/managed-instance/public-endpoint-configure)

#### Limitation

- Not support to query the Instance Pool
- Support to identify a Database is added to Failover Group, but not support to explicitly indicate Primary and Secondary of Failover Group

## Redis Cache

**Get-Redis-NetworkIsolation.ps1**

- Get **Availability Zones** provision status
- Get Public Network Access configuration
- Collect the configuration of Network Isolation Method of Redis Cache Instance
- Zone Redundancy isn't supported with geo-replication
- Persistence isn't supported with geo-replication
- Require Azure CLI to get Redis information

**Reference**

- [Azure Cache for Redis network isolation options](https://docs.microsoft.com/en-us/azure/azure-cache-for-redis/cache-network-isolation)
- [Geo-replication prerequisites](https://docs.microsoft.com/en-us/azure/azure-cache-for-redis/cache-how-to-geo-replication#geo-replication-prerequisites)

## Virtual Machine

- Require Azure CLI to get Unmanaged Disk information

#### Limitation

Verifying the status of **Region Disaster Recovery** and **Zone to Zone Disaster Recovery** by following method:

- Azure Portal (Supported)
- Az Module (Supported)
  - Require additional permission to perform action 'Microsoft.RecoveryServices/vaults/extendedInformation/write'
- Azure CLI (Not Supported)

## Azure Backup

#### Limitation

- Support to query the existing Azure VM only
  - Not support to detect a deleted VM but backup copy exist in a Recovery Service Vault
- Not Support to list the Azure File Share with/without backup enabled
  - Although RunAs account with read only permission is capable to retrieve Azure File Share Backup Copy by running Get-AzRecoveryServicesBackupProtectionPolicy, it is not able to list Azure File Share of all storage account without access key or using read only access account
- Backup status SQL Server in Azure VM 
  - Clarification is relying on Resource Type **Microsoft.SqlVirtualMachine/SqlVirtualMachines**
  - Azure VM Agent has to function properly in order to reflect whether SQL Server is installed on Azure VM 
  - Support to query the Databases that enable backup, not support to query the Databases that has not enable backup

# Resource Type Matrix

| Azure Services | Resource Type | Is Hidden Resource | Support Tagging | 
| - | - | - | - | 
| Availability Test | microsoft.insights/webtests | No | Yes |
| API Connection | Microsoft.Web/connections | No | Yes |
| Application Insights | microsoft.insights/components | No | Yes |
| Data collection Rule | microsoft.Insights/dataCollectionRules | No | Yes |
| Azure Workbook | microsoft.insights/workbooks | No | Yes |
| Azure Lab Account | Microsoft.LabServices/labaccounts | No | Yes |
| Data Share | Microsoft.DataShare/accounts | No | Yes |
| Managed Identity | Microsoft.ManagedIdentity/userAssignedIdentities | No | Yes |
| On-premises Data Gateway | Microsoft.Web/connectionGateways | No | Yes |
| App Service Environment | Microsoft.Web/hostingEnvironments | No | Yes |
| Azure DevOps Organization | microsoft.visualstudio/account | No | No | 
| SQL Managed Instance Database | Microsoft.Sql/managedInstances/databases | No | No | 
| SQL Virtual Cluster | Microsoft.Sql/virtualClusters | No | No | 
| Service Endpoint Policy | Microsoft.Network/serviceEndpointPolicies | No | Yes | 