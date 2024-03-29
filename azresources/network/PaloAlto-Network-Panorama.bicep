// ----------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.
//
// THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
// EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES 
// OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
// ----------------------------------------------------------------------------------

@description('Location for the deployment.')
param location string = resourceGroup().location

@description('Virtual Machine Name.')
param vmName string

@description('Virtual Machine SKU.')
param vmSize string

// Credentials
@description('Virtual Machine Username.')
@secure()
param username string

@description('Virtual Machine Password')
@secure()
param password string

// Networking
@description('Subnet Resource Id.')
param subnetId string

param availID string

resource PanoramaPIP 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: '${vmName}-pip-01'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

param privateIPAddress string

resource nic 'Microsoft.Network/networkInterfaces@2020-06-01' = {
    name: '${vmName}-nic-01'
    location: location
    properties: {
        ipConfigurations: [
            {
                name: 'ipconfig1'
                properties: {
                    subnet: {
                        id: subnetId
                    }
                    publicIPAddress: {
                      id: PanoramaPIP.id
                    }
                    privateIPAllocationMethod: 'Static'
                    privateIPAddress: privateIPAddress
                    privateIPAddressVersion: 'IPv4'
                    primary: true
                }
            }
        ]
    }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
    name: vmName
    location: location
    plan: {
      name: 'byol'
      publisher: 'paloaltonetworks'
      product: 'panorama'
    }
    properties: {
        hardwareProfile: {
            vmSize: vmSize
        }
        availabilitySet: {
          id: availID
        }
        networkProfile: {
            networkInterfaces: [
                {
                    id: nic.id
                }
            ]
        }
        storageProfile: {
            imageReference: {
                publisher: 'paloaltonetworks'
                offer: 'panorama'
                sku: 'byol'
                version: '10.2.3'
                
            }
            osDisk: {
                name: '${vmName}-os'
                caching: 'ReadWrite'
                createOption: 'FromImage'
                managedDisk: {
                    storageAccountType: 'Premium_LRS'
                }
            }
            dataDisks: [
                {
                    caching: 'None'
                    name: '${vmName}-data-1'
                    diskSizeGB: 2048
                    lun: 0
                    managedDisk: {
                        storageAccountType: 'Premium_LRS'                        
                    }
                    createOption: 'Empty'
                }
            ]
        }
        osProfile: {
            computerName: vmName
            adminUsername: username
            adminPassword: password
        }
    }
}

// Outputs
output vmName string = vm.name
output vmId string = vm.id
output nicId string = nic.id
