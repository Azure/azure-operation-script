# Global Parameter
$CsvFilePath = "./vnet-list.csv"

# Script Variable
$CurrentSubscription = ""
$vnets = Import-Csv $CsvFilePath
$vnets = $vnets | Sort-Object Subscription,ResourceGroup,VNetName

# Disable breaking change warning messages
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value "true"

#Region Resource Group
$rgs = $vnets | Select-Object -Unique ResourceGroup, Subscription, Location
Write-Host "`nProvision Resource Group ..." -ForegroundColor Cyan

foreach ($rg in $rgs) {
    # Set current subscription
    if ($CurrentSubscription -ne $rg.Subscription) {
        Write-Host ("Connecting to Subscription: " + $rg.Subscription.Trim())
        Set-AzContext -SubscriptionName $rg.Subscription.Trim() | Out-Null
        $CurrentSubscription = $rg.Subscription.Trim()
    }

    # Create Resource Group if not exist
    $IsExist = Get-AzResourceGroup -Name $rg.ResourceGroup -ErrorAction SilentlyContinue
    if ([string]::IsNullOrEmpty($IsExist)) {
        New-AzResourceGroup -Name $rg.ResourceGroup -Location $rg.Location | Out-Null
        Write-Host ($rg.ResourceGroup + " is created") 
    } else {
        Write-Host ($rg.ResourceGroup + " already exist") -ForegroundColor Yellow
    }
    Start-Sleep -Milliseconds 100
}
Start-Sleep -Seconds 5
#EndRegion Resource Group

#Region Virtual Network
Write-Host "`nProvision Virtual Network ..." -ForegroundColor Cyan

for ([int]$i = 0; $i -lt $vnets.Count; $i++) {
    # Set current subscription
    if ($CurrentSubscription -ne $vnets[$i].Subscription) {
        Write-Host ("Connecting to Subscription: " + $vnets[$i].Subscription)
        Set-AzContext -SubscriptionName $vnets[$i].Subscription | Out-Null
        $CurrentSubscription = $vnets[$i].Subscription
    }

    # Create Virtual Network if not exist
    $IsExist = Get-AzVirtualNetwork -ResourceGroupName $vnets[$i].ResourceGroup -Name $vnets[$i].VNetName -ErrorAction SilentlyContinue
    if ([string]::IsNullOrEmpty($IsExist)) {
        $subnet = New-AzVirtualNetworkSubnetConfig -Name $vnets[$i].SubnetName -AddressPrefix $vnets[$i].SubnetAddressSpace
        Start-Sleep -Milliseconds 100
        $NewAzVirtualNetwork = New-AzVirtualNetwork -ResourceGroupName $vnets[$i].ResourceGroup -Name $vnets[$i].VNetName -Location $vnets[$i].Location -AddressPrefix $vnets[$i].VNetAddressSpace -Subnet $subnet
        Write-Host ($vnets[$i].VNetName + " is created") 

        # Add Second and later Subnet
        $OtherSubnets = $vnets | ? {$_.VNetName -eq $vnets[$i].VNetName} | Select-Object -skip 1
        if (![string]::IsNullOrEmpty($OtherSubnets) -and $OtherSubnets.Count -gt 1) {
            foreach ($item in $OtherSubnets) {
                Add-AzVirtualNetworkSubnetConfig -VirtualNetwork $NewAzVirtualNetwork -Name $item.SubnetName -AddressPrefix $item.SubnetAddressSpace | Out-Null
                Write-Host ("Adding Subnet: " + $item.SubnetName)
                Start-Sleep -Milliseconds 100
            } 
            $NewAzVirtualNetwork | Set-AzVirtualNetwork | Out-Null
            $i += $OtherSubnets.Count
        }
    } else {
        Write-Host ($vnets[$i].VNetName + " already exist") -ForegroundColor Yellow
    }
    Start-Sleep -Milliseconds 100
}
#EndRegion Virtual Network