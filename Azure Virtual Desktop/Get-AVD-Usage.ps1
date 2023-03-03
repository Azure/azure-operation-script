# Global Parameter
$TenantIds = @("")
$ExcelOutputFolder = "C:\Temp"
$ExcelFileName = "AVD-Usage.xlsx" # Export Result to Excel file 

# Script Variable
if ($ExcelOutputFolder -notlike "*\") {$ExcelOutputFolder += "\"}
$Global:ExcelFullPath = $ExcelOutputFolder + $ExcelFileName
$Global:ScalingPlanAssignment = @()
$Global:HostPools = @()
$Global:HostPoolsSummary = @()
$Global:SessionHosts = @()
$Global:SessionHostsSummary = @()
$Global:VmSizeSummary = @()
$Global:Message = @()
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

# Login and get list of subscription(s)
$Global:Subscriptions = @()
foreach ($TenantId in $TenantIds) {
    Connect-AzAccount -TenantId $TenantId
    $Global:Subscriptions += Get-AzSubscription -TenantId $TenantId | ? {$_.Name -like "*AVD*"} # Retrieve specific subscription(s) where AVD exists
    Start-Sleep -Seconds 2
}
$Global:Subscriptions = $Global:Subscriptions | Sort-Object TenantId, Name

# Disable breaking change warning messages
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value "true"

# Module
Import-Module ImportExcel

# Get the Latest Location Name, Display Name, and Paired Region
$Global:NameReference = Get-AzLocation | ? {$_.RegionType -eq "Physical" -and $_.DisplayName -notlike "*EUAP*"} | Sort-Object GeographyGroup, DisplayName

# Main
$Global:StartTime = Get-Date
Write-Host ("`n" + "=" * 70)
Write-Host "`nCollect the utilization of AVD Host Pool, Scaling Plan Assignment, list of Session Host including Power / Update Status" -ForegroundColor Cyan

# Get Azure VM Sku
$VmSku = Get-AzVMSize -Location "East Asia"

# Get Scaling Plan
foreach ($Subscription in $Global:Subscriptions) {
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id -TenantId $Subscription.TenantId
    $ScalingPlans = Get-AzWvdScalingPlan

    foreach ($ScalingPlan in $ScalingPlans) {
        if ($ScalingPlan.HostPoolReference.Count -gt 0) {
            foreach ($Assignment in $ScalingPlan.HostPoolReference) {
                $obj = New-Object -TypeName PSobject
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "ScalingPlan" -Value $ScalingPlan.Name

                if ($ScalingPlan.Schedule.Name.Count -eq 1) {
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ScheduleName" -Value $ScalingPlan.Schedule.Name
                } else {
                    [string]$st = $ScalingPlan.Schedule.Name -join("; ")
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ScheduleName" -Value ($st)
                }

                Add-Member -InputObject $obj -MemberType NoteProperty -Name "IsEnabled" -Value $Assignment.ScalingPlanEnabled
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "AssignedHostPool" -Value $Assignment.HostPoolArmPath.Split("/")[-1]
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "AssignedHostPoolResourceId" -Value $Assignment.HostPoolArmPath
                $Global:ScalingPlanAssignment += $obj
            }
        } else {
            $obj = New-Object -TypeName PSobject
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ScalingPlan" -Value $ScalingPlan.Name

            if ($ScalingPlan.Schedule.Name.Count -eq 1) {
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "ScheduleName" -Value $ScalingPlan.Schedule.Name
            } else {
                [string]$st = $ScalingPlan.Schedule.Name -join("; ")
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "ScheduleName" -Value ($st)
            }

            Add-Member -InputObject $obj -MemberType NoteProperty -Name "IsEnabled" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "AssignedHostPool" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "AssignedHostPoolResourceId" -Value "N/A"
            $Global:ScalingPlanAssignment += $obj
        }
    }
}

# Collection Information
foreach ($Subscription in $Global:Subscriptions) {
    Write-Host ("`n")
    Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
    
    # Set current subscription
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id -TenantId $Subscription.TenantId
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Global:Subscriptions.Count + " Subscription: " + $Subscription.name) -ForegroundColor Yellow
    $CurrentItem++

    # Get Host Pool
    $SubscriptionSessionHosts = @()
    $SubscriptionVmSizeSummary = @()
    $CurrentHostPools = Get-AzWvdHostPool
    $Global:HostPools += $CurrentHostPools

    # Get Session Host of each Host Pool
    foreach ($CurrentHostPool in $CurrentHostPools) {
        # Re-apply current subscription context
        $AzContext = Set-AzContext -SubscriptionId $Subscription.Id -TenantId $Subscription.TenantId
        $CurrentSubscriptionId = $Subscription.Id
        $AvsRG = $CurrentHostPool.Id.Substring($CurrentHostPool.Id.IndexOf("/resourcegroups/") + 16)
        $AvsRG = $AvsRG.Substring(0, $AvsRG.IndexOf("/providers/Microsoft.DesktopVirtualization/"))
        $CurrentSessionHosts = Get-AzWvdSessionHost -ResourceGroupName $AvsRG -HostPoolName $CurrentHostPool.Name
        $SubscriptionSessionHosts += $CurrentSessionHosts
        Start-Sleep -Seconds 1

        if ($CurrentSessionHosts.Count -gt 0) {
            # Get Session Host VM Size
            try {
                $ExistingHostName = $CurrentSessionHosts[-1].Id.Split("/")[-1]
                $VmSubscriptionId = $CurrentSessionHosts[-1].ResourceId.Split("/")[2]
                
                if ($VmSubscriptionId -ne $CurrentSubscriptionId) {
                    $CurrentSubscriptionId = $VmSubscriptionId
                    $AzContext = Set-AzContext -SubscriptionId $VmSubscriptionId -TenantId $Subscription.TenantId
                }

                $currentVmInfo = Get-AzVM -ResourceGroupName $CurrentSessionHosts[-1].ResourceId.Split("/")[4] -Name $ExistingHostName.Split(".")[0]
                [string]$CurrentVmSize = $CurrentVmInfo.HardwareProfile.VmSize
                $Location = Get-LocationDisplayName -Location $currentVmInfo.Location
            }
            catch {
                Write-Host ($_ | ConvertTo-Json)
                $Location = ""
            }

            # vCore
            [int]$NumberOfCores = $VmSku | ? {$_.Name -eq $CurrentVmSize} | select -ExpandProperty NumberOfCores
            if ($NumberOfCores -eq 0) {
                $CurrentVmSize = "Unknown"
                $msg = "[Error] Unable to retrieve information from Host Pool: " + $($CurrentHostPool.Name)
                Write-Host ("`n$msg`n") -ForegroundColor Red
                $Global:Message += $msg
            }

            # Unique Id
            $Uid = ($CurrentVmSize + ";" + $currentVmInfo.Location)

            # Add Session Host and vCore status to temp array
            if ($SubscriptionVmSizeSummary.Uid -notcontains $Uid) {
                $obj = New-Object -TypeName PSobject
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "VmSize" -Value $CurrentVmSize
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "NumberOfCores" -Value $NumberOfCores
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "Region" -Value $Location
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "HostTotal" -Value $CurrentSessionHosts.Count
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "vCoreTotal" -Value ($NumberOfCores * $CurrentSessionHosts.Count)
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "Uid" -Value $Uid
                $SubscriptionVmSizeSummary += $obj
            } else {
                foreach ($item in $SubscriptionVmSizeSummary) {
                    if ($item.Uid -eq $Uid) {
                        # Calculate Session Host
                        [int]$NewInstanceCount = $item.HostTotal + $CurrentSessionHosts.Count
                        $item.HostTotal = $NewInstanceCount

                        # Calculate vCore
                        [int]$NewVCoreCount = $item.vCoreTotal + ($NumberOfCores * $CurrentSessionHosts.Count)
                        $item.vCoreTotal = $NewVCoreCount
                    }
                }
            }
        } else {
            $msg = "[Info] Host Pool: " + $CurrentHostPool.Name + " has " + $CurrentSessionHosts.Count + " Session Host"
            Write-Host ("`n$msg`n") -ForegroundColor Yellow
            $Global:Message += $msg
        }
    }
    # Current Subscription Summary
    Write-Host ("`nSummary of Current Subscription`n" + "-" * 30)
    Write-Host ($($CurrentHostPools.Count).ToString() + " Host Pool(s)")
    Write-Host ($($SubscriptionSessionHosts.Count).ToString() + " Session Host(s)")
    Write-Host ($([int]$SubTotal = 0;$SubscriptionVmSizeSummary | % {$SubTotal += $_.vCoreTotal};$SubTotal).ToString() + " vCore(s)")
    $SubscriptionVmSizeSummary = $SubscriptionVmSizeSummary | Sort-Object VmSize, Region
    $SubscriptionVmSizeSummary | ft VmSize, NumberOfCores, Region, HostTotal, vCoreTotal -AutoSize

    # Add to Global Array
    $Global:SessionHosts += $SubscriptionSessionHosts

    foreach ($item in $SubscriptionVmSizeSummary) {
        if ($Global:VmSizeSummary.Uid -notcontains $item.Uid) {
            $obj = New-Object -TypeName PSobject
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VmSize" -Value $item.VmSize
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "NumberOfCores" -Value $item.NumberOfCores
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Region" -Value $item.Region
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "HostTotal" -Value $item.HostTotal
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "vCoreTotal" -Value $item.vCoreTotal
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Uid" -Value $item.Uid
            $Global:VmSizeSummary += $obj
        } else {
            # Calculate Session Host
            $NewHost = $($Global:VmSizeSummary | ? {$_.Uid -eq $item.Uid}).HostTotal
            $NewHost += $item.HostTotal
            $($Global:VmSizeSummary | ? {$_.Uid -eq $item.Uid}).HostTotal = $NewHost

            # Calculate vCore
            $NewCore = $($Global:VmSizeSummary | ? {$_.Uid -eq $item.Uid}).vCoreTotal
            $NewCore += $item.vCoreTotal
            $($Global:VmSizeSummary | ? {$_.Uid -eq $item.Uid}).vCoreTotal = $NewCore
        }
    }
}

