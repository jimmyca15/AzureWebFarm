# Web Farm With ARR and Application Servers
A common web farm architecture using ARR reverse proxy servers to delegate traffic to application servers.

## Deployment Instructions

### Create a Storage Account

1. Navigate to the [Azure portal](https://portal.azure.com) and [create a storage account](https://docs.microsoft.com/en-us/azure/storage/common/storage-create-storage-account#create-a-storage-account) for storing virtual machine VHDs and IIS content.
1. In the storage account create a [blob container](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction) named _images_ to store VHDs for the ARR and application servers.
1. In the storage account create a [file share](https://docs.microsoft.com/en-us/azure/storage/files/storage-how-to-create-file-share) to store IIS material such as shared configuration, certificates, and application content.

### Prepare an Application Server VHD
1. Create a VM using the desired server OS. If creating the VM locally make sure to use a **fix-sized** VHD with .vhd form rather than .vhdx.
1. Boot the VM and install all desired utilities, applications, and frameworks.
1. Configure installed utilities to desired state.
1. Enable IIS and all optional IIS features that will be required.
1. Install the [PowerShellGet](https://docs.microsoft.com/en-us/powershell/gallery/readme#supported-operating-systems) module
1. Install the [IISAdministration PowerShell module](https://www.powershellgallery.com/packages/IISAdministration/1.1.0.0) from the PS gallery by running the following command in an elevated PowerShell prompt
`
Install-Module -Name IISAdministration
`
1. Export the IIS Configuration to the Azure file share in a directory called _AppServerConfig_
    1. Open IIS Manager
    2. On the Web Server screen double-click _Shared Configuration_
    3. On the right hand side click _Export_ and choose a location to export IIS's configuration. Either export it directly to the file share or export it to a local directory and then copy the content to the directory in the file share.
    * __Note:__ To access the file share from the virtual machine see the _Mounting Azure File Share_ section below
1. Follow the steps listed on how to [Prepare a Windows VHD to upload to Azure](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/prepare-for-upload-vhd-image?toc=%2fazure%2fvirtual-machines%2fwindows%2ftoc.json) which includes **generalizing** the VHD.
* **Pitfall:** Make sure not to enable IIS shared configuration or the central certificate store before generalizing as encrypted credentials are not preserved in generalization.

### Prepare an ARR (Load Balancing) Server VHD
1. Create a VM using the desired server OS. If creating the VM locally make sure to use a **fix-sized** VHD with .vhd form rather than .vhdx.
1. Boot the VM and install all desired utilities, applications, and frameworks.
1. Configure installed utilities to desired state.
1. Enable IIS and all optional IIS features that will be required.
1. Download and install the IIS [Application Request Routing](https://www.iis.net/downloads/microsoft/application-request-routing) (ARR) module.
1. Install the [PowerShellGet](https://docs.microsoft.com/en-us/powershell/gallery/readme#supported-operating-systems) module.
1. Install the [IISAdministration PowerShell module](https://www.powershellgallery.com/packages/IISAdministration/1.1.0.0) from the PS gallery by running the following command in an elevated PowerShell prompt
`
Install-Module -Name IISAdministration
`
1. Export the IIS Configuration to the Azure file share in a directory called _ArrServerConfig_
    1. Open IIS Manager
    2. On the Web Server screen double-click _Shared Configuration_
    3. On the right hand side click _Export_ and choose a location to export IIS's configuration. Either export it directly to the file share or export it to a local directory and then copy the content to the directory in the file share.
    * __Note:__ To access the file share from the virtual machine see the _Mounting Azure File Share_ section below
1. Follow the steps listed on how to [Prepare a Windows VHD to upload to Azure](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/prepare-for-upload-vhd-image?toc=%2fazure%2fvirtual-machines%2fwindows%2ftoc.json) which includes **generalizing** the VHD.
* **Pitfall:** Make sure not to enable IIS shared configuration or the central certificate store before generalizing as encrypted credentials are not preserved in generalization.

### Upload VHDs To Azure
 1. On the machine containing the VHDS install the [PowerShellGet](https://docs.microsoft.com/en-us/powershell/gallery/readme#supported-operating-systems) module.
 1. Install [Azure PowerShell](https://docs.microsoft.com/en-us/powershell/azure/install-azurerm-ps?view=azurermps-4.4.0&viewFallbackFrom=azurermps-4.3.1)
     * In elevated PowerShell run:
`
Install-Module AzureRM
`
     * In elevated PowerShell run:
`
Import-Module AzureRM
`

1. Use the _Add-AzureRmVhd_ command to upload the VHDs to Azure
    * In PowerShell run:
`
Add-AzureRmVhd -Destination https://<StorageAccountName>.blob.core.windows.net/images/<VhdName>.vhd -LocalFilePath <PathToVhd> -ResourceGroupName <ResourceGroupName>
`
    * Notice how we used the images blob container we created in the very beginning

### Deploy Resources To Azure
1. Download this directory to a machine that has [Azure PowerShell](https://docs.microsoft.com/en-us/powershell/azure/install-azurerm-ps?view=azurermps-4.4.0&viewFallbackFrom=azurermps-4.3.1) installed.
1. Open the parameters.json file and fill out the parameters for the deployment.
2. Run the deploy.ps1 script
    * In PowerShell run:
`
.\deploy.ps1 -subscriptionId <SubscriptionId> -resourceGroupName <ResourceGroupName pick one if does not exist> -deploymentName <PickAnyName>
`

### Scale Up and Verify
The targeted Azure subscription should now contain all the desired resources. Navigate to the [Azure portal](https://portal.azure.com) to see the newly created resources. The VM Scale set can be scaled up and down manually through the portal. By selecting the load balancer that has been deployed and inspecting the inbound NAT rules, an IP address and port can be obtained for connecting to one of the scale set VMs via remote desktop.
    

## Mounting Azure File Share inside a VM

1. Create local user with the following credentials
    * Username: The storage account name that contains the file share
    * Password: The storage account key for the specified account
2. Run the following command from an elevated Command Prompt
```
net use G: \\<Storage Account Name>.file.core.windows.net\<File Share Name>  /u:<Storage Account Name> <Storage Account Key>
```