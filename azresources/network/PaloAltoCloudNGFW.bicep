// ----------------------------------------------------------------------------------
// THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
// EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES 
// OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
// ----------------------------------------------------------------------------------
@description('Location for the deployment.')
param location string = resourceGroup().location

@description('Azure Firewall Name')
param name string

@description('Availability Zones to deploy Azure Firewall.')
param zones array

// @description('Subnet Id for AzureFirewallSubnet.')
// param firewallSubnetId string

// @description('Subnet Id for AzureFirewallManagementSubnet.')
// param firewallManagementSubnetId string

@description('Whether to enable Source NAT for NGFW with different public IP Address.')
param sourceNATEnabled bool

// @description('Existing Firewall Policy Resource Id')
// param existingFirewallPolicyId string

resource ngfwPublicIp 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: '${name}-PublicIp'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: !empty(zones) ? zones : null
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource sourceNATPublicIp 'Microsoft.Network/publicIPAddresses@2021-02-01' = if (sourceNATEnabled) {
  name: '${name}-SourceNAT-PublicIp'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: !empty(zones) ? zones : null
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// resource firewall 'Microsoft.Network/azureFirewalls@2021-02-01' = {
//   name: name
//   location: location
//   zones: !empty(zones) ? zones : null
//   properties: {
//     sku: {
//       name: 'AZFW_VNet'
//       tier: 'Premium'
//     }
//     firewallPolicy: {
//       id: existingFirewallPolicyId
//     }
//     ipConfigurations: [
//       {
//         name: 'ipConfig'
//         properties: {
//           subnet: {
//             id: firewallSubnetId
//           }
//           publicIPAddress: !forcedTunnelingEnabled ? {
//             id: firewallPublicIp.id
//           } : null
//         }
//       }
//     ]
//     managementIpConfiguration: forcedTunnelingEnabled ? {
//       name: 'managementIpConfig'
//       properties: {
//         subnet: {
//           id: firewallManagementSubnetId
//         }
//         publicIPAddress: {
//           id: firewallManagementPublicIp.id
//         }
//       }
//     } : null
//   }
// }


// Outputs
// output firewallId string = firewall.id
// output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
