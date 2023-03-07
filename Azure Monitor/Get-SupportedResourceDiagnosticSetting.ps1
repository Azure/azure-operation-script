# Global Parameter
$TenantIds = @("")
$CurrentExportPath = "C:\Temp\DiagnosticSetting.csv"

# Script Variable
$Global:Subscriptions = @()
$Global:CurrentDiagnosticSetting = @()
[int]$CurrentItem = 1
$ErrorActionPreference = "Continue"

function Add-Record {
    param (
        $SubscriptionName,
        $SubscriptionId,
        $ResourceGroup,
        $ResourceName,
        $ResourceType,
        $Location,
        $EnabledDiagnostic,
        $WorkspaceId,
        $StorageAccountId,
        $ServiceBusRuleId,
        $EventHubAuthorizationRuleId
    )

    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $SubscriptionName
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $SubscriptionId
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $ResourceGroup
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceName" -Value $ResourceName
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value $ResourceType
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Location
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledDiagnostic" -Value $EnabledDiagnostic
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "WorkspaceId" -Value $WorkspaceId
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "StorageAccountId" -Value $StorageAccountId
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ServiceBusRuleId" -Value $ServiceBusRuleId
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "EventHubAuthorizationRuleId" -Value $EventHubAuthorizationRuleId
    $Global:CurrentDiagnosticSetting += $obj
}

function Clear-UnsupportedResourceType {
    param (
        $AzResources
    )

    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.AlertsManagement/actionRules"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.alertsmanagement/smartDetectorAlertRules"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Automation/automationAccounts/runbooks"} # Support Automation Accounts only
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.AzureActiveDirectory/b2cDirectories"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.cdn/profiles"} # Support Endpoint only
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Compute/availabilitySets"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Compute/cloudServices"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Compute/disks"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Compute/images"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Compute/galleries"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Compute/galleries/images"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Compute/galleries/images/versions"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Compute/restorePointCollections"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Compute/snapshots"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Compute/sshPublicKeys"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Compute/virtualMachines/extensions"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Compute/virtualMachineScaleSets"} # Enabling Azure Monitors for VMSS
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.ContainerRegistry/registries/replications"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.ContainerRegistry/registries/webhooks"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.ContainerInstance/containerGroups"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.DataCatalog/catalogs"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.DevTestLab/schedules"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.MarketplaceApps/classicDevServices"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.insights/actiongroups"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.insights/activityLogAlerts"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.insights/autoscalesettings"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.insights/components"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Insights/dataCollectionRules"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.insights/metricalerts"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.insights/webtests"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.insights/scheduledqueryrules"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.insights/workbooks"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.LabServices/labaccounts"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Logic/integrationServiceEnvironments"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Logic/integrationServiceEnvironments/managedApis"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.ManagedIdentity/userAssignedIdentities"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Migrate/moveCollections"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/applicationGatewayWebApplicationFirewallPolicies"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/frontdoorWebApplicationFirewallPolicies"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/applicationSecurityGroups"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/connections"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/ddosProtectionPlans"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/firewallPolicies"} # Firewall Instance support Diagnostic settings
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/ipGroups"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/localNetworkGateways"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/serviceEndpointPolicies"} # Not support Diagnostic settings, but support Tagging
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/networkIntentPolicies"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/networkWatchers"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/networkWatchers/connectionMonitors"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.network/networkWatchers/flowLogs"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/privateDnsZones"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/privateDnsZones/virtualNetworkLinks"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/privateEndpoints"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/publicIPPrefixes"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/routeFilters"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/routeTables"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/virtualHubs"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/virtualWans"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.NotificationHubs/namespaces/notificationHubs"} # Support Namespace only
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.OperationsManagement/solutions"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Portal/dashboards"} # Shared Dashboard not support
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.ResourceGraph/queries"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.SaaS/resources"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Scheduler/jobcollections"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.security/automations"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Security/iotSecuritySolutions"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.StreamAnalytics/clusters"} # Microsoft.StreamAnalytics/streamingjobs support
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Sql/servers"} # Support Database only
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Sql/servers/jobAgents"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Sql/virtualClusters"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.SqlVirtualMachine/SqlVirtualMachines"} # Configure at Virtual Machine
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.StorageSync/storageSyncServices"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.visualstudio/account"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Web/connectionGateways"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Web/certificates"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Web/connections"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Web/staticSites"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Sendgrid.Email/accounts"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.DataProtection/BackupVaults"} # Backup Vault not support, but Recovery Service vault support
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.DataMigration/services"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.DataMigration/services/projects"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.MachineLearning/commitmentPlans"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.MachineLearning/Workspaces"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Migrate/assessmentProjects"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Migrate/migrateprojects"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.offazure/ImportSites"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.OffAzure/MasterSites"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.OffAzure/VMwareSites"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.ResourceGraph/queries"}
    $AzResources = $AzResources | ? {$_.ResourceType -notlike "*Classic*"}
    $AzResources = $AzResources | ? {$_.ResourceType -notlike "*/webhooks"}

    $FilteredAzResources = @()
    foreach ($item in $AzResources) {
        # Exclude Master Database
        if ($item.ResourceType -eq "Microsoft.Sql/servers/databases") {
            if ($item.ResourceName -notlike "*/master") {
                $FilteredAzResources += $item
            }
        } else {
            $FilteredAzResources += $item
        }
    }
    
    return $FilteredAzResources
}

