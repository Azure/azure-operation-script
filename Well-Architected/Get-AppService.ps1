# Script Variable
$Global:AppServiceSetting = @()
$Global:AppServiceSettingSummary = @()
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
Write-Host "`nGet App Service Configuration" -ForegroundColor Cyan

foreach ($Subscription in $Global:Subscriptions) {
    Write-Host ("`n")
    Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
    
    # Set current subscription
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id -TenantId $Subscription.TenantId
    az account set --subscription $Subscription.Id
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Global:Subscriptions.Count + " Subscription: " + $Subscription.name) -ForegroundColor Yellow
    $CurrentItem++

    # Get App Service and App Service Plan
    # Include Function App
    $AppServices = Get-AzWebApp | sort Name
    $AppServicePlans = Get-AzAppServicePlan
    $pe = Get-AzPrivateEndpoint

    foreach ($AppService in $AppServices) {
        $Location = Rename-Location -Location $AppService.location
        $AppServiceName = $AppService.Name

        # App Service Plan
        $AppServicePlanName = $AppService.ServerFarmId.Substring($AppService.ServerFarmId.IndexOf("/serverfarms/") + "/serverfarms/".Length)
        $AppServicePlanRG = $AppService.ServerFarmId.Substring($AppService.ServerFarmId.IndexOf("/resourceGroups/") + "/resourceGroups/".Length)
        $AppServicePlanRG = $AppServicePlanRG.Substring(0, $AppServicePlanRG.IndexOf("/"))
        $AppServicePlanInstance = $AppServicePlans | ? {$_.ResourceGroup -eq $AppServicePlanRG -and $_.Name -eq $AppServicePlanName}
        $sku = ($AppServicePlanInstance.Sku.Name + ": " + $AppServicePlanInstance.Sku.Capacity + " Unit")

        # Zone Redundant (Not Supported by Az Module and Azure CLI)
        $CurrentAppServicePlan = az appservice plan list --resource-group $AppServicePlanRG --query "[?name=='$AppServicePlanName']" | ConvertFrom-Json
        if ($CurrentAppServicePlan.zoneRedundant) {
            $ZoneRedundant = "Y"
        } else {
            $ZoneRedundant = "N"
        }

        # VNet Integration
        $WebAppvNetIntegration = az webapp vnet-integration list --resource-group $AppService.ResourceGroup --name $AppService.Name

        if ($WebAppvNetIntegration -eq "[]") {
            $EnabledVNetIntegration = "N"
            $VirtualNetworkId = "N/A"
        } else {
            $vNetInfo = $WebAppvNetIntegration | ConvertFrom-Json
            $EnabledVNetIntegration = "Y"
            $VirtualNetworkId = $vNetInfo.vnetResourceId
        }

        # Private Endpoint
        $PrivateLinkResource = $pe | ? {$_.PrivateLinkServiceConnections.PrivateLinkServiceId -eq $AppService.Id}
        if ($PrivateLinkResource.Length -gt 0 -and $PrivateLinkResource -ne $null) {
            $EnabledPrivateEndpoint = "Y"
        } else {
            $EnabledPrivateEndpoint = "N"
        }

        # Save to Temp Object
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.Id
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "AppService" -Value $AppServiceName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "AppServiceResourceGroup" -Value $AppService.ResourceGroup
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Type" -Value $AppService.Kind
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Location
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "AppServicePlan" -Value $AppServicePlanName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "AppServicePlanResourceGroup" -Value $AppServicePlanRG
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SKU" -Value $sku
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ZoneRedundant" -Value $ZoneRedundant
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledPrivateEndpoint" -Value $EnabledPrivateEndpoint
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledVNetIntegration" -Value $EnabledVNetIntegration
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "VirtualNetworkId" -Value $VirtualNetworkId
    
        # Save to Array
        $Global:AppServiceSetting += $obj
    }
}

#Region Export
if ($Global:AppServiceSetting.Count -ne 0) {
    # Prepare App Service Setting Summary
    $SettingStatus = $Global:AppServiceSetting

    for ($i = 0; $i -lt 3; $i++) {
        switch ($i) {
            0 { 
                $CurrentSettingStatus = $SettingStatus | group ZoneRedundant | select Name, Count 
                $NetworkType = "Zone Redundant"
            }
            1 { 
                $CurrentSettingStatus = $SettingStatus | group EnabledVNetIntegration | select Name, Count 
                $NetworkType = "VNet Integration"
            }
            2 { 
                $CurrentSettingStatus = $SettingStatus | group EnabledPrivateEndpoint | select Name, Count 
                $NetworkType = "Private Endpoint"
            }
        }
        
        foreach ($item in $CurrentSettingStatus) {
            $obj = New-Object -TypeName PSobject
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Item" -Value $NetworkType
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Enabled" -Value $item.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Subtotal" -Value $item.Count
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Total" -Value $Global:AppServiceSetting.Count
            $Global:AppServiceSettingSummary += $obj
        }
    }

    # Export to Excel File
    $Global:AppServiceSettingSummary | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "AppServiceSummary" -TableName "AppServiceSummary" -TableStyle Medium16 -AutoSize -Append
    $Global:AppServiceSetting | sort SubscriptionName | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "AppServiceDetail" -TableName "AppServiceDetail" -TableStyle Medium16 -AutoSize -Append
} else {
    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value "Azure App Service"
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Status" -Value "Resource is not found"
    $Global:AppServiceSettingSummary += $obj
   
    # Export to Excel File
    $Global:AppServiceSettingSummary | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "ResourceNotFound" -TableName "ResourceNotFound" -TableStyle Light11 -AutoSize -Append
}
#EndRegion Export