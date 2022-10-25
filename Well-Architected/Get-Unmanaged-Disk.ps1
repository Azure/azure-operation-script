# Script Variable
$Global:UnmanagedDisk = @()
$Global:UnmanagedDiskSummary = @()
$CurrentItem = 1

# Disable breaking change warning messages
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value "true"

# Module
Import-Module ImportExcel

# Main
Write-Host ("`n" + "=" * 100)
Write-Host "`nGet Unmanaged Disk of Virtual Machine" -ForegroundColor Cyan

foreach ($Subscription in $Global:Subscriptions) {
    Write-Host ("`n")
    Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
	
    # Set current subscription
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id
    az account set --subscription $Subscription.Id
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Global:Subscriptions.Count + " Subscription: " + $Subscription.name) -ForegroundColor Yellow

    # Get Az VM List
    $CurrentItem++
    $CurrentVMItem = 1
    $vms = Get-AzVM

    foreach ($vm in $vms) {
        Write-Host ("`nProcessing Azure VM (" + $CurrentVMItem + " out of " + $vms.Count + ") of Subscription: " + $Subscription.name) -ForegroundColor White
        $CurrentVMItem++

        # OS Disk
        if ($vm.StorageProfile.OsDisk.ManagedDisk -eq $null) {
            # Save to Temp Object
            $obj = New-Object -TypeName PSobject
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.Id
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $vm.ResourceGroupName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VM" -Value $vm.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "DiskName" -Value $vm.StorageProfile.OsDisk.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "DiskType" -Value "OS Disk"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VhdUri" -Value $vm.StorageProfile.OsDisk.Vhd.Uri

            # Save to Array
            $Global:UnmanagedDisk += $obj
        }

        # Data Disk
        $VmDisks = az vm unmanaged-disk list -g $vm.ResourceGroupName --vm-name $vm.Name
        $VmDisks = $VmDisks | ConvertFrom-Json
        foreach ($VmDisk in $VmDisks) {
            if ($VmDisk.managedDisk -eq $null) {
                # Save to Temp Object
                $obj = New-Object -TypeName PSobject
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.Id
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $vm.ResourceGroupName
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "VM" -Value $vm.Name
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "DiskName" -Value $VmDisk.Name
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "DiskType" -Value "Data Disk"
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "VhdUri" -Value $VmDisk.vhd.uri

                # Save to Array
                $Global:UnmanagedDisk += $obj
            }
        }
    }
}

#Region Export
if ($Global:UnmanagedDisk.Count -ne 0) {
    # Prepare Classic Resources Summary
    $CountType = $Global:UnmanagedDisk | group DiskType | select Name, Count | sort Name
    $ResourceTotal = $Global:UnmanagedDisk.Count

    foreach ($item in $CountType) {
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DiskType" -Value $item.Name 
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Subtotal" -Value $item.Count
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Total" -Value $ResourceTotal
        $Global:UnmanagedDiskSummary += $obj
    }

    # Export to Excel File
    $Global:UnmanagedDiskSummary | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "UnmanagedDiskSummary" -TableName "UnmanagedDiskSummary" -TableStyle Medium16 -AutoSize -Append
    $Global:UnmanagedDisk | sort SubscriptionName, ResourceGroup, VM, DiskName | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "UnmanagedDiskDetail" -TableName "UnmanagedDiskDetail" -TableStyle Medium16 -AutoSize -Append
} else {
    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value "Unmanaged Disk"
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Status" -Value "Resource is not found"
    $Global:UnmanagedDiskSummary += $obj

    # Export to Excel File
    $Global:UnmanagedDiskSummary| Export-Excel -Path $Global:ExcelFullPath -WorksheetName "ResourceNotFound" -TableName "ResourceNotFound" -TableStyle Light11 -AutoSize -Append
}
#EndRegion Export