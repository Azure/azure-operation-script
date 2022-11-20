# Global Parameter
$RTCsvFilePath = "./vnet-rt.csv"

# Script Variable
$CurrentSubscription = ""
$rts = Import-Csv $RTCsvFilePath
$rts = $rts | Sort-Object RTSubscription, RTResourceGroup, RTName, AddressPrefix

# Disable breaking change warning messages
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value "true"

#Region Route Table
Write-Host "`nProvision Route Table ..." -ForegroundColor Cyan

for ([int]$i = 0; $i -lt $rts.Count; $i++) {
    # Set current subscription
    if ($CurrentSubscription -ne $rts[$i].RTSubscription) {
        Write-Host ("Connecting to Subscription: " + $rts[$i].RTSubscription)
        Set-AzContext -SubscriptionName $rts[$i].RTSubscription | Out-Null
        $CurrentSubscription = $rts[$i].RTSubscription
    }

    # Create Route Table
    if ($rts[$i].BgpRoutePropagation -eq "Y") {
        New-AzRouteTable -ResourceGroupName $rts[$i].RTResourceGroup -Name $rts[$i].RTName -Location $rts[$i].Location | Out-Null
    } else {
        New-AzRouteTable -ResourceGroupName $rts[$i].RTResourceGroup -Name $rts[$i].RTName -Location $rts[$i].Location -DisableBgpRoutePropagation | Out-Null
    }
    Start-Sleep -Milliseconds 500
    Write-Host ($rts[$i].RTName + " is created") 

    # Add Route
    $OtherRoutes = $rts | ? {$_.RTResourceGroup -eq $rts[$i].RTResourceGroup -and $_.RTName -eq $rts[$i].RTName}
    if (![string]::IsNullOrEmpty($OtherRoutes) -and $OtherRoutes.Count -gt 0) {
        $RouteTable = Get-AzRouteTable -ResourceGroupName $rts[$i].RTResourceGroup -Name $rts[$i].RTName
        foreach ($item in $OtherRoutes) {
            Add-AzRouteConfig -Name ($item.AddressPrefix -replace "/","_") -AddressPrefix $item.AddressPrefix -NextHopType $item.NextHopType -NextHopIpAddress $item.NextHopIpAddress -RouteTable $RouteTable -Confirm:$false | Out-Null
            Write-Host ("Adding Route: " + $item.AddressPrefix)
            Start-Sleep -Milliseconds 100
        } 
        $RouteTable | Set-AzRouteTable | Out-Null
        $i += ($OtherRoutes.Count - 1)
    }
}
#EndRegion Route Table