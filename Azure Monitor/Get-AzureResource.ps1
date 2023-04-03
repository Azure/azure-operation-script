# Global Parameter
$CsvOutputFolder = "C:\Temp"
$CsvFileName = "Resources.csv" # Export Result to Excel file 

# Script Variable
if ($CsvOutputFolder -notlike "*\") {$CsvOutputFolder += "\"}
$CsvFullPath = $CsvOutputFolder + $CsvFileName
$ResourceList = @()
[int]$CurrentItem = 1
$ErrorActionPreference = "Continue"

# Disable breaking change warning messages
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value "true"

# Get Subscription
$Global:Subscriptions = Get-AzSubscription | ? {$_.State -eq "Enabled" -and $_.Name -ne "Access to Azure Active Directory"}

# Main
$Global:StartTime = Get-Date
Write-Host ("`n" + "=" * 70)
Write-Host "`nGet full resource list of Azure Subscription that accessible to current user account" -ForegroundColor Cyan

foreach ($Subscription in $Global:Subscriptions) {
    Write-Host ("`n")
    Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
    
    # Set current subscription
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id -TenantId $Subscription.TenantId
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Global:Subscriptions.Count + " Subscription: " + $Subscription.Name) -ForegroundColor Yellow
    $CurrentItem++

    # Get resources
    $resources = Get-AzResource

    foreach ($resource in $resources) {
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.Id
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value $resource.ResourceType
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $resource.ResourceGroupName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Name" -Value $resource.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $resource.Location
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceId" -Value $resource.ResourceId
        $ResourceList += $obj
    }
}

# Export
$ResourceList | Export-Csv -Path $CsvFullPath -NoTypeInformation -Force -Confirm:$false