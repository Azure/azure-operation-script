# Global Parameter 
$username = "" # Enter UPN of Azure Account
$SpecificTenant = "" # "Y" or "N"
$TenantId = "" # Enter Tenant ID if $SpecificTenant is "Y"

# Script Variable
$password = Get-Content .\secure-password.txt
$adminCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, ($password | ConvertTo-SecureString)
[string]$PlainTextPassword = $adminCredential.GetNetworkCredential().Password

# Main
Write-Host "`nConnecting to Azure using Az PowerShell Module" -ForegroundColor Gray

if ($SpecificTenant -eq "Y") {
    Connect-AzAccount -Credential $adminCredential -Tenant $TenantId | Out-Null
    az login --username $username --password $PlainTextPassword --tenant $TenantId
} else {
    Connect-AzAccount -Credential $adminCredential | Out-Null
    az login --username $username --password $PlainTextPassword
}

Write-Host "`nConnected`n" -ForegroundColor Gray
