# AzureWebFarm
Templates and documentation for moving existing IIS infrastructure to Azure

## [Web Farm With ARR and Application Servers](./ArrVmssAppVmss)
This guide can be used to bring a web farm to Azure that relies on the IIS ARR reverse proxy, central certificate store, shared configuration, and file shares. There is an [existing ARM template](https://github.com/Azure/azure-quickstart-templates/tree/master/201-vmss-win-iis-app-ssl) in the ARM examples gallery that demonstrates how vm scale sets can be allocated in Azure. The approach found here expands upon the example by focusing on the minimal set of requirements to get a common on-premise webfarm to Azure. This is acheived by enabling custom fitted VHDs, file shares, and common IIS features like shared configuration. The VHDs used as base images for the vm scale sets can contain whatever applications and frameworks that are required.

### Architecture Summary
* Application layer load balancing via ARR servers on an Azure VM scale set
* Scalable application servers running on a separate VM scale set
* Shared content located in an Azure file share
* Centrally managed certificates in IIS central certificate store located in an Azure file share
* Shared configurations for the ARR VM scale set and the application server vm scale set

### Deployment steps summary
1. Create an Azure subscription + storage account
1. Prepare an application server vhd
1. Prepare an ARR proxy server vhd
1. Upload required vhds to Azure
1. Run the [deployment script](./ArrVmssAppVmss/deploy.ps1)

For a full list of instructions and explanations refer to [this walkthrough](./ArrVmssAppVmss).