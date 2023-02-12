# Global Parameter 
$username = "" # Enter UPN of Azure Account
$SpecificTenant = "" # "Y" or "N"
$TenantId = "" # Enter Tenant ID if $SpecificTenant is "Y"

# Script Variable
$password = Get-Content .\secure-password.txt
$adminCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, ($password | ConvertTo-SecureString)
[string]$PlainTextPassword = $adminCredential.GetNetworkCredential().Password

# Main
Write-Host "`nConnecting to Azure with both Az PowerShell Module and Azure CLI" -ForegroundColor Gray
$error.Clear()

if ($SpecificTenant -eq "Y") {
    Connect-AzAccount -Credential $adminCredential -Tenant $TenantId | Out-Null
    az login --username $username --password $PlainTextPassword --tenant $TenantId
} else {
    Connect-AzAccount -Credential $adminCredential | Out-Null
    az login --username $username --password $PlainTextPassword
}

# End
if ($error.Count -eq 0) {
    Write-Host "`nConnected`n" -ForegroundColor Gray
} else {
    Write-Host "`nLogin issue, please review the error message`n" -ForegroundColor Yellow
}