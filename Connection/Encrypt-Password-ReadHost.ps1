# Main
$password = Read-Host -Prompt "Enter your Password of Azure Account, then press ENTER" -AsSecureString
$bytes = ConvertFrom-SecureString $password
$bytes | Out-File .\secure-password.txt