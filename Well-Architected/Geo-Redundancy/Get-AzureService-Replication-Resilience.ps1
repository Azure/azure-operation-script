# Global Parameter
#$TenantId = ""
$ExcelOutputFolder = "C:\Temp"
$ExcelFileName = "Replication-Assessment.xlsx" # Export Result to Excel file 

# Script Variable
if ($ExcelOutputFolder -notlike "*\") {$ExcelOutputFolder += "\"}
$Global:ExcelFullPath = $ExcelOutputFolder + $ExcelFileName
$Global:ReplicationPair = @()
$Global:RedundancySetting = @()
$Global:RedundancySettingSummary = @()
[int]$CurrentItem = 1
$ErrorActionPreference = "Continue"

function Get-LocationDisplayName {
    param (
        [string]$Location
    )

    if ($Location -like "* *") {
        return $Location
    } else {
        [string]$LocationDisplayName = $Global:NameReference | ? {$_.Location -eq $Location} | select -ExpandProperty DisplayName

        return $LocationDisplayName
    }
}

function Add-Record {
    param (
        $SubscriptionName,
        $SubscriptionId,
        $ResourceGroup,
        $Location,
        $InstanceName,
        $InstanceType,
        $CurrentRedundancyType,
        $Remark
    )

    # Rename
    $Location = Get-LocationDisplayName -Location $Location

    # Add to array
    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $SubscriptionName
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $SubscriptionId
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $ResourceGroup
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Location
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "InstanceName" -Value $InstanceName
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "InstanceType" -Value $InstanceType
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "CurrentRedundancyType" -Value $CurrentRedundancyType
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Remark" -Value $Remark
    $Global:RedundancySetting += $obj
}

# Disable breaking change warning messages
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value "true"

# Module
Import-Module ImportExcel

# Login
# Referring to https://github.com/Azure/azure-operation-script/tree/dev/Connection
#Connect-AzAccount -Tenant $TenantId

# Get Azure Subscription
# Referring to https://github.com/Azure/azure-operation-script#subscription-management
#$Global:Subscriptions = Get-AzSubscription -TenantId $TenantId | ? {$_.State -eq "Enabled" -and $_.Name -ne "Access to Azure Active Directory"}
$Global:Subscriptions = Import-Csv SubscriptionList.csv

# Get the Latest Location Name, Display Name, and Paired Region
$Global:NameReference = Get-AzLocation | ? {$_.RegionType -eq "Physical" -and $_.DisplayName -notlike "*EUAP*"} | Sort-Object GeographyGroup, DisplayName

#Region Azure cross-region replication pairings
# As of Feb 2023, the output of Get-AzLocation in terms of paired region of Australia Central and Australia Central 2 NOT aligned with https://learn.microsoft.com/en-us/azure/reliability/cross-region-replication-azure#azure-cross-region-replication-pairings-for-all-geographies
# Exclude paired region (West US 3 <> East US)
# Exclude Governments
foreach ($item in $Global:NameReference) {
    if ($Global:ReplicationPair.RegionalPair1 -notcontains $item.DisplayName -and $Global:ReplicationPair.RegionalPair2 -notcontains $item.DisplayName) {
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Geography" -Value $item.GeographyGroup
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "RegionalPair1" -Value $item.DisplayName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "RegionalPair2" -Value (Get-LocationDisplayName -Location $item.PairedRegion.Name)
        $Global:ReplicationPair += $obj
    }
}
#EndRegion Azure cross-region replication pairings

# Main
$Global:StartTime = Get-Date
Write-Host ("`n" + "=" * 70)
Write-Host "`nGet Configuration of Azure Service Replication and Resilience" -ForegroundColor Cyan

foreach ($Subscription in $Global:Subscriptions) {
    Write-Host ("`n")
    Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
    
    # Set current subscription
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id -TenantId $Subscription.TenantId
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Global:Subscriptions.Count + " Subscription: " + $Subscription.Name) -ForegroundColor Yellow
    $CurrentItem++

    # Recovery Services Vault
    Write-Host ("`nRecovery Services Vault") -ForegroundColor Blue
    $InstanceType = "Recovery Services Vault"
    $RecoveryServicesVaults = Get-AzRecoveryServicesVault | Sort-Object Name
    $ReplicationProtectedItems = @()

    foreach ($RecoveryServicesVault in $RecoveryServicesVaults) {
        Write-Host $($RecoveryServicesVault.Name)
        $BackupProperty = Get-AzRecoveryServicesBackupProperty -Vault $RecoveryServicesVault
        $RedundancyConfig = $BackupProperty.BackupStorageRedundancy
        $CrossRegionRestore = $BackupProperty.CrossRegionRestore

        # Add Cross-Region Restore setting to Remark
        if ($RedundancyConfig -like "*Geo*") {
            if ($CrossRegionRestore) {
                $RedundancyConfig += " with Cross-Region Restore enabled"
            } else {
                $RedundancyConfig += " with Cross-Region Restore disabled"
            }
        } 
 
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $RecoveryServicesVault.ResourceGroupName -Location $RecoveryServicesVault.Location -InstanceName $RecoveryServicesVault.Name -InstanceType $InstanceType -CurrentRedundancyType $RedundancyConfig -Remark ""
    
        # VM Disaster Recovery
        $VaultContext = Set-AzRecoveryServicesAsrVaultContext -Vault $RecoveryServicesVault # Perform action 'Microsoft.RecoveryServices/vaults/extendedInformation/write' 
        $fabrics = Get-AzRecoveryServicesAsrFabric
        foreach ($fabric in $fabrics) {
            $ProtectionContainers = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $fabric | ? {$_.FabricType -eq "Azure"}

            foreach ($ProtectionContainer in $ProtectionContainers) {
                $ReplicationProtectedItems += Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $ProtectionContainer
            }
        }
    }

    # Backup Vault
    Write-Host ("`nBackup Vault") -ForegroundColor Blue
    $InstanceType = "Backup Vault"
    $BackupVaults = Get-AzResource | ? {$_.ResourceType -eq "Microsoft.DataProtection/BackupVaults"} | Sort-Object Name

    foreach ($BackupVault in $BackupVaults) {
        Write-Host $($BackupVault.Name)
        $BackupVaultInstance = Get-AzDataProtectionBackupVault -ResourceGroupName $BackupVault.ResourceGroupName -VaultName $BackupVault.Name
        $RedundancyConfig = $BackupVaultInstance.StorageSetting.Type
        
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $BackupVault.ResourceGroupName -Location $BackupVaultInstance.Location -InstanceName $BackupVaultInstance.Name -InstanceType $InstanceType -CurrentRedundancyType $RedundancyConfig -Remark ""
    }

    # Virtual Machine
    Write-Host ("`nVirtual Machine") -ForegroundColor Blue
    $InstanceType = "Virtual Machine Disaster Recovery"
    $vms = Get-AzVM | ? {$_.ResourceGroupName -notlike "databricks-rg*"}

    foreach ($vm in $vms) {
        Write-Host $($vm.Name)
        $InstanceTypeDetail = "Standalone"
        
        # Location
        [array]$array = $vm.Zones
        $Location = $vm.Location 

        if ($array.Count -gt 0) {
            $Location = $Location + " (Zone: " + ($array -join ",") + ")"
        } else {
            $Location = $Location
        }

        # Availability Set
        if ($vm.AvailabilitySetReference.Id -ne $null ) {
            $InstanceTypeDetail = "Availability Set"
        }
        
        # Virtual Machine Scale Set
        if ($vm.VirtualMachineScaleSet -ne $null ) {
            $InstanceTypeDetail = "Virtual Machine Scale Set"
        }

        # Disaster Recovery
        $IsAsrEnabled = $ReplicationProtectedItems.ProviderSpecificDetails | ? {$_.FabricObjectId -eq $vm.Id}

        if ($IsAsrEnabled -and $IsAsrEnabled -ne $null) {
            $RedundancyConfig = "Enabled"
        } else {
            $RedundancyConfig = "Disabled"
        }

        # Add-Record
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $vm.ResourceGroupName -Location $Location -InstanceName $vm.Name -InstanceType $InstanceType -CurrentRedundancyType $RedundancyConfig -Remark $InstanceTypeDetail
    }

    # Storage Account
    Write-Host ("`nStorage Account") -ForegroundColor Blue
    $InstanceType = "Storage Account"
    $StorageAccounts = Get-AzStorageAccount | Sort-Object StorageAccountName

    foreach ($StorageAccount in $StorageAccounts) {
        Write-Host $($StorageAccount.StorageAccountName)
        $RedundancyConfig = $StorageAccount.Sku.Name.Substring($StorageAccount.Sku.Name.IndexOf("_") + 1)
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $StorageAccount.ResourceGroupName -Location $StorageAccount.Location -InstanceName $StorageAccount.StorageAccountName -InstanceType $InstanceType -CurrentRedundancyType $RedundancyConfig -Remark ""
    }
    
    # Api Management
    Write-Host ("`nApi Management") -ForegroundColor Blue
    $InstanceType = "Api Management"
    $apims = Get-AzApiManagement | Sort-Object Name

    foreach ($apim in $apims) {
        Write-Host $($apim.Name)
        $InstanceTypeDetail = ""
        $Location = $apim.Location # Primary Location
        $sku = $apim.Sku.ToString()

        if ($sku -in ("Premium", "Isolated")) {
            # Additional Region
            [array]$AdditionalRegions = $apim.AdditionalRegions

            if ($AdditionalRegions.Count -gt 0) {
                $RedundancyConfig = "Multi-Region Enabled"
                foreach ($AdditionalRegion in $AdditionalRegions) {
                    if ($InstanceTypeDetail -eq "") {
                        $InstanceTypeDetail = "Additional Region: " + $AdditionalRegion.Location
                    } else {
                        $InstanceTypeDetail += ", " + $AdditionalRegion.Location
                    }
                }
            } else {
                $RedundancyConfig = "Disabled"
                $InstanceTypeDetail = "No Multi-Region Deployment"
            }
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $apim.ResourceGroupName -Location $apim.Location -InstanceName $apim.Name -InstanceType $InstanceType -CurrentRedundancyType $RedundancyConfig -Remark $InstanceTypeDetail
        } else {
            $RedundancyConfig = "Multi-Region not supported by current Sku"
            $InstanceTypeDetail = ""
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $apim.ResourceGroupName -Location $apim.Location -InstanceName $apim.Name -InstanceType $InstanceType -CurrentRedundancyType $RedundancyConfig -Remark $InstanceTypeDetail
        }
    }

    # Azure SQL Database
    Write-Host ("`nSQL Database") -ForegroundColor Blue
    $SqlServers = Get-AzSqlServer
	$Databases = $SqlServers | Get-AzSqlDatabase | ? {$_.DatabaseName -ne "Master" -and $_.SecondaryType -ne "Geo"} | Sort-Object DatabaseName

	foreach ($Database in $Databases) {
        Write-Host $($Database.DatabaseName)
        $SqlServer = $SqlServers | ? {$_.ResourceGroupName -eq $Database.ResourceGroupName -and $_.ServerName -eq $Database.ServerName}

        # Pricing Tier
        $Edition = $Database.Edition
        if ($Edition -eq "Premium" -or $Edition -eq "Standard" -or $Edition -eq "Basic") {
            $sku = $Database.CurrentServiceObjectiveName
            $vCore = "N/A"
        } else {
            $sku = $Database.SkuName
            $vCore = $Database.Capacity
        }

        # Elastic Pool
        if ([string]::IsNullOrEmpty($Database.ElasticPoolName)) { 
            $PoolName = "N/A" 
        } else { 
            $PoolName = $Database.ElasticPoolName 
            $ElasticPool = Get-AzSqlElasticPool -ResourceGroupName $Database.ResourceGroupName -ServerName $Database.ServerName -ElasticPoolName $PoolName

            if ($ElasticPool.Edition -eq "Premium" -or $ElasticPool.Edition -eq "Standard" -or $ElasticPool.Edition -eq "Basic") {
                $sku += " " + $ElasticPool.Capacity + " DTU"
            } else {
                $sku += " " + $ElasticPool.SkuName
                $vCore = $ElasticPool.Capacity
            }
        }

        # Availability Zone 
        $ZoneRedundant = $Database.ZoneRedundant
        if ($ZoneRedundant) {
            $ZoneRedundant = "Enabled"
        } else {
            $ZoneRedundant = "Disabled"
        }

        # Backup Storage Redundancy
        $InstanceType = "SQL Database Backup Storage Redundancy"
        $InstanceTypeDetail = ""
        if ([string]::IsNullOrEmpty($Database.CurrentBackupStorageRedundancy)) {
            $RedundancyConfig = "N/A"
        } else {
            $RedundancyConfig = $Database.CurrentBackupStorageRedundancy
        }

        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $Database.ResourceGroupName -Location $Database.Location -InstanceName $Database.DatabaseName -InstanceType $InstanceType -CurrentRedundancyType $RedundancyConfig -Remark $InstanceTypeDetail

        # Failover Group
        $InstanceType = "SQL Database Auto-Failover Group"
        $RedundancyConfig = "Disabled"
        $InstanceTypeDetail = "No Multi-Region Deployment"
        $FailoverGroups = Get-AzSqlDatabaseFailoverGroup -ResourceGroupName $Database.ResourceGroupName -ServerName $Database.ServerName
        if (![string]::IsNullOrEmpty($FailoverGroups)) {
            foreach ($FailoverGroup in $FailoverGroups) {
                if ($FailoverGroup.DatabaseNames -contains $Database.DatabaseName) {
                    $RedundancyConfig = "Enabled"
                    $InstanceTypeDetail = "Failover Group Name: " + $FailoverGroup.FailoverGroupName.ToString()
                }
            }
        }

        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $Database.ResourceGroupName -Location $Database.Location -InstanceName $Database.DatabaseName -InstanceType $InstanceType -CurrentRedundancyType $RedundancyConfig -Remark $InstanceTypeDetail

        # Dedicated SQL pool
        if ($Database.Edition -eq "DataWarehouse") {
            $InstanceType = "Dedicated SQL pool Geo-Backup Policy"
            $InstanceTypeDetail = ""
            $Geo = Get-AzSqlDatabaseGeoBackupPolicy -ResourceGroupName $Database.ResourceGroupName -DatabaseName $Database.DatabaseName -ServerName $Database.ServerName
            $RedundancyConfig = $Geo.State.ToString()
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $Database.ResourceGroupName -Location $Database.Location -InstanceName $Database.DatabaseName -InstanceType $InstanceType -CurrentRedundancyType $RedundancyConfig -Remark $InstanceTypeDetail
        }
    }

    # Azure SQL Managed Instance
    Write-Host ("`nSQL Managed Instance") -ForegroundColor Blue
    $SqlServers = Get-AzSqlInstance | Sort-Object ManagedInstanceName

    foreach ($SqlServer in $SqlServers) {
        Write-Host $($SqlServer.ManagedInstanceName)

        # Pricing Tier
        $Edition = $SqlServer.Sku.Tier
        $sku = $SqlServer.Sku.Name
        $vCore = $SqlServer.VCores

        # Availability Zone 
        $ZoneRedundant = $SqlServer.ZoneRedundant
        if ($ZoneRedundant) {
            $ZoneRedundant = "Enabled"
        } else {
            $ZoneRedundant = "Disabled"
        }
        
        # Backup Storage Redundancy
        $InstanceType = "SQL Managed Instance Backup Storage Redundancy"
        $InstanceTypeDetail = ""
        if ([string]::IsNullOrEmpty($SqlServer.BackupStorageRedundancy)) {
            $RedundancyConfig = "N/A"
        } else {
            $RedundancyConfig = $SqlServer.BackupStorageRedundancy
        }

        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $SqlServer.ResourceGroupName -Location $SqlServer.Location -InstanceName $SqlServer.ManagedInstanceName -InstanceType $InstanceType -CurrentRedundancyType $RedundancyConfig -Remark $InstanceTypeDetail

        # Failover Group
        $FailoverGroups = Get-AzSqlDatabaseInstanceFailoverGroup -ResourceGroupName $SqlServer.ResourceGroupName -Location $SqlServer.Location
        $InstanceType = "SQL Managed Instance Auto-Failover Group"
        $RedundancyConfig = "Disabled"
        $InstanceTypeDetail = "No Multi-Region Deployment"
        $IsPrimary = $true
        if (![string]::IsNullOrEmpty($FailoverGroups)) {
            foreach ($FailoverGroup in $FailoverGroups) {
                if ($FailoverGroup.PrimaryManagedInstanceName -eq $SqlServer.ManagedInstanceName -or $FailoverGroup.PartnerManagedInstanceName -eq $SqlServer.ManagedInstanceName) {
                    $RedundancyConfig = "Enabled"
                    $InstanceTypeDetail = "Failover Group Name: " + $FailoverGroup.Name.ToString()

                    if ($FailoverGroup.ReplicationRole -ne "Primary") {
                        $IsPrimary = $false
                    }
                }
            }
        }

        if ($IsPrimary) {
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $SqlServer.ResourceGroupName -Location $SqlServer.Location -InstanceName $SqlServer.ManagedInstanceName -InstanceType $InstanceType -CurrentRedundancyType $RedundancyConfig -Remark $InstanceTypeDetail
        }
    }

    # Azure Database for MySQL flexible Server
    Write-Host ("`nMySQL flexible Server") -ForegroundColor Blue
    $SqlFlexibleServers = Get-AzMySqlFlexibleServer | Sort-Object Name

    foreach ($SqlFlexibleServer in $SqlFlexibleServers) {
        Write-Host $($SqlFlexibleServer.Name)
        $SqlFlexibleServerRG = ($SqlFlexibleServer.Id -split "/")[4]

        # High Availability
        $InstanceType = "MySQL flexible Server High Availability"
        $RedundancyConfig = $SqlFlexibleServer.HighAvailabilityMode 
        $InstanceTypeDetail = $SqlFlexibleServer.HighAvailabilityState
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $SqlFlexibleServerRG -Location $SqlFlexibleServer.Location -InstanceName $SqlFlexibleServer.Name -InstanceType $InstanceType -CurrentRedundancyType $RedundancyConfig -Remark $InstanceTypeDetail
    
        # Backup Storage Redundancy
        $InstanceType = "MySQL flexible Server Backup Storage Redundancy"
        $InstanceTypeDetail = ""
        if ($SqlFlexibleServer.BackupGeoRedundantBackup -eq "Enabled") {
            $RedundancyConfig = "Geo"
        } else {
            $RedundancyConfig = "LRS"
        }
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $SqlFlexibleServerRG -Location $SqlFlexibleServer.Location -InstanceName $SqlFlexibleServer.Name -InstanceType $InstanceType -CurrentRedundancyType $RedundancyConfig -Remark $InstanceTypeDetail
    }

    # Event Hub
    Write-Host ("`nEvent Hub") -ForegroundColor Blue
    $EventHubs = Get-AzEventHubNamespace | Sort-Object Name
    $InstanceType = "Event Hub"
    $InstanceTypeDetail = "Event Hub Namespace"

    foreach ($EventHub in $EventHubs) {
        Write-Host $($EventHub.Name)

        # SKU
        $sku = ($EventHub.Sku.Tier + ": " + $EventHub.Sku.Capacity + " Unit")
        
        # Auto-Inflate
        if ($EventHub.IsAutoInflateEnabled -eq $true) {
            $remark = "Auto-Inflate Enabled, Maximum Throughput Units: " + $EventHub.MaximumThroughputUnits
        } else {
            $remark = ""
        }
        
        # Geo-Recovery
        $GeoDR = $null
        
        try {
            $GeoDR = Get-AzEventHubGeoDRConfiguration -ResourceGroupName $EventHub.ResourceGroupName -Namespace $EventHub.Name -ErrorAction SilentlyContinue
        } catch {
            
        }
        
        if ($GeoDR -ne $null) {
            if ($GeoDR.Role -ne "PrimaryNotReplicating") {
                $PartnerNamespace = $GeoDR.PartnerNamespace.Substring($GeoDR.PartnerNamespace.IndexOf("/namespaces/") + ("/namespaces/".Length))
                $remark += ("; Geo-Recovery Partner Namespace: " + $PartnerNamespace)
            }
        }
        
        if ($EventHub.ZoneRedundant -eq $true) {
            if ($GeoDR -ne $null) {
                $RedundancyConfig = "Zone Redundant with Geo-Recovery (" + $GeoDR.Role + ")"
            } else {
                $RedundancyConfig = "Zone Redundant"
            }
        } else {
            if ($GeoDR -ne $null) {
                $RedundancyConfig = "Geo-Recovery (" + $GeoDR.Role + ")"
            } else {
                $RedundancyConfig = "No Redundant"
            }
        }
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $EventHub.ResourceGroupName -Location $EventHub.Location -InstanceName $EventHub.Name -InstanceType $InstanceType -CurrentRedundancyType $RedundancyConfig -Remark $InstanceTypeDetail
    }
    # Event Hub
}

