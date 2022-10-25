# Script Variable
$Global:ClassicList = @()
$Global:ClassicListSummary = @()
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

function Rename-ResourceType {
    param (
        [string]$ResourceType
    )

    switch -Wildcard ($ResourceType) {
        "*domainNames*" { $ResourceType = "Cloud Service (classic)"; continue; }
        "*reservedIps*" { $ResourceType = "Reserved IP Address (classic)"; continue; }
        "*virtualMachines*" { $ResourceType = "Virtual Machine (classic)"; continue; }
        "*virtualNetworks*" { $ResourceType = "Virtual Network (classic)"; continue; }
        "*storageAccounts*" { $ResourceType = "Storage Account (classic)"; continue; }
        Default {}
    }

    return $ResourceType
}

# Disable breaking change warning messages
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value "true"

# Module
Import-Module ImportExcel

# Main
Write-Host ("`n" + "=" * 100)
Write-Host "`nGet Classic Resources" -ForegroundColor Cyan

foreach ($Subscription in $Global:Subscriptions) {
    Write-Host ("`n")
    Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
    
    # Set current subscription
	$AzContext = Set-AzContext -SubscriptionId $Subscription.Id
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Global:Subscriptions.Count + " Subscription: " + $Subscription.name) -ForegroundColor Yellow
    $CurrentItem++

    # Get Az Resource List
    $ClassicResources = Get-AzResource | ? { $_.ResourceType -like "*Classic*" }
    
    foreach ($ClassicResource in $ClassicResources) {
        $Location = Rename-Location -Location $ClassicResource.Location
        $ResourceType = Rename-ResourceType -ResourceType $ClassicResource.ResourceType
        
        # Save to Temp Object
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.Id
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $ClassicResource.ResourceGroupName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceName" -Value $ClassicResource.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value $ResourceType
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Location
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceId" -Value $ClassicResource.ResourceId
    
        # Save to Array
        $Global:ClassicList += $obj
    }
}

#Region Export
if ($Global:ClassicList.Count -ne 0) {
    # Prepare Classic Resources Summary
    $CountType = $Global:ClassicList | group ResourceType | select Name, Count | sort Name
    foreach ($item in $CountType) {
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value $item.Name 
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Total" -Value $item.Count
        $Global:ClassicListSummary += $obj
    }

    # Export to Excel File
    $Global:ClassicListSummary | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "ClassicSummary" -TableName "ClassicSummary" -TableStyle Medium16 -AutoSize -Append
    $Global:ClassicList | sort ResourceType, SubscriptionName, ResourceGroup, ResourceName | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "ClassicDetail" -TableName "ClassicDetail" -TableStyle Medium16 -AutoSize -Append
} else {
    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value "Classic Resource (ASM)"
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Status" -Value "Resource is not found"
    $Global:ClassicListSummary += $obj

    # Export to Excel File
    $Global:ClassicListSummary | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "ResourceNotFound" -TableName "ResourceNotFound" -TableStyle Light11 -AutoSize -Append
}
#EndRegion Export