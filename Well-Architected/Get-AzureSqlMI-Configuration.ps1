# Script Variable
$Global:SqlSetting = @()
$Global:SqlSettingSummary = @()
$Global:SqlAccessSummary = @()
[int]$CurrentItem = 1
$ErrorActionPreference = "Continue"

# Function to align the Display Name
function Rename-Location {
    param (
        [string]$Location
    )

    foreach ($item in $Global:NameReference) {
        if ($item.Location -eq $Location) {
            $Location = $item.DisplayName
        }
    }

    return $Location
}

# Disable breaking change warning messages
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value "true"

# Module
Import-Module ImportExcel

# Main
Write-Host ("`n" + "=" * 100)
Write-Host "`nGet Azure SQL Managed Instance Configuration" -ForegroundColor Cyan

foreach ($Subscription in $Global:Subscriptions) {
    Write-Host ("`n")
    Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
    
    # Set current subscription
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Global:Subscriptions.Count + " Subscription: " + $Subscription.name) -ForegroundColor Yellow
    $CurrentItem++

    #Region Azure SQL Managed Instance
	$SqlServers = Get-AzSqlInstance

    foreach ($SqlServer in $SqlServers) {
        Write-Host ("SQL Managed Instance: " + $SqlServer.ManagedInstanceName)

        # Pricing Tier
        $Edition = $SqlServer.Sku.Tier
        $sku = $SqlServer.Sku.Name
        $vCore = $SqlServer.VCores
        
        # Failover Group
        $FailoverGroups = Get-AzSqlDatabaseInstanceFailoverGroup -ResourceGroupName $SqlServer.ResourceGroupName -Location $SqlServer.Location
        $FailoverGroupEnabled = "N"
        $FailoverGroupName = "N/A"
        if (![string]::IsNullOrEmpty($FailoverGroups)) {
            foreach ($FailoverGroup in $FailoverGroups) {
                if ($FailoverGroup.PrimaryManagedInstanceName -eq $SqlServer.ManagedInstanceName -or $FailoverGroup.PartnerManagedInstanceName -eq $SqlServer.ManagedInstanceName) {
                    $FailoverGroupEnabled = "Y"
                    $FailoverGroupName = $FailoverGroup.Name
                }
            }
        }

        # Backup Storage Redundancy
        if ([string]::IsNullOrEmpty($SqlServer.BackupStorageRedundancy)) {
            $BackupStorageRedundancy = "N/A"
        } else {
            $BackupStorageRedundancy = $SqlServer.BackupStorageRedundancy
        }

        # Availability Zone 
        $ZoneRedundant = $SqlServer.ZoneRedundant
        if ($ZoneRedundant) {
            $ZoneRedundant = "Y"
        } else {
            $ZoneRedundant = "N"
        }

        # Private Endpoint
        $PrivateLinkResource = $pe | ? {$_.PrivateLinkServiceConnections.PrivateLinkServiceId -eq $SqlServer.ResourceId}
        if ($PrivateLinkResource.Length -gt 0 -and $PrivateLinkResource -ne $null) {
            $EnabledPrivateEndpoint = "Y"
        } else {
            $EnabledPrivateEndpoint = "N"
        }

        # Public Endpoint
        if ($SqlServer.PublicDataEndpointEnabled) {
            $EnabledPublicEndpoint = "Y"
        } else {
            $EnabledPublicEndpoint = "N"
        }

        # SQL Managed Instance Database
        $Databases = Get-AzSqlInstanceDatabase -InstanceResourceId $SqlServer.Id | ? {$_.Name -ne "Master"}

        foreach ($Database in $Databases) {
            Write-Host ("SQL Managed Instance Database: " + $Database.Name)
            $Location = Rename-Location -Location $Database.Location

            # Backup Policy
            $ShortTerm = Get-AzSqlInstanceDatabaseBackupShortTermRetentionPolicy  -ResourceGroupName $Database.ResourceGroupName -InstanceName $Database.ManagedInstanceName -DatabaseName $Database.Name
            $LongTerm = Get-AzSqlInstanceDatabaseBackupLongTermRetentionPolicy -ResourceGroupName $Database.ResourceGroupName -InstanceName $Database.ManagedInstanceName -DatabaseName $Database.Name

            # Long Term Retention
            if ($LongTerm.WeeklyRetention -eq "PT0S") {
                $WeeklyRetention = "Not Enabled"
            } else {
                $WeeklyRetention = $LongTerm.WeeklyRetention
            }

            if ($LongTerm.MonthlyRetention -eq "PT0S") {
                $MonthlyRetention = "Not Enabled"
            } else {
                $MonthlyRetention = $LongTerm.MonthlyRetention
            }

            if ($LongTerm.YearlyRetention -eq "PT0S") {
                $YearlyRetention = "Not Enabled"
            } else {
                $YearlyRetention = $LongTerm.YearlyRetention
            }
            
            # SQL Managed Instance Storage space reserved
            #$MI_Metric_Storage = Get-AzMetric -ResourceId $SqlServer.Id -MetricName 'reserved_storage_mb' -WarningAction SilentlyContinue
            #[int]$MI_ReservedSpace = $MI_Metric_Storage.Data.Average | select -Last 1
            #$MI_ReservedSpace = [math]::Round($MI_ReservedSpace / 1KB, 2)
            $MI_ReservedSpace = $SqlServer.StorageSizeInGB

            # SQL Managed Instance Storage space used
            $MI_Metric_Storage = Get-AzMetric -ResourceId $SqlServer.Id -MetricName 'storage_space_used_mb' -WarningAction SilentlyContinue
            [int]$MI_UsedSpace = $MI_Metric_Storage.Data.Average | select -Last 1
            $MI_UsedSpace = [math]::Round($MI_UsedSpace / 1KB, 2)

            # Save to Temp Object
            $obj = New-Object -TypeName PSobject
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $Database.ResourceGroupName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ServerName" -Value $Database.ManagedInstanceName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "DatabaseName" -Value $Database.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value "SQL Managed Instance Database"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Edition" -Value $Edition
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SKU" -Value $sku
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "vCore" -Value $vCore
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "FailoverGroupEnabled" -Value $FailoverGroupEnabled
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "FailoverGroupName" -Value $FailoverGroupName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "BackupStorageRedundancy" -Value $BackupStorageRedundancy
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ZoneRedundant" -Value $ZoneRedundant
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledPrivateEndpoint" -Value $EnabledPrivateEndpoint
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledPublicEndpoint" -Value $EnabledPublicEndpoint
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Location
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "PITR(Day)" -Value $ShortTerm.RetentionDays
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "WeeklyRetention" -Value $WeeklyRetention
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "MonthlyRetention" -Value $MonthlyRetention
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "YearlyRetention" -Value $YearlyRetention
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ServerReservedSize(GB)"  -Value $MI_ReservedSpace
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ServerUsedSize(GB)"  -Value $MI_UsedSpace
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "DBCreationDate" -Value $Database.CreationDate
            $Global:SqlSetting += $obj
        }
    }
    #EndRegion Azure SQL Managed Instance
}