#Region Export
# Prepare Summary
foreach ($item in @("Recovery Services Vault", "Backup Vault", "Virtual Machine Disaster Recovery", "Storage Account", "Api Management", "SQL Database Backup Storage Redundancy", "SQL Database Auto-Failover Group", "Dedicated SQL pool Geo-Backup Policy", "SQL Managed Instance Backup Storage Redundancy", "SQL Managed Instance Auto-Failover Group", "MySQL flexible Server High Availability", "MySQL flexible Server Backup Storage Redundancy", "Event Hub")) {
    if ($Global:RedundancySetting.InstanceType -notcontains $item) {
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "InstanceType" -Value $item
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "RedundancyType" -Value "N/A"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Count" -Value "N/A"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Remark" -Value "Resource Not Found"
        $Global:RedundancySettingSummary += $obj
    }
}

foreach ($item in ($Global:RedundancySetting | group InstanceType | select Name, Count)) {
    $RedundancyType = $Global:RedundancySetting | ? {$_.InstanceType -eq $item.Name} | group CurrentRedundancyType | select Name, Count

    foreach ($type in $RedundancyType) {
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "InstanceType" -Value $item.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "RedundancyType" -Value $type.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Count" -Value $type.Count
        if ($type.Name -eq "Disabled") {
            $Remark = ($Global:RedundancySetting | ? {$_.InstanceType -eq $item.Name -and $_.CurrentRedundancyType -eq $type.Name} | select -First 1 | select -ExpandProperty Remark)
        } else {
            $Remark = ""
        }
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Remark" -Value $Remark
        $Global:RedundancySettingSummary += $obj
    }
}

# Export to Excel File
$Global:RedundancySettingSummary | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "Summary" -TableName "Summary" -TableStyle Medium16 -AutoSize -Append
$Global:RedundancySetting | Sort-Object InstanceType, InstanceName | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "InstanceDetail" -TableName "InstanceDetail" -TableStyle Medium16 -AutoSize -Append
#EndRegion Export

# End
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`nReplication and Resilience Assessment have been completed"
$Global:EndTime = Get-Date
$Duration = $Global:EndTime - $Global:StartTime
Write-Host ("`nTotal Process Time: " + $Duration.Hours + " Hours " + $Duration.Minutes + " Minutes " + $Duration.Seconds + " Seconds") -ForegroundColor Blue -BackgroundColor Black
Start-Sleep -Seconds 1
Write-Host ("`nAssessment Result is exported to " + $Global:ExcelFullPath + "`n")