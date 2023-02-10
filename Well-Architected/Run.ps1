# Global Parameter
$SpecificTenant = "N" # "Y" or "N"
$TenantId = "" # Enter Tenant ID if $SpecificTenant is "Y"
$Global:ExcelOutputFolder = "C:\Temp"
$ExcelFileName = "WAF-Assessment.xlsx" # Export Result to Excel file 

# Script Variable
if ($Global:ExcelOutputFolder -notlike "*\") {$Global:ExcelOutputFolder += "\"}
$Global:ExcelFullPath = $Global:ExcelOutputFolder + $ExcelFileName
$Global:RunScriptList = @()
$Global:DisabledRunScript = @()
$ErrorActionPreference = "Continue"
$Width = 120
$error.Clear()

# Run-Script Configuration
$GetAzureBackup = $false
$GetAzureSql = $false
$GetAzureSqlMI = $false
$GetDiagnosticSetting = $true
$GetRedisCache = $false
$GetAZoneEnabledService = $false
$GetClassicResource = $false
$GetUnmanagedDisk = $false
$GetStorageAccount = $false
$GetAppService = $false

function Update-RunScriptList {
    param(
        $RunScript,
        $Command
    )

    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "RunScript" -Value $RunScript
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Command" -Value $Command
    $Global:RunScriptList += $obj
}

# Set PowerShell Windows Size
if ($host.UI.RawUI.BufferSize.Width -lt $Width) {
    $host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.size(120,9999)
    $host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.size(120,45)
    Start-Sleep -Milliseconds 200
}

# Create the Export Folder if not exist
if (!(Test-Path $Global:ExcelOutputFolder)) {
    $Global:ExcelOutputFolder
    try {
        New-Item -Path $Global:ExcelOutputFolder -ItemType Directory -Force -Confirm:$false -ErrorAction Stop
    } catch {
        Write-Host "$Global:ExcelOutputFolder does not exist or cannot create"
        throw
    }
}

# Delete Assessment Excel File
if (Test-Path $Global:ExcelFullPath) {
    try {
        Remove-Item $Global:ExcelFullPath -Force -Confirm:$false -ErrorAction Stop
    } catch {
        Write-Host "Excel File with same name exists or cannot delete"
        throw
    }
}

# Login
#$ConnectAzAccount = Connect-AzAccount | Out-Null
#$AzLogin = az login | Out-Null


# Get Azure Subscription
if ($SpecificTenant -eq "Y") {
    #$Global:Subscriptions = Get-AzSubscription -TenantId $TenantId
} else {
    #$Global:Subscriptions = Get-AzSubscription
}

# Determine Run-Script
Write-Host "`n"
Write-Host "Enabled Run-Script:" -ForegroundColor Green -BackgroundColor Black

if ($GetAzureBackup) {
    Write-Host "Get Azure Backup Status" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetAzureBackup" -Command "& .\Get-AzureBackupStatus.ps1"
} else {
    $Global:DisabledRunScript += "Get Azure Backup Status"
}

if ($GetAzureSql) {
    Write-Host "Get Azure SQL Configuration" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetAzureSql" -Command "& .\Get-AzureSql-Configuration.ps1"
} else {
    $Global:DisabledRunScript += "Get Azure SQL Configuration"
} 

if ($GetAzureSqlMI) {
    Write-Host "Get Azure SQL Managed Instance Configuration" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetAzureSqlMI" -Command "& .\Get-AzureSqlMI-Configuration.ps1"
} else {
    $Global:DisabledRunScript += "Get Azure SQL Managed Instance Configuration"
} 

if ($GetDiagnosticSetting) {
    Write-Host "Get Diagnostic Setting" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetDiagnosticSetting" -Command "& .\Get-DiagnosticSetting.ps1"
} else {
    $Global:DisabledRunScript += "Get Diagnostic Setting"
} 

if ($GetRedisCache) {
    Write-Host "Get Azure Cache for Redis Network Configuration" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetRedisCache" -Command "& .\Get-Redis-Configuration.ps1"
} else {
    $Global:DisabledRunScript += "Get Azure Cache for Redis Network Configuration"
} 

if ($GetAZoneEnabledService) {
    Write-Host "Get Availability Zone Enabled Service" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetAZoneEnabledService" -Command "& .\Get-AZoneEnabledService.ps1"
} else {
    $Global:DisabledRunScript += "Get Availability Zone Enabled Service"
} 

if ($GetClassicResource) {
    Write-Host "Get Classic Resources" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetClassicResource" -Command "& .\Get-ClassicResource.ps1"
} else {
    $Global:DisabledRunScript += "Get Classic Resources"
} 

if ($GetUnmanagedDisk) {
    Write-Host "Get Unmanaged Disk of Virtual Machine" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetUnmanagedDisk" -Command "& .\Get-Unmanaged-Disk.ps1"
} else {
    $Global:DisabledRunScript += "Get Unmanaged Disk of Virtual Machine"
} 

if ($GetStorageAccount) {
    Write-Host "Get Storage Account Configuration" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetStorageAccount" -Command "& .\Get-StorageAccount-Configuration.ps1"
} else {
    $Global:DisabledRunScript += "Get Storage Account Configuration"
} 

if ($GetAppService) {
    Write-Host "Get App Service Configuration" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetAppService" -Command "& .\Get-AppService.ps1"
} else {
    $Global:DisabledRunScript += "Get App Service Configuration"
} 

if ($Global:DisabledRunScript.Count -ne 0 -and (![string]::IsNullOrEmpty($Global:DisabledRunScript))) {
    Write-Host "`n"
    Write-Host "Disabled Run-Script:" -ForegroundColor DarkRed -BackgroundColor Black

    foreach ($item in $Global:DisabledRunScript) {
        Write-Host $item -ForegroundColor Cyan
    }
}
Start-Sleep -Seconds 1

# Startup Message
Write-Host "`n`n"
Write-Host ("*" * 60)
Write-Host ("*" + " " * 58 + "*")
Write-Host ("*" + " " * 58 + "*")
Write-Host ("*" + " " * 58 + "*")
Write-Host ("*" + " " * 8 + "Microsoft Azure Well-Architected Framework" + " " * 8 + "*")
Write-Host ("*" + " " * 58 + "*")
Write-Host ("*" + " " * 58 + "*")
Write-Host ("*" + " " * 58 + "*")
Write-Host ("*" * 60)

# Get the Latest Location Name and Display Name
$Global:NameReference = Get-AzLocation

# Disable breaking change warning messages
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value "true"

# Module
Import-Module ImportExcel

# Execute Run Script using RunspacePool
Write-Host "`n`nThe process may take more than 30 minutes ..."
Write-Host "`nPlease wait until it finishes ..."
Start-Sleep -Seconds 1
$Global:StartTime = Get-Date
foreach ($RunScript in $Global:RunScriptList) {
    Invoke-Expression -Command $RunScript.Command
}

# End
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`nWell-Architected Assessment have been completed"
$Global:EndTime = Get-Date
$Duration = $Global:EndTime - $Global:StartTime
Write-Host ("`nTotal Process Time: " + $Duration.Hours + " Hours " + $Duration.Minutes + " Minutes " + $Duration.Seconds + " Seconds") -ForegroundColor Blue -BackgroundColor Black
Start-Sleep -Seconds 1
Write-Host ("`nPlease refer to the Assessment Result locate at " + $Global:ExcelFullPath)
Write-Host "`n"