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
* **Pitfall:** Make sure to disable IIS shared configuration and the central certificate store before generalizing because encrypted credentials are not preserved in generalization.

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
1. Create a directory in the Azure file share named _certs_ to act as the [IIS central certificate store](https://docs.microsoft.com/en-us/iis/get-started/whats-new-in-iis-8/iis-80-centralized-ssl-certificate-support-ssl-scalability-and-manageability)
1. Follow the steps listed on how to [Prepare a Windows VHD to upload to Azure](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/prepare-for-upload-vhd-image?toc=%2fazure%2fvirtual-machines%2fwindows%2ftoc.json) which includes **generalizing** the VHD.
* **Pitfall:** Make sure to disable IIS shared configuration and the central certificate store before generalizing because encrypted credentials are not preserved in generalization.

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
1. Open the [parameters.json](./parameters.json) file and fill out the parameters for the deployment.
2. Run the [deploy.ps1](./deploy.ps1) script
    * In PowerShell run:
`
.\deploy.ps1 -subscriptionId <SubscriptionId> -resourceGroupName <ResourceGroupName pick one if does not exist> -deploymentName <PickAnyName>
`

### Scale Up and Verify
The targeted Azure subscription should now contain all the desired resources. Navigate to the [Azure portal](https://portal.azure.com) to see the newly created resources. The VM Scale set can be scaled up and down manually through the portal. By selecting the load balancer that has been deployed and inspecting the inbound NAT rules, an IP address and port can be obtained for connecting to one of the scale set VMs via remote desktop.

## Configuration Guide

This webfarm strategy relies on IIS shared configuration stored in an Azure file share.

* The ARR and application servers should each use IIS shared configuration where the configuration is located on an Azure file share
* There should be two different configurations, one for all of the ARR servers and one for all of the application servers.
* The servers can be configured at any time either before deployment or afterwards once the machines have been allocated in Azure.
    * Since the machines are using shared configuration, a local desktop machine can be used to target the configuration and make all necessary adjustments. 
* A local user for accessing the shared configuration is created during VM provisioning on Azure by the [vssinit](../scripts/vssinit.ps1) script that is linked in the ARM template.
* To start using a shared configuration on Azure files a **local user** must exist with the following credentials:
    * Username: storage account name
    * Password: storage account key

### ARR Server Configuration

The ARR servers are set up to accept HTTPS connections from the Azure load balancer and then forward them to the application servers. These servers must be configured to be aware of what internal IP addresses the application servers are using. A health check should be configured so that the ARR servers can detect if the application server scale set has scaled in or out.

* An ARR server farm should be created to store the upstream servers
* All possible IP addresses for the application server scale set VMs should be listed as servers in the server farm
    * E.g. If the subnet prefix for app servers is 10.5.0.0/21 and 50 VMs are expected then the IP addresses 10.5.0.4 - 10.5.0.53 should be added to the server farm
* ARR Health checking should be configured to detect when the app server scale set performs auto scaling
    * A shorter health check interval means quicker identification of newly provisioned VMs
    * A shorter health check timeout means quicker identification of deallocated VMs
* HTTPS bindings should be created to utilize the [IIS central certificate store](https://docs.microsoft.com/en-us/iis/get-started/whats-new-in-iis-8/iis-80-centralized-ssl-certificate-support-ssl-scalability-and-manageability)
    * The central certificate store is automatically enabled on VM provision by the [vssinit](../scripts/vssinit.ps1) script

### Application Server Configuration

Application servers should be able to serve content for all the bindings that are registered on the ARR servers. Having web site content in a central location will allow application servers to scale in and out automatically while always having access to the latest content.

* Bindings should be created using the same hostnames that are used on the ARR servers
* Web sites should be configured to serve content from the Azure file share
    * The physical path should be accessed using the credentials of an Azure file share user
    * Username: storage account name
    * Password: storage account key

## Mounting Azure File Share inside a VM

1. Create local user with the following credentials
    * Username: The storage account name that contains the file share
    * Password: The storage account key for the specified account
2. Run the following command from an elevated Command Prompt
```
net use G: \\<Storage Account Name>.file.core.windows.net\<File Share Name>  /u:<Storage Account Name> <Storage Account Key>
```