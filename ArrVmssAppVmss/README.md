# Web Farm With ARR and Application Servers
A common web farm architecture using ARR reverse proxy servers to delegate traffic to application servers.

64 bit Windows Server 2012 R2 or above is recommended. 64 bit Windows Server 2012 or above is **required**.

## Deployment Instructions

### Create a Storage Account

1. Navigate to the [Azure portal](https://portal.azure.com) and log in. 
1. [Create a storage account](https://docs.microsoft.com/en-us/azure/storage/common/storage-create-storage-account#create-a-storage-account) for storing virtual machine VHDs (Virtual Hard Disks) and IIS content.
    * If a storage account already exists it may be used for this guide.
    * All of the resources that are created will belong to the same resource group as the storage account.
    * **Important**: Use a storage account name that is 20 characters or less to be able to map the storage account to a local Windows user.

![CreateStorageAccount]

2. Select the _Blobs_ service for the storage account and create a [blob container](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction) named _images_ to store VHDs for the ARR and application servers.

![CreateBlobContainer]

3. Select the _Files_ service for the storage account and create a [file share](https://docs.microsoft.com/en-us/azure/storage/files/storage-how-to-create-file-share) to store IIS material such as shared configuration, certificates, and application content.
    * Use any name for the file share. The name will be used as a parameter in a later step.

![CreateFileShare]

4. Select the file share and create the following directories
    * AppServerConfig: This directory will be used to store shared configuration for the application servers.
    * ArrServerConfig: This directory will be used to store shared configuration for the ARR load balancing servers.
    * CentralCertStore: This directory will be used to store the certificates for the [IIS central certificate store](https://docs.microsoft.com/en-us/iis/get-started/whats-new-in-iis-8/iis-80-centralized-ssl-certificate-support-ssl-scalability-and-manageability).
    * Content: This directory will be used for web site content.

![FoldersCreated]    

### Prepare an Application Server VHD
1. Create a Hyper-V VM (Virtual Machine) using the desired Windows Server operating system. 
    * Make sure to use a **fix-sized** VHD with .vhd format rather than .vhdx.
    * Generally a smaller vhd is preferred because it will be uploaded to Azure faster
    * Virtual Machine settings such as network, memory limits, and cpu limits will not carry over when deployed to Azure
    * **Important**: Azure supports [only Generation 1 VMs](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/prepare-for-upload-vhd-image?toc=%2fazure%2fvirtual-machines%2fwindows%2ftoc.json). This is a setting that is configured when creating a VM in Hyper-V.
2. Boot the VM and install all desired utilities, applications, and frameworks.
    * Do not domain join the machine since the domain will not exist when the machine is moved to Azure
3. Configure installed utilities to desired state.
4. Enable IIS and all optional IIS features that will be required.
5. Install the [PowerShellGet](https://docs.microsoft.com/en-us/powershell/gallery/readme#supported-operating-systems) module
    * **Note:** PowerShellGet is installed by default on Windows 10 / Windows Server 2016
6. Install the [IISAdministration PowerShell module](https://www.powershellgallery.com/packages/IISAdministration/1.1.0.0) from the PS gallery by running the following command in an elevated PowerShell prompt
`
Install-Module -Name IISAdministration
`
7. Export the IIS Configuration to the Azure file share in a directory called _AppServerConfig_
    1. Open IIS Manager
    2. On the Web Server screen double-click _Shared Configuration_
    3. On the right hand side click _Export_ and choose a location to export IIS's configuration.
    4. Export it directly to the file share or export it to a local directory and then copy the content to the directory in the file share.
    5. Remember the password used for encrypting the shared configuration. It will be used as a **parameter during deployment**.
    * __Note:__ To access the file share from the virtual machine see the [Mounting Azure File Share](#mounting-azure-file-share-inside-a-vm) section below
    * When the application servers begin running in Azure they will import the shared configuration and start using it automatically. This configuration can be updated at any time either before or after deployment. For more info see the [configuration guide](#configuration-guide) section below.
8. Follow the steps listed on how to [Prepare a Windows VHD to upload to Azure](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/prepare-for-upload-vhd-image?toc=%2fazure%2fvirtual-machines%2fwindows%2ftoc.json) which includes **generalizing** the VHD.
* **Pitfall:** Make sure to disable IIS shared configuration and the central certificate store before generalizing because they require encrypted secrets that won't be available after generalization. Shared configuration and the central certificate store will be enabled automatically by a provisioning script when the VMs are deployed in Azure.

### Prepare an ARR (Load Balancing) Server VHD
1. Repeat **steps 1 - 6** from [Prepare an Application Server VHD](#prepare-an-application-server-vhd).
1. Download and install the IIS [Application Request Routing](https://www.iis.net/downloads/microsoft/application-request-routing) (ARR) module.
1. Export the IIS Configuration to the Azure file share as shown in **step 7** of [Prepare an Application Server VHD](#prepare-an-application-server-vhd). 
    * This time export to the _ArrServerConfig_ directory
    * Use the same password for encrypting the shared configuration.
1. Create a directory in the Azure file share named _CentralCertStore_ to act as the [IIS central certificate store](https://docs.microsoft.com/en-us/iis/get-started/whats-new-in-iis-8/iis-80-centralized-ssl-certificate-support-ssl-scalability-and-manageability)
    * The password needed to access the certificates in the central certificate store will be provided as a **parameter during deployment**.
1. Follow the steps listed on how to [Prepare a Windows VHD to upload to Azure](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/prepare-for-upload-vhd-image?toc=%2fazure%2fvirtual-machines%2fwindows%2ftoc.json) which includes **generalizing** the VHD.
* **Pitfall:** Make sure to disable IIS shared configuration and the central certificate store before generalizing because they require encrypted secrets that won't be available after generalization. Shared configuration and the central certificate store will be enabled automatically by a provisioning script when the VMs are deployed in Azure.

### Upload VHDs To Azure
 1. On the machine containing the VHDs install the [PowerShellGet](https://docs.microsoft.com/en-us/powershell/gallery/readme#supported-operating-systems) module.
    * **Note:** PowerShellGet is installed by default on Windows 10 / Windows Server 2016
 2. Install [Azure PowerShell](https://docs.microsoft.com/en-us/powershell/azure/install-azurerm-ps?view=azurermps-4.4.0&viewFallbackFrom=azurermps-4.3.1)
     * In elevated PowerShell run:
```
Set-ExecutionPolicy Unrestricted -Scope Process
Install-Module AzureRM
Import-Module AzureRM
Login-AzureRMAccount -Subscription "<Name of Subscription with Storage Account>" 
```

3. Use the _Add-AzureRmVhd_ command to upload the VHDs to Azure
    * In PowerShell run:
`
Add-AzureRmVhd -Destination https://<StorageAccountName>.blob.core.windows.net/images/<VhdName>.vhd -LocalFilePath <PathToVhd> -ResourceGroupName <Resource Group Name For Storage Account>
`
    * Notice how we used the images blob container we created in the very beginning

![AddAzureRmVhd]

### Deploy Resources To Azure
1. Download this directory to a machine that has [Azure PowerShell](https://docs.microsoft.com/en-us/powershell/azure/install-azurerm-ps?view=azurermps-4.4.0&viewFallbackFrom=azurermps-4.3.1) installed.
1. Open the [parameters.json](./parameters.json) file and fill out the parameters for the deployment.
1. Run the [deploy.ps1](./deploy.ps1) script
    * In PowerShell run:
`
.\deploy.ps1 -subscriptionId <SubscriptionId> -resourceGroupName <Resource Group Name For Storage Account> -deploymentName <PickAnyName>
`
1. Fill out the required secure parameters for the deployment. These will appear as prompts when the deployment script is executed:
    * vss_admin_password: The password to use for the built-in administrator account on the VM.
    * config_key_password: Password used to encrypt the shared configuration when exported during preparation of VHDs
    * cert_store_key_password: Password used to access private keys stored in the central certificate store

### Scale Up and Verify
The targeted Azure subscription should now contain all the desired resources. Navigate to the [Azure portal](https://portal.azure.com) to see the newly created resources. The [VM scale set]((https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-overview)) can be scaled up and down manually through the portal. By selecting the load balancer that has been deployed and inspecting the inbound NAT rules, an IP address and port can be obtained for connecting to one of the ARR scale set VMs via remote desktop. Only the load balancing servers are available through the public IP address. This narrows down the exposed surface area of the web farm which is beneficial to security. As a result, connecting to the application servers with remote desktop requires that a connection be established from one of the ARR machines.

![ResourcesCreated]

1. Verify the resources were created by viewing them in the Azure portal
    * 1 Load Balancer
    * 1 Public IP Address
    * 1 Virtual Network
    * 2 Images, 1 ending with 'AppServer' and 1 ending with 'LoadBalancer'
    * 2 Virtual Machine Scale Sets, 1 ending with 'Apps' and 1 ending with 'Lb'
2. Scale out the [virtual machine scale sets](https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-overview)
    1. Select the virtual machine scale set resource
    2. Select the _Scaling_ tab in the virtual machine scale set settings
    3. Increase the instances to the desired number and click save to finish scaling up the virtual machine scale set
    4. Check the _Instances_ tab to confirm that the instances are being created.
    4. Repeat for the other virtual machine scale set

![ScalingOut]

![ScalingOut3]

3. Verify VMs with remote desktop
    * The ARR servers are accessible through a public IP address, however to access the application servers a remote desktop session will need to be created from an ARR server
    1. Select the load balancer resource after scaling up the ARR server VM scale set
    2. Select the _Inbound NAT rules_ tab in the load balancer settings to find the IP Address and Ports that are available for remote desktop connections
        * By default the starting port is 50000 and the IP Address will be the IP address of the public IP that was created
    3. Connect using remote desktop to the IP Address and port combination found in the Inbound NAT rules
        * By selecting the virtual network resource, the private IP addresses of the application servers can be found and used to establish a remote desktop session from the ARR server session

![InboundNatRules]

![VnetDevices]

4. Verify IIS is serving HTTP requests
    * The VM scale set is accessible through an Azure allocated DNS name in the form of _\<IP address name\>.\<resource group location\>.cloudapp.azure.com_. ex: contoso.westus.cloudapp.azure.com
    * This information for connecting to the VM scale set through the internet is available in the Azure portal by selecting the public IP resource

![RequestToVmss]

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

![ArrServersListing]

* ARR Health checking should be configured to detect when the app server scale set performs auto scaling
    * A shorter health check interval means quicker identification of newly provisioned VMs
    * A shorter health check timeout means quicker identification of deallocated VMs

![ArrHealthTest]

* HTTPS bindings should be created to utilize the [IIS central certificate store](https://docs.microsoft.com/en-us/iis/get-started/whats-new-in-iis-8/iis-80-centralized-ssl-certificate-support-ssl-scalability-and-manageability)
    * The central certificate store is automatically enabled on VM provision by the [vssinit](../scripts/vssinit.ps1) script

![BindingConfiguration]

### Application Server Configuration

Application servers should be able to serve content for all the bindings that are registered on the ARR servers. Having web site content in a central location will allow application servers to scale in and out automatically while always having access to the latest content.

* Bindings should be created using the same hostnames that are used on the ARR servers
* Web sites should be configured to serve content from the Azure file share
    * The physical path should be accessed using the credentials of an Azure file share user
    * Username: storage account name
    * Password: storage account key

## Using Azure Files

Certain operations involving Azure files require a local user to exist with the credentials required to access the share. The provisioning script that is part of this deployment automatically creates this local user if it does not exist when VMs are created.

### Creating File Share User

1. Acquire a storage account key for the storage account that contains the file share
    1. Navigate to the storage account settings in the Azure Portal
    2. Go to the _Access keys_ tab to find the storage account keys associated with the account
2. Create local user with the following credentials
    * Username: The storage account name
    * Password: The storage account key
    * Run the following command from an elevated Command Prompt 
```
net user <username> <password> /ADD /Y
```

### Mounting Azure File Share inside a VM
1. Create a local user to access the file share as mentioned [above](#creating-file-share-user)
2. Run the following command from an elevated Command Prompt
```
net use G: \\<Storage Account Name>.file.core.windows.net\<File Share Name>  /u:<Storage Account Name> <Storage Account Key>
```

### Serving Web Site Content From Azure File Share
1. Create a local user to access the file share as mentioned [above](#creating-file-share-user)
2. Open IIS manager
3. Open the basic settings for the web site
4. Change the physical path to: 
`
\\<Storage Account Name>.file.core.windows.net\<File Share Name>
`
    * example: \\contoso.file.core.windows.net\MyIisFileShare
5. Click the _Connect As..._ button and fill out the form with the credentials for the local file share user

![WebSiteAzureFiles]

[AddAzureRmVhd]: imgs/AddAzureRmVhd.PNG "Uploading a VHD to azure"
[ArrHealthTest]: imgs/ArrHealthTest.PNG "Health check configuration for the IIS ARR module in the Azure web farm"
[ArrServersListing]: imgs/ArrServersListing.PNG "List of all configured backend application servers. Two are running"
[BindingConfiguration]: imgs/BindingConfiguration.PNG "Binding setup for ARR server"
[CreateBlobContainer]: imgs/CreateBlobContainer.PNG "Creating a blob container in the Azure Portal"
[CreateFileShare]: imgs/CreateFileShare.PNG "Creating a file share in the Azure Portal"
[CreateStorageAccount]: imgs/CreateStorageAccount.PNG "Creating a storage account in the Azure Portal"
[FoldersCreated]: imgs/FoldersCreated.PNG "All folders created for the deployment"
[InboundNatRules]: imgs/InboundNatRules.PNG "List of Network Address Translation (NAT) rules for the Azure Load Balancer"
[RequestToVmss]: imgs/RequestToVmss.PNG "HTTP request to validate the web farm servers are running"
[ResourcesCreated]: imgs/ResourcesCreated.PNG "All resources created by the deployment script"
[ScalingOut]: imgs/ScalingOut.PNG "Scaling out a VM scale set in the Azure Portal"
[ScalingOut3]: imgs/ScalingOut3.PNG "VM scale set instances indicating that they are finished provisioning"
[VnetDevices]: imgs/VnetDevices.PNG "All Azure virtual machines connected to the virtual network"
[WebSiteAzureFiles]: imgs/WebSiteAzureFiles.PNG "Setting up a web site to serve from an Azure file share"