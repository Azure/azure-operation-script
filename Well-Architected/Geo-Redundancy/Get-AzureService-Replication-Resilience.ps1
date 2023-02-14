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
    $RecoveryServicesVaults = Get-AzRecoveryServicesVault

    foreach ($RecoveryServicesVault in $RecoveryServicesVaults) {
        Write-Host ("`nRecovery Services Vault") -ForegroundColor Blue
        Write-Host $($RecoveryServicesVault.Name)
        $BackupProperty = Get-AzRecoveryServicesBackupProperty -Vault $RecoveryServicesVault
        $RedundancyConfig = $BackupProperty.BackupStorageRedundancy
        $CrossRegionRestore = $BackupProperty.CrossRegionRestore

        # Add Cross-Region Restore setting to Remark
        if ($CrossRegionRestore -and $RedundancyConfig -like "*Geo*") {
            $Remark = "Cross-Region Restore is enabled"
        } else {
            $Remark = "Cross-Region Restore is disabled"
        }
 
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $RecoveryServicesVault.ResourceGroupName -Location $RecoveryServicesVault.Location -InstanceName $RecoveryServicesVault.Name -InstanceType "Recovery Services Vault" -CurrentRedundancyType $RedundancyConfig -Remark $Remark
    }

    # Backup Vault
    $BackupVaults = Get-AzResource | ? {$_.ResourceType -eq "Microsoft.DataProtection/BackupVaults"} 
    foreach ($BackupVault in $BackupVaults) {
        Write-Host ("`nBackup Vault") -ForegroundColor Blue
        Write-Host $($BackupVault.Name)
        $BackupVaultInstance = Get-AzDataProtectionBackupVault -ResourceGroupName $BackupVault.ResourceGroupName -VaultName $BackupVault.Name
        $RedundancyConfig = $BackupVaultInstance.StorageSetting.Type
        
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $BackupVault.ResourceGroupName -Location $BackupVaultInstance.Location -InstanceName $BackupVaultInstance.Name -InstanceType "Backup Vault" -CurrentRedundancyType $RedundancyConfig -Remark ""
    }


    # Storage Account


    # Api Management
}

#Region Export
foreach ($item in ($Global:RedundancySetting | group InstanceType | select Name, Count)) {
    if ($item.Count -eq 0) {
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "InstanceType" -Value $item.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "RedundancyType" -Value "N/A"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Count" -Value "N/A"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Remark" -Value "Resource Not Found"
        $Global:RedundancySettingSummary += $obj
    } else {
        $RedundancyType = $Global:RedundancySetting | ? {$_.InstanceType -eq $item.Name} | group CurrentRedundancyType | select Name, Count
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "InstanceType" -Value $item.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "RedundancyType" -Value $RedundancyType.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Count" -Value $RedundancyType.Count
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Remark" -Value ""
        $Global:RedundancySettingSummary += $obj
    }
}

# Export to Excel File
$Global:RedundancySettingSummary | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "Summary" -TableName "Summary" -TableStyle Medium16 -AutoSize -Append
#EndRegion Export