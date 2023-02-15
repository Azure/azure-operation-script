# Global Parameter
$TenantId = ""
$ExcelOutputFolder = "C:\Temp"
$ExcelFileName = "Replication-Assessment.xlsx" # Export Result to Excel file 

# Script Variable
if ($ExcelOutputFolder -notlike "*\") {$ExcelOutputFolder += "\"}
$Global:ExcelFullPath = $Global:ExcelOutputFolder + $ExcelFileName
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
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Global:Subscriptions.Count + " Subscription: " + $Subscription.name) -ForegroundColor Yellow
    $CurrentItem++

    # Recovery Services Vault
    Write-Host ("`nRecovery Services Vault") -ForegroundColor Blue
    $RecoveryServicesVaults = Get-AzRecoveryServicesVault

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
 
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $RecoveryServicesVault.ResourceGroupName -Location $RecoveryServicesVault.Location -InstanceName $RecoveryServicesVault.Name -InstanceType "Recovery Services Vault" -CurrentRedundancyType $RedundancyConfig -Remark ""
    }

    # Backup Vault
    Write-Host ("`nBackup Vault") -ForegroundColor Blue
    $BackupVaults = Get-AzResource | ? {$_.ResourceType -eq "Microsoft.DataProtection/BackupVaults"}

    foreach ($BackupVault in $BackupVaults) {
        Write-Host $($BackupVault.Name)
        $BackupVaultInstance = Get-AzDataProtectionBackupVault -ResourceGroupName $BackupVault.ResourceGroupName -VaultName $BackupVault.Name
        $RedundancyConfig = $BackupVaultInstance.StorageSetting.Type
        
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $BackupVault.ResourceGroupName -Location $BackupVaultInstance.Location -InstanceName $BackupVaultInstance.Name -InstanceType "Backup Vault" -CurrentRedundancyType $RedundancyConfig -Remark ""
    }

    # Storage Account
    Write-Host ("`nStorage Account") -ForegroundColor Blue
    $StorageAccounts = Get-AzStorageAccount

    foreach ($StorageAccount in $StorageAccounts) {
        Write-Host $($StorageAccount.StorageAccountName)
        $RedundancyConfig = $StorageAccount.Sku.Name.Substring($StorageAccount.Sku.Name.IndexOf("_") + 1)
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $StorageAccount.ResourceGroupName -Location $StorageAccount.Location -InstanceName $StorageAccount.StorageAccountName -InstanceType "Storage Account" -CurrentRedundancyType $RedundancyConfig -Remark ""
    }
    
    # Api Management
    Write-Host ("`nApi Management") -ForegroundColor Blue
    $apims = Get-AzApiManagement

    foreach ($apim in $apims) {
        Write-Host $($apim.Name)
        $InstanceTypeDetail = ""
        $Location = $apim.Location # Primary Location
        $sku = $apim.Sku.ToString()

        if ($sku -in ("Premium", "Isolated")) {
            # Additional Region
            [array]$AdditionalRegions = $apim.AdditionalRegions

            if ($AdditionalRegions.Count -gt 0) {
                $RedundancyConfig = "Multi-Region"
                foreach ($AdditionalRegion in $AdditionalRegions) {
                    if ($InstanceTypeDetail -eq "") {
                        $InstanceTypeDetail = "Additional Region: " + $AdditionalRegion.Location
                    } else {
                        $InstanceTypeDetail += ", " + $AdditionalRegion.Location
                    }
                }
            } else {
                $RedundancyConfig = "Disabled"
                $InstanceTypeDetail = "No Multi-Region deployment Deployment"
            }
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $apim.ResourceGroupName -Location $apim.Location -InstanceName $apim.Name -InstanceType "Api Management" -CurrentRedundancyType $RedundancyConfig -Remark $InstanceTypeDetail
        } else {
            $RedundancyConfig = "Multi-Region not supported by current Sku"
            $InstanceTypeDetail = ""
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $apim.ResourceGroupName -Location $apim.Location -InstanceName $apim.Name -InstanceType "Api Management" -CurrentRedundancyType $RedundancyConfig -Remark $InstanceTypeDetail
        }
    }

    # Azure SQL Database
    Write-Host ("`nSQL Database") -ForegroundColor Blue
    $SqlServers = Get-AzSqlServer
	$Databases = $SqlServers | Get-AzSqlDatabase | ? {$_.DatabaseName -ne "Master" -and $_.SecondaryType -ne "Geo"}

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
        $InstanceTypeDetail = ""
        $FailoverGroups = Get-AzSqlDatabaseFailoverGroup -ResourceGroupName $Database.ResourceGroupName -ServerName $Database.ServerName
        $RedundancyConfig = "Disabled"
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
        $InstanceType = "Dedicated SQL pool Geo-Backup Policy"
        $InstanceTypeDetail = ""
        if ($Database.Edition -eq "DataWarehouse") {
            $Geo = Get-AzSqlDatabaseGeoBackupPolicy -ResourceGroupName $Database.ResourceGroupName -DatabaseName $Database.DatabaseName -ServerName $Database.ServerName
            $RedundancyConfig = $Geo.State.ToString()
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $Database.ResourceGroupName -Location $Database.Location -InstanceName $Database.DatabaseName -InstanceType $InstanceType -CurrentRedundancyType $RedundancyConfig -Remark $InstanceTypeDetail
        }
    }

    # Azure SQL Managed Instance
}

#Region Export
# Prepare Summary
foreach ($item in @("Recovery Services Vault", "Backup Vault", "Storage Account", "Api Management", "SQL Database Backup Storage Redundancy", "SQL Database Auto-Failover Group", "Dedicated SQL pool Geo-Backup Policy")) {
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
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Remark" -Value ($Global:RedundancySetting | ? {$_.InstanceType -eq $item.Name -and $_.CurrentRedundancyType -eq $type.Name} | select -First 1 | select -ExpandProperty Remark)
        $Global:RedundancySettingSummary += $obj
    }
}

# Export to Excel File
$Global:RedundancySettingSummary | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "Summary" -TableName "Summary" -TableStyle Medium16 -AutoSize -Append
$Global:RedundancySetting | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "InstanceDetail" -TableName "InstanceDetail" -TableStyle Medium16 -AutoSize -Append
#EndRegion Export

# End
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`nReplication and Resilience Assessment have been completed"
$Global:EndTime = Get-Date
$Duration = $Global:EndTime - $Global:StartTime
Write-Host ("`nTotal Process Time: " + $Duration.Hours + " Hours " + $Duration.Minutes + " Minutes " + $Duration.Seconds + " Seconds") -ForegroundColor Blue -BackgroundColor Black
Start-Sleep -Seconds 1
Write-Host ("`nAssessment Result is exported to " + $Global:ExcelFullPath)
Write-Host "`n"