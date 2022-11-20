$Location = "East Asia"
$KeyVaultRG = "KeyVault"
$KeyVaultName = "kv-core-prd-eas-001"
$KeyName = "AKS-BYOK-Key"
$DiskEncryptionSetName = "DiskEncryptionSet-AKS-Prod"

# Create an Azure Key Vault resource in a supported Azure region
az keyvault create -n $KeyVaultName -g $KeyVaultRG -l $Location --enable-purge-protection true --enable-soft-delete true

# Create a software-protected key OR Upload the custom key to Key Vault
# az keyvault key create --vault-name $KeyVaultName --name $KeyName --protection software

# Retrieve the Key Vault Id and store it in a variable
$keyVaultId = $(az keyvault show --name $KeyVaultName --query "[id]" -o tsv)

# Retrieve the Key Vault key URL and store it in a variable
$keyVaultKeyUrl = $(az keyvault key show --vault-name $KeyVaultName --name $KeyName --query "[key.kid]" -o tsv)

# Create a DiskEncryptionSet
az disk-encryption-set create -n $DiskEncryptionSetName -l $Location -g $KeyVaultRG --source-vault $keyVaultId --key-url $keyVaultKeyUrl

# Retrieve the DiskEncryptionSet value and set a variable
$desIdentity = $(az disk-encryption-set show -n $DiskEncryptionSetName -g $KeyVaultRG --query "[identity.principalId]" -o tsv)

# Update security policy settings
az keyvault set-policy -n $KeyVaultName -g $KeyVaultRG --object-id $desIdentity --key-permissions wrapkey unwrapkey get

# Retrieve the DiskEncryptionSet value and set a variable
$diskEncryptionSetId = $(az disk-encryption-set show -n $DiskEncryptionSetName -g $KeyVaultRG --query "[id]" -o tsv)