#Region Export
if ($Global:SqlSetting.Count -ne 0) {

    # Backup Status Summary 
    for ($i = 0; $i -lt 4; $i++) {
        switch ($i) {
            0 { 
                $CurrentSettingStatus = $Global:SqlSetting | group ResourceType, "PITR(Day)" | select Name, Count 
                $RetentionType = "Point-in-time restore (PITR)"
            }
            1 { 
                $CurrentSettingStatus = $Global:SqlSetting | group ResourceType, WeeklyRetention | select Name, Count 
                $RetentionType = "Long-term retention (Weekly)"
            }
            2 { 
                $CurrentSettingStatus = $Global:SqlSetting | group ResourceType, MonthlyRetention | select Name, Count 
                $RetentionType = "Long-term retention (Monthly)"
            }
            3 { 
                $CurrentSettingStatus = $Global:SqlSetting | group ResourceType, YearlyRetention | select Name, Count 
                $RetentionType = "Long-term retention (Yearly)"
            }
        }

        foreach ($item in $CurrentSettingStatus) {
            $ResourceType = $item.Name.Substring(0, $item.Name.IndexOf(","))
            $Retention = $item.Name.Substring($item.Name.IndexOf(",") + 1)
            $ResourceTotal = $Global:SqlSetting | group ResourceType | ? {$_.Name -eq $ResourceType} | select -ExpandProperty Count

            $obj = New-Object -TypeName PSobject
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value $ResourceType
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "RetentionType" -Value $RetentionType
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Retention" -Value $Retention
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Subtotal" -Value $item.Count
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Total" -Value $ResourceTotal
            $Global:SqlSettingSummary += $obj
        }
    }

    # Access Summary
    # Zone Redundant per SQL Managed Instance
    $ZoneRedundantSetting = $Global:SqlSetting | ? {$_.ResourceType -eq "SQL Managed Instance Database"} | select -Unique SubscriptionName, ServerName, ZoneRedundant
    
    # Private Endpoint per SQL Managed Instance
    $PrivateEndpointSetting = $Global:SqlSetting | select -Unique SubscriptionName, ServerName, EnabledPrivateEndpoint

    # Per SQL Managed Instance
    $SqlMISetting = $Global:SqlSetting | ? {$_.ResourceType -eq "SQL Managed Instance Database"} | select -Unique SubscriptionName, ServerName, EnabledPublicEndpoint

    $CurrentSettingStatus = $ZoneRedundantSetting | group ZoneRedundant | select Name, Count 
    foreach ($item in $CurrentSettingStatus) {
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Item" -Value "ZoneRedundant"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Enabled" -Value $item.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Subtotal" -Value $item.Count
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Total" -Value $ZoneRedundantSetting.Count
        $Global:SqlAccessSummary += $obj
    }

    $CurrentSettingStatus = $PrivateEndpointSetting | group EnabledPrivateEndpoint | select Name, Count 
    foreach ($item in $CurrentSettingStatus) {
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Item" -Value "EnabledPrivateEndpoint"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Enabled" -Value $item.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Subtotal" -Value $item.Count
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Total" -Value $PrivateEndpointSetting.Count
        $Global:SqlAccessSummary += $obj
    }

    $CurrentSettingStatus = $SqlMISetting | group EnabledPublicEndpoint | select Name, Count 
    foreach ($item in $CurrentSettingStatus) {
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Item" -Value "EnabledPublicEndpoint"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Enabled" -Value $item.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Subtotal" -Value $item.Count
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Total" -Value $SqlMISetting.Count
        $Global:SqlAccessSummary += $obj
    }

    # Export to Excel File
    $Global:SqlSettingSummary | sort ResourceType, RetentionType | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "SqlMI_BackupSummary" -TableName "SqlMI_BackupSummary" -TableStyle Medium16 -AutoSize -Append
    $Global:SqlAccessSummary | sort ResourceType, RetentionType | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "SqlMI_Summary" -TableName "SqlMI_Summary" -TableStyle Medium16 -AutoSize -Append
    $Global:SqlSetting | sort ResourceType, SubscriptionName, DatabaseName | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "SqlMI_Detail" -TableName "SqlMI_Detail" -TableStyle Medium16 -AutoSize -Append
} else {
    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value "Azure SQL Managed Instance"
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Status" -Value "Resource is not found"
    $Global:SqlSettingSummary += $obj

    # Export to Excel File
    $Global:SqlSettingSummary | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "ResourceNotFound" -TableName "ResourceNotFound" -TableStyle Light11 -AutoSize -Append
}
#EndRegion Export