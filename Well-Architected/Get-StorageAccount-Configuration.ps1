# Script Variable
$Global:StorageAccountSetting = @()
$Global:StorageAccountSettingSummary = @()
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
Write-Host "`nGet Storage Account Configuration" -ForegroundColor Cyan

foreach ($Subscription in $Global:Subscriptions) {
    Write-Host ("`n")
    Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
    
    # Set current subscription
	$AzContext = Set-AzContext -SubscriptionId $Subscription.Id
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Global:Subscriptions.Count + " Subscription: " + $Subscription.name) -ForegroundColor Yellow
    $CurrentItem++

    # Get Storage Account
    $StorageAccounts = Get-AzStorageAccount
    $pe = Get-AzPrivateEndpoint

    foreach ($StorageAccount in $StorageAccounts) {
        $Location = Rename-Location -Location $StorageAccount.Location 
        
        # SKU
        $sku = $StorageAccount.Sku.Name
        
        # Redundancy
        if ($sku -like "*ZRS*") {
            $CurrentRedundancyType = $sku.Substring($sku.IndexOf("_") + 1)
            $ZoneRedundant = "Y" 
        } else {
            $CurrentRedundancyType = $sku.Substring($sku.IndexOf("_") + 1)
            $ZoneRedundant = "N" 
        }

        # When allow blob public access is enabled, one is permitted to configure container ACLs to allow anonymous access to blobs within the storage account. 
        # When disabled, no anonymous access to blobs within the storage account is permitted, regardless of underlying ACL configurations
        if ($StorageAccount.AllowBlobPublicAccess -eq $true -or $StorageAccount.AllowBlobPublicAccess -eq $null) {
            $AllowBlobPublicAccess = "Y"
        } else {
            $AllowBlobPublicAccess = "N"
        }   
        
        # Prevent Shared Key authorization for an Azure Storage account
        if ($StorageAccount.AllowSharedKeyAccess -eq $true -or $StorageAccount.AllowSharedKeyAccess -eq $null) {
            $AllowSharedKeyAccess = "Y"
        } else {
            $AllowSharedKeyAccess = "N"
        }   

        # Public Network Access
        # Firewall Bypass is an exception for Enabled from selected virtual networks and IP addresses. Allowed Value: Logging, Metrics, AzureServices
        if ($StorageAccount.PublicNetworkAccess -eq "Enabled" -or $StorageAccount.PublicNetworkAccess -eq $null) {
            if ($StorageAccount.NetworkRuleSet.DefaultAction -eq "Allow") {
                # Allow All Network
                $PublicNetworkAccess = "Allow All Network"
                $FirewallBypass = "N/A"
            } elseif ($StorageAccount.NetworkRuleSet.DefaultAction -eq "Deny") {
                # Allow Selected virtual networks and IP addresses 
                $PublicNetworkAccess = "Allow Selected Network"
                $FirewallBypass = $StorageAccount.NetworkRuleSet.Bypass
            } else {
                $PublicNetworkAccess = "Unknown"
                $FirewallBypass = "Unknown"
            }
        } elseif ($StorageAccount.PublicNetworkAccess -eq "Disabled") {
            # Disabled Public network access
            $PublicNetworkAccess = "Disabled"
            $FirewallBypass = "Disabled"
        } else {
            $PublicNetworkAccess = "Unknown"
            $FirewallBypass = "Unknown"
        }

        # Private Endpoint
        $PrivateLinkResource = $pe | ? {$_.PrivateLinkServiceConnections.PrivateLinkServiceId -eq $StorageAccount.Id}
        if ($PrivateLinkResource.Length -gt 0 -and $PrivateLinkResource -ne $null) {
            $EnabledPrivateEndpoint = "Y"
        } else {
            $EnabledPrivateEndpoint = "N"
        }

        # Version 1
        if ($StorageAccount.kind -eq "Storage") {
            $remark = "Recommend to upgrade to General-purpose v2 storage account"
        } else {
            $remark = ""
        }

        # Save to Temp Object
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.Id
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $StorageAccount.ResourceGroupName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "InstanceName" -Value $StorageAccount.StorageAccountName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SKU" -Value $sku
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Type" -Value $StorageAccount.Kind
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Location
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "AccessTier" -Value $StorageAccount.AccessTier
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "RedundancyType" -Value $CurrentRedundancyType
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "AllowAnonymousAccess" -Value $AllowBlobPublicAccess
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "AllowSharedKeyAccess" -Value $AllowSharedKeyAccess
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ZoneRedundant" -Value $ZoneRedundant
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledPrivateEndpoint" -Value $EnabledPrivateEndpoint
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "PublicNetworkAccess" -Value $PublicNetworkAccess
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "FirewallBypass" -Value $FirewallBypass
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Remark" -Value $remark

        # Save to Array
        $Global:StorageAccountSetting += $obj
    }
}

#Region Export
if ($Global:StorageAccountSetting.Count -ne 0) {
    # Prepare Storage Account Summary
    $SettingStatus = $Global:StorageAccountSetting

    for ($i = 0; $i -lt 4; $i++) {
        switch ($i) {
            0 { 
                $CurrentSettingStatus = $SettingStatus | group ZoneRedundant | select Name, Count 
                $NetworkType = "Zone Redundant"
            }
            1 { 
                $CurrentSettingStatus = $SettingStatus | group AllowAnonymousAccess | select Name, Count 
                $NetworkType = "Allow anonymous access to blobs"
            }
            2 { 
                $CurrentSettingStatus = $SettingStatus | group EnabledPrivateEndpoint | select Name, Count 
                $NetworkType = "Private Endpoint"
            }
            3 { 
                $CurrentSettingStatus = $SettingStatus | group PublicNetworkAccess | select Name, Count 
                $NetworkType = "Type of Allowed Network Access"
            }
        }
        
        foreach ($item in $CurrentSettingStatus) {
            $obj = New-Object -TypeName PSobject
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Item" -Value $NetworkType
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Enabled" -Value $item.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Subtotal" -Value $item.Count
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Total" -Value $Global:StorageAccountSetting.Count
            $Global:StorageAccountSettingSummary += $obj
        }
    }

    # Export to Excel File
    $Global:StorageAccountSettingSummary | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "StorageAccountSummary" -TableName "StorageAccountSummary" -TableStyle Medium16 -AutoSize -Append
    $Global:StorageAccountSetting | sort SubscriptionName | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "StorageAccountDetail" -TableName "StorageAccountDetail" -TableStyle Medium16 -AutoSize -Append
} else {
    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value "Storage Account"
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Status" -Value "Resource is not found"
    $Global:StorageAccountSettingSummary += $obj
   
    # Export to Excel File
    $Global:StorageAccountSettingSummary | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "ResourceNotFound" -TableName "ResourceNotFound" -TableStyle Light11 -AutoSize -Append
}
#EndRegion Export