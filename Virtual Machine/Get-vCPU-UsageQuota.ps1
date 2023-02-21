# Global Parameter
$Location = "Southeast Asia"
$Global:ExcelOutputFolder = "C:\Temp"
$ExcelFileName = "VM-vCore-Quota.xlsx" # Export Result to Excel file 

# Script Variable
if ($Global:ExcelOutputFolder -notlike "*\") {$Global:ExcelOutputFolder += "\"}
$Global:ExcelFullPath = $Global:ExcelOutputFolder + $ExcelFileName
$Global:UsageQuota = @()
[int]$CurrentItem = 1
$ErrorActionPreference = "Continue"

# Main
Write-Host ("`n" + "=" * 100)
Write-Host "`nGet vCPU Usage and Quota" -ForegroundColor Cyan

foreach ($Subscription in $Global:Subscriptions) {
    Write-Host ("`n")
    Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
    
    # Set current subscription
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id -TenantId $Subscription.TenantId
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Global:Subscriptions.Count + " Subscription: " + $Subscription.name) -ForegroundColor Yellow
    $CurrentItem++
    
    # Get Usage and Quota
    $usages = Get-AzVMUsage -Location $Location

    foreach ($usage in $usages) {
        $AvailableValue = ($usage.Limit - $usage.CurrentValue)

        # Save to Temp Object
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.id
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ItemName" -Value $usage.Name.LocalizedValue
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Limit" -Value $usage.Limit
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Used" -Value $usage.CurrentValue
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Available" -Value $AvailableValue
        if ($usage.Limit -ne 0) {
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Available(%)" -Value ($AvailableValue / $usage.Limit).ToString("P")
        } else {
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Available(%)" -Value "0%"
        }
        #Add-Member -InputObject $obj -MemberType NoteProperty -Name "Unit" -Value $usage.Unit

        # Save to Array
        $Global:UsageQuota += $obj
    }
}

# Export to Excel File
$Global:UsageQuota | sort SubscriptionName, ItemName | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "MicrosoftCompute" -TableName "MicrosoftCompute" -TableStyle Medium16 -AutoSize -Append

# End
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`n`nCompleted"