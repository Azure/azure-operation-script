# Global Parameter 
$password = "" # Enter your Password of Azure Account

# Main
$password = $password | ConvertTo-SecureString -Force -AsPlainText
$bytes = ConvertFrom-SecureString $password
$bytes | Out-File .\secure-password.txt