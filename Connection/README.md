# Highlight

- If executing .ps1 by **right-click the script file name and then select "Run with PowerShell"**, **Connect-AzAccount** will run in Local Scope. In other words, each script is an individual connection section that unable to share with other script
- To reuse the connection section for multiple scripts, starting from opening a **Windows PowerShell** from start menu, explicitly login once, then either run the script or copy the content and paste into the **Windows PowerShell**

# Prerequisites

- For Non-Interactive logins, Azure Run-As Account should not enable Multi-Factor Authentication
- Run connection scripts under the same directory as secure-password.txt

# List of Scripts

| Id | File Name | Description |
| - | - | - |
| 1 | Encrypt-Password-Embed.ps1 | Specify the password in script file, converting to **SecureString** and export to text file |
| 2 | Encrypt-Password-ReadHost.ps1 | Enter the password at PowerShell session for Converting to **SecureString** and export to text file |
| 3 | Connect-To-Cloud.ps1 | Login Azure with pre-encrypted credential using PowerShell  |

# PowerShell Scope

PowerShell support following scopes:

- **Global**: The scope that is in effect when PowerShell starts or when you create a new session or runspace. Variables and functions that are present when PowerShell starts have been created in the global scope, such as automatic variables and preference variables. The variables, aliases, and functions in your PowerShell profiles are also created in the global scope. The global scope is the root parent scope in a session.
- **Local**: The current scope. The local scope can be the global scope or any other scope.
- **Script**: The scope that is created while a script file runs. Only the commands in the script run in the script scope. To the commands in a script, the script scope is the local scope.

**Reference:** 

[About Scopes](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_scopes)

# Issue Log

### 1. Az Module
```
WARNING: Unable to acquire token for tenant 'Tenant Id XXX' with error 'You must use multi-factor authentication to access tenant 'Tenant Id XXX', please rerun 'Connect-AzAccount' with additional parameter '-TenantId Tenant Id XXX'.'
```

**Solution**

Run Connect-AzAccount with -TenantId parameter during initial connection

```PowerShell
Connect-AzAccount
Connect-AzAccount -TenantId "Tenant Id" # Execute for each TenantId
```

### 2. Azure CLI

```
WARNING: You have logged in. Now let us find all the subscriptions to which you have access...
WARNING: The following tenants require Multi-Factor Authentication (MFA). Use 'az login --tenant TENANT_ID' to explicitly login to a tenant.
WARNING: <Subscription ID> 'Subscription Name'
```

**Solution**

Run az login with -TenantId during initial connection. 

```Bash
az login
az login --tenant "Tenant Id" # Execute for each TenantId
```