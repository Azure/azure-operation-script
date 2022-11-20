# Global Parameter
$CsvFullPath = "C:\Temp\AppServiceVNet.csv"

# Script Variable
$Global:AppServiceSetting = @()

# Main
$StartTime = Get-Date
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black

# Get App Service and App Service Plan
$AppServices = Get-AzWebApp | Sort-Object Name
$AppServicePlans = Get-AzAppServicePlan

foreach ($AppService in $AppServices) {
    $AppServiceName = $AppService.Name

    # App Service Plan Information
    $AppServicePlanName = $AppService.ServerFarmId.Substring($AppService.ServerFarmId.IndexOf("/serverfarms/") + "/serverfarms/".Length)
    $AppServicePlanRG = $AppService.ServerFarmId.Substring($AppService.ServerFarmId.IndexOf("/resourceGroups/") + "/resourceGroups/".Length)
    $AppServicePlanRG = $AppServicePlanRG.Substring(0, $AppServicePlanRG.IndexOf("/"))
    $AppServicePlanInstance = $AppServicePlans | ? {$_.ResourceGroup -eq $AppServicePlanRG -and $_.Name -eq $AppServicePlanName}
    $sku = ($AppServicePlanInstance.Sku.Name + ": " + $AppServicePlanInstance.Sku.Capacity + " Unit")

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

    # Save to Temp Object
    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "AppService" -Value $AppServiceName
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "AppServiceResourceGroup" -Value $AppService.ResourceGroup
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Type" -Value $AppService.Kind
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "AppServicePlan" -Value $AppServicePlanName
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "AppServicePlanResourceGroup" -Value $AppServicePlanRG
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "SKU" -Value $sku
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledVNetIntegration" -Value $EnabledVNetIntegration
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "VirtualNetworkId" -Value $VirtualNetworkId

    # Save to Array
    $Global:AppServiceSetting += $obj
}

$Global:AppServiceSetting | Export-Csv -Path $CsvFullPath -NoTypeInformation -Force -Confirm:$false

# End
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`nCompleted"
$EndTime = Get-Date
$Duration = $EndTime - $StartTime
Write-Host ("`nTotal Process Time: " + $Duration.Minutes + " Minutes " + $Duration.Seconds + " Seconds") -ForegroundColor White -BackgroundColor Black
Start-Sleep -Seconds 1
Write-Host "`n"