# Global Parameter
$TenantIds = @("")
$ExcelOutputFolder = "C:\Temp"
$ExcelFileName = "AVD-Usage.xlsx" # Export Result to Excel file 

# Script Variable
$Global:Subscriptions = @()
if ($ExcelOutputFolder -notlike "*\") {$ExcelOutputFolder += "\"}
$Global:ExcelFullPath = $ExcelOutputFolder + $ExcelFileName
$Global:VmList = @()
$Global:ScalingPlanAssignment = @()
$Global:ApplicationGroupList = @()
$Global:HostPools = @()
$Global:HostPoolsSummary = @()
$Global:SessionHostsSummary = @()
$Global:VmSizeSummary = @()
$Global:VmSku = @()
$Global:Message = @()
[int]$CurrentItem = 1
$VmSkuLocation = @("East Asia", "Southeast Asia")
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

# Start
$Global:StartTime = Get-Date
Write-Host ("`n" + "=" * 70 + "`n")
Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host ("`nRunning ...`n") -ForegroundColor Cyan

# Login and get list of subscription(s)
foreach ($TenantId in $TenantIds) {
    Connect-AzAccount -TenantId $TenantId
    $Global:Subscriptions += Get-AzSubscription -TenantId $TenantId | ? {$_.Name -like "*AVD*"} # Retrieve specific subscription(s) where AVD exists
    Start-Sleep -Seconds 2
}
$Global:Subscriptions = $Global:Subscriptions | ? {$_.State -eq "Enabled" -and $_.Name -ne "Access to Azure Active Directory"} | Sort-Object TenantId, Name

# Disable breaking change warning messages
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value "true"

# Module
Import-Module ImportExcel

# Get the Latest Location Name, Display Name, and Paired Region
$Global:NameReference = Get-AzLocation | ? {$_.RegionType -eq "Physical" -and $_.DisplayName -notlike "*EUAP*"} | Sort-Object GeographyGroup, DisplayName

# Get Azure VM and Scaling Plan
Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`nCollect the list of Azure VM and Scaling Plan Assignment" -ForegroundColor Cyan
foreach ($Subscription in $Global:Subscriptions) {
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id -TenantId $Subscription.TenantId

    # Azure VM
    $Global:VmList += Get-AzVM

    # Get Azure VM Sku
    foreach ($locate in $VmSkuLocation) {
        $CurrentVmSku = Get-AzVMSize -Location $locate

        foreach ($item in $CurrentVmSku) {
            if ($Global:VmSku.Name -notcontains $item.Name) {
                $Global:VmSku += $item
            }
        }
    }

    # Scaling Plan
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

    # Application Group
    $ApplicationGroups = Get-AzWvdApplicationGroup

    foreach ($ApplicationGroup in $ApplicationGroups) {
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.Id
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "InstanceName" -Value $ApplicationGroup.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Type" -Value $ApplicationGroup.Kind
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "FriendlyName" -Value $ApplicationGroup.FriendlyName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Description" -Value $ApplicationGroup.Description
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "AssignedHostPool" -Value $ApplicationGroup.HostPoolArmPath.Split("/")[-1]
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "AssignedHostPoolResourceId" -Value $ApplicationGroup.HostPoolArmPath

        if ($null -eq $ApplicationGroup.WorkspaceArmPath) {
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "AssignedWorkspace" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "AssignedWorkspaceResourceId" -Value "N/A"
        } else {
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "AssignedWorkspace" -Value $ApplicationGroup.WorkspaceArmPath.Split("/")[-1]
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "AssignedWorkspaceResourceId" -Value $ApplicationGroup.WorkspaceArmPath
        }
        $Global:ApplicationGroupList += $obj
    }
}

# Main
Write-Host ("`n")
Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`nCollect the utilization of AVD Host Pool" -ForegroundColor Cyan

foreach ($Subscription in $Global:Subscriptions) {
    Write-Host ("`n")
    Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
    
    # Set current subscription
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id -TenantId $Subscription.TenantId
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Global:Subscriptions.Count + " Subscription: " + $Subscription.Name) -ForegroundColor Yellow
    $CurrentItem++

    # Get Host Pool
    $SubscriptionSessionHosts = @()
    $SubscriptionVmSizeSummary = @()
    $CurrentHostPools = Get-AzWvdHostPool

    if ($CurrentHostPools.Count -gt 0) {
        $Global:HostPools += $CurrentHostPools

        # Get Session Host of each Host Pool
        foreach ($CurrentHostPool in $CurrentHostPools) {
            $AvsRG = $CurrentHostPool.Id.Substring($CurrentHostPool.Id.IndexOf("/resourcegroups/") + 16)
            $AvsRG = $AvsRG.Substring(0, $AvsRG.IndexOf("/providers/Microsoft.DesktopVirtualization/"))
            $CurrentSessionHosts = Get-AzWvdSessionHost -ResourceGroupName $AvsRG -HostPoolName $CurrentHostPool.Name
            $SubscriptionSessionHosts += $CurrentSessionHosts
            Start-Sleep -Seconds 1

            if ($CurrentSessionHosts.Count -gt 0) {
                foreach ($CurrentSessionHost in $CurrentSessionHosts) {
                    $CurrentVmInfo = $Global:VmList | ? {$_.Id -eq $CurrentSessionHost.ResourceId}
                    $CurrentVmHostName = $CurrentSessionHost.Id.Split("/")[-1]

                    if ($null -eq $CurrentVmInfo) {
                        $msg = "[Error] Unable to retrieve Session Hosts $CurrentVmHostName of Host Pool: " + $($CurrentHostPool.Name)
                        $SubscriptionName = "Unknown"
                        $SubscriptionId = $CurrentSessionHost.ResourceId.Split("/")[2]
                        $CurrentVmSize = "Unknown"
                        $OsDiskSku = "Unknown"
                        $OsDiskSize = "Unknown" 
                        $Location = "Unknown"
                        $NumberOfCores = 0
                        $Uid = "Unknown"
                        Write-Host ("`n$msg`n") -ForegroundColor Red
                        $Global:Message += $msg
                    } else {
                        $SubscriptionName = ($Global:Subscriptions | ? {$_.Id -eq $CurrentVmInfo.Id.Split("/")[2]} | select -ExpandProperty Name)
                        $SubscriptionId = $CurrentVmInfo.Id.Split("/")[2]
                        [string]$CurrentVmSize = $CurrentVmInfo.HardwareProfile.VmSize
                        [string]$OsDiskSku = $CurrentVmInfo.StorageProfile.OsDisk.ManagedDisk.StorageAccountType
                        [string]$OsDiskSize = $CurrentVmInfo.StorageProfile.OsDisk.DiskSizeGB 

                        if ($null -eq $OsDiskSku -or $OsDiskSku -eq "") {
                            $disk = Get-AzDisk -ResourceGroupName $CurrentVmInfo.StorageProfile.OsDisk.ManagedDisk.Id.Split("/")[4] -DiskName $CurrentVmInfo.StorageProfile.OsDisk.ManagedDisk.Id.Split("/")[8]

                            [string]$OsDiskSku = $disk.Sku.Name
                            [string]$OsDiskSize = $disk.DiskSizeGB 
                        }

                        $Location = Get-LocationDisplayName -Location $currentVmInfo.Location

                        # vCore
                        [int]$NumberOfCores = $Global:VmSku | ? {$_.Name -eq $CurrentVmSize} | select -ExpandProperty NumberOfCores
                        if ($NumberOfCores -eq 0) {
                            $CurrentVmSize = "Unknown"
                            $Uid = "Unknown"
                            $msg = "[Error] Sku '$CurrentVmSize' is not valid for Session Hosts $CurrentVmHostName of Host Pool: " + $($CurrentHostPool.Name)
                            Write-Host ("`n$msg`n") -ForegroundColor Red
                            $Global:Message += $msg
                        } else {
                            $Uid = ($CurrentVmSize + ";" + $currentVmInfo.Location)
                        }
                    }

                    # Add Session Host and vCore status to temp array
                    if ($SubscriptionVmSizeSummary.Uid -notcontains $Uid) {
                        $obj = New-Object -TypeName PSobject
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "VmSize" -Value $CurrentVmSize
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "NumberOfCores" -Value $NumberOfCores
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Region" -Value $Location
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "HostTotal" -Value 1
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "vCoreTotal" -Value $NumberOfCores
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Uid" -Value $Uid
                        $SubscriptionVmSizeSummary += $obj
                    } else {
                        foreach ($item in $SubscriptionVmSizeSummary) {
                            if ($item.Uid -eq $Uid) {
                                # Calculate Session Host
                                [int]$NewInstanceCount = ($item.HostTotal + 1)
                                $item.HostTotal = $NewInstanceCount

                                # Calculate vCore
                                [int]$NewVCoreCount = ($item.vCoreTotal + $NumberOfCores)
                                $item.vCoreTotal = $NewVCoreCount
                            }
                        }
                    }

                    # Session Hosts
                    $obj = New-Object -TypeName PSobject
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $SubscriptionName
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $SubscriptionId
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "HostPool" -Value $CurrentHostPool.Name
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "SessionHostName" -Value $CurrentVmHostName #$CurrentVmInfo.Name
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "OSVersion" -Value $CurrentSessionHost.OSVersion
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Location
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Sku" -Value $CurrentVmSize
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "OsDiskSku" -Value $OsDiskSku
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "OsDiskSize" -Value $OsDiskSize
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "PowerState" -Value $CurrentSessionHost.Status
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "UpdateState" -Value $CurrentSessionHost.UpdateState
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "UpdateErrorMessage" -Value $CurrentSessionHost.UpdateErrorMessage
                    $Global:SessionHostsSummary += $obj
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
    } else {
        Write-Host ("`nSummary of Current Subscription`n" + "-" * 30)
        Write-Host ("No Host Pool provisioned")
    }
}

# Export
Write-Host ("`nTotal`n" + "-" * 70)
Write-Host ($($Global:HostPools.Count).ToString() + " Host Pool(s)")
Write-Host ($($Global:SessionHostsSummary.Count).ToString() + " Session Host(s)")
Write-Host ($([int]$SubTotal = 0;$Global:VmSizeSummary | % {$SubTotal += $_.vCoreTotal};$SubTotal).ToString() + " vCore(s)")

# Provisioning and Utilization
$Global:VmSizeSummary = $Global:VmSizeSummary | Sort-Object VmSize, Region
$Global:VmSizeSummary | ft VmSize, NumberOfCores, Region, HostTotal, vCoreTotal -AutoSize 
$Global:VmSizeSummary | select VmSize, NumberOfCores, Region, HostTotal, vCoreTotal | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "AVD_Utilization" -TableName "AVD_Utilization" -TableStyle Medium16 -AutoSize -Append

# Session Hosts Power Status
$Global:SessionHostsSummary | group PowerState | select Name, Count | Sort-Object Name | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "PowerStatus" -TableName "PowerStatus" -TableStyle Medium16 -AutoSize -Append

# Session Hosts Update Error
$Global:SessionHostsSummary | group UpdateErrorMessage | select Name, Count | ? {$_.Name -ne "" -and $_.Name -ne $null} | Sort-Object Name | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "UpdateErrorMessage" -TableName "UpdateErrorMessage" -TableStyle Medium16 -AutoSize -Append

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
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "StartVMOnConnect" -Value $item.StartVMOnConnect
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "AssignedScalingPlan" -Value $AssignedScalingPlan
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ScalingPlanSchedule" -Value $ScalingPlanSchedule
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ApplicationGroupCount" -Value $item.ApplicationGroupReference.Count
    $Global:HostPoolsSummary += $obj
}

$Global:HostPoolsSummary | Sort-Object HostPool | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "HostPool" -TableName "HostPool" -TableStyle Medium16 -AutoSize -Append

# Scaling Plan Assignment
$Global:ScalingPlanAssignment | Sort-Object AssignedHostPoolResourceId, ScalingPlan | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "ScalingPlan" -TableName "ScalingPlan" -TableStyle Medium16 -AutoSize -Append

# Section Hosts Full List
$Global:SessionHostsSummary | Sort-Object SubscriptionName, HostPool, SessionHostName | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "SessionHost" -TableName "SessionHost" -TableStyle Medium16 -AutoSize -Append

# Application Group
$Global:ApplicationGroupList | Sort-Object SubscriptionName, InstanceName, FriendlyName | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "ApplicationGroup" -TableName "ApplicationGroup" -TableStyle Medium16 -AutoSize -Append

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