# Login and get list of subscription(s)
foreach ($TenantId in $TenantIds) {
    Connect-AzAccount -TenantId $TenantId
    $Global:Subscriptions += Get-AzSubscription -TenantId $TenantId | ? {$_.State -eq "Enabled" -and $_.Name -ne "Access to Azure Active Directory"} 
    Start-Sleep -Seconds 2
}
$Global:Subscriptions = $Global:Subscriptions | Sort-Object TenantId, Name

# Main
foreach ($Subscription in $Global:Subscriptions) {
    Write-Host ("`n")
    Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
    
    # Set current subscription
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id -TenantId $Subscription.TenantId
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Global:Subscriptions.Count + " Subscription: " + $Subscription.Name) -ForegroundColor Yellow
    $CurrentItem++

    # Get Azure Resources
    $list = Get-AzResource | ? {$_.ResourceGroupName -notlike "databricks-rg*"} # Add filter $_.ResourceType to focus on specific resource type

    # Filter Azure Resources that support Diagnostic Settings
    $list = Clear-UnsupportedResourceType -AzResources $list

    foreach ($item in $list) {
        $TempDiagnosticSettings = Get-AzDiagnosticSetting -ResourceId $item.Id

        if ($TempDiagnosticSettings -eq $null) {
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $item.ResourceGroupName -ResourceName $item.ResourceName -ResourceType $item.ResourceType -Location $item.Location `
            -EnabledDiagnostic "N" -WorkspaceId "N/A" -StorageAccountId "N/A" -ServiceBusRuleId "N/A" -EventHubAuthorizationRuleId "N/A"
        } else {
            foreach ($TempDiagnosticSetting in $TempDiagnosticSettings) {
                Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $item.ResourceGroupName -ResourceName $item.ResourceName -ResourceType $item.ResourceType -Location $item.Location `
                -EnabledDiagnostic "Y" -WorkspaceId $TempDiagnosticSetting.WorkspaceId -StorageAccountId $TempDiagnosticSetting.StorageAccountId -ServiceBusRuleId $TempDiagnosticSetting.ServiceBusRuleId -EventHubAuthorizationRuleId $TempDiagnosticSetting.EventHubAuthorizationRuleId
            }
        }
    }
}

# Export
$Global:CurrentDiagnosticSetting | Sort-Object ResourceType, ResourceGroup, ResourceName | Export-Csv -Path $CurrentExportPath -NoTypeInformation -Force -Confirm:$false

# End
Write-Host "`nCompleted"