# Export
Write-Host ("`nTotal`n" + "-" * 70)
Write-Host ($($Global:HostPools.Count).ToString() + " Host Pool(s)")
Write-Host ($($Global:SessionHosts.Count).ToString() + " Session Host(s)")
Write-Host ($([int]$SubTotal = 0;$Global:VmSizeSummary | % {$SubTotal += $_.vCoreTotal};$SubTotal).ToString() + " vCore(s)")

# Provisioning and Utilization
$Global:VmSizeSummary = $Global:VmSizeSummary | Sort-Object VmSize, Region
$Global:VmSizeSummary | ft VmSize, NumberOfCores, Region, HostTotal, vCoreTotal -AutoSize 
$Global:VmSizeSummary | select VmSize, NumberOfCores, Region, HostTotal, vCoreTotal | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "AVD_Utilization" -TableName "AVD_Utilization" -TableStyle Medium16 -AutoSize -Append

# Session Hosts Power Status
$Global:SessionHosts | group Status | select Name, Count | Sort-Object Name | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "PowerStatus" -TableName "PowerStatus" -TableStyle Medium16 -AutoSize -Append

# Session Hosts Update Error
$Global:SessionHosts | group UpdateErrorMessage | select Name, Count | ? {$_.Name -ne "" -and $_.Name -ne $null} | Sort-Object Name | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "UpdateErrorMessage" -TableName "UpdateErrorMessage" -TableStyle Medium16 -AutoSize -Append

# Host Pools
foreach ($item in $Global:HostPools) {

    $AssignedScalingPlan = $Global:ScalingPlanAssignment | ? {$_.AssignedHostPoolResourceId -eq $item.Id} | select -ExpandProperty ScalingPlan
    if ($AssignedScalingPlan -eq $null) {
        $AssignedScalingPlan = "N/A"
        $ScalingPlanSchedule = "N/A"
    } else {
        $ScalingPlanSchedule = $Global:ScalingPlanAssignment | ? {$_.AssignedHostPoolResourceId -eq $item.Id} | select -ExpandProperty ScheduleName
    }

    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "HostPool" -Value $item.Name
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "FriendlyName" -Value $item.FriendlyName
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "HostPoolType" -Value $item.HostPoolType
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "LoadBalancerType" -Value $item.LoadBalancerType
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value (Get-LocationDisplayName -Location $item.Location)
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "MaxSessionLimit" -Value $item.MaxSessionLimit
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "AssignedScalingPlan" -Value $AssignedScalingPlan
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ScalingPlanSchedule" -Value $ScalingPlanSchedule
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ApplicationGroupCount" -Value $item.ApplicationGroupReference.Count
    $Global:HostPoolsSummary += $obj
}

$Global:HostPoolsSummary | Sort-Object HostPool | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "HostPool" -TableName "HostPool" -TableStyle Medium16 -AutoSize -Append

# Scaling Plan Assignment
$Global:ScalingPlanAssignment | Sort-Object AssignedHostPoolResourceId, ScalingPlan | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "ScalingPlan" -TableName "ScalingPlan" -TableStyle Medium16 -AutoSize -Append

# Section Hosts Full List with Power Status
foreach ($item in $Global:SessionHosts) {
    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value ($Global:Subscriptions | ? {$_.Id -eq $item.ResourceId.Split("/")[2]} | select -ExpandProperty Name)
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $item.ResourceId.Split("/")[2]
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "HostPool" -Value $item.Name.Split("/")[0]
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "SessionHost" -Value $item.ResourceId.Split("/")[-1]
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "OSVersion" -Value $item.OSVersion
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Status" -Value $item.Status
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "StatusTimestamp" -Value $item.StatusTimestamp
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "UpdateState" -Value $item.UpdateState
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "UpdateErrorMessage" -Value $item.UpdateErrorMessage
    $Global:SessionHostsSummary += $obj
}

$Global:SessionHostsSummary | Sort-Object SubscriptionName, HostPool, SessionHost | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "SessionHost" -TableName "SessionHost" -TableStyle Medium16 -AutoSize -Append

# Log
$Global:Message | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "Log" -TableName "Log" -TableStyle Medium16 -AutoSize -Append

# End
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`nCompleted"
$Global:EndTime = Get-Date
$Duration = $Global:EndTime - $Global:StartTime
Write-Host ("`nTotal Process Time: " + $Duration.Hours + " Hours " + $Duration.Minutes + " Minutes " + $Duration.Seconds + " Seconds") -ForegroundColor Blue -BackgroundColor Black
Start-Sleep -Seconds 1
Write-Host "`n"