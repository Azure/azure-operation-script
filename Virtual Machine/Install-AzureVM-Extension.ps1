# Global Parameter
$VmRG = ""
$VmName = ""
$VmLocation = ""

# list the installed extension
$extensions = Get-AzVMExtension -ResourceGroupName $VmRG -VMName $VmName
$extensions | select Name, TypeHandlerVersion

# Azure Monitor Dependency for Windows
# https://learn.microsoft.com/en-us/azure/virtual-machines/extensions/agent-dependency-windows
Set-AzVMExtension -Name "Microsoft.Azure.Monitoring.DependencyAgent" -ExtensionType "DependencyAgentWindows" -Publisher "Microsoft.Azure.Monitoring.DependencyAgent" `
-TypeHandlerVersion "9.10" -EnableAutomaticUpgrade $true `
-ResourceGroupName $VmRG -VMName $VmName -Location $VmLocation
	
# Azure Monitor Agent
# Extension Property
# https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-manage?tabs=azure-powershell#virtual-machine-extension-details
# Version Detail (Specify Major and Minor version only)
# https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-extension-versions#version-details
Set-AzVMExtension -Name "AzureMonitorWindowsAgent" -ExtensionType "AzureMonitorWindowsAgent" -Publisher "Microsoft.Azure.Monitor" `
-TypeHandlerVersion "1.12" -EnableAutomaticUpgrade $true `
-ResourceGroupName $VmRG -VMName $VmName -Location $VmLocation