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

@description('virtual network ID that NGFW reside in')
param vnetId string

// @description('Network configuration for the spoke virtual network.  It includes name, dnsServers, address spaces, vnet peering and subnets.')
// param network object

@description('Network Type for NGFW: VNET or VWAN')
param networkType string

@description('Whether to enable Source NAT for NGFW with different public IP Address.')
param sourceNATEnabled bool

// @description('If enableDnsProxy')
// param enableDnsProxy bool


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

resource localRuleStacks 'PaloAltoNetworks.Cloudngfw/localRulestacks@2023-09-01' = {
  name: '${name}-lrs'
  location: location
  properties: {
    scope: 'LOCAL'
    defaultMode: 'IPS'
    securityServices: {
        vulnerabilityProfile: 'BestPractice'
        antiSpywareProfile: 'BestPractice'
        antiVirusProfile: 'BestPractice'
        urlFilteringProfile: 'BestPractice'
        fileBlockingProfile: 'BestPractice'
        dnsSubscription: 'BestPractice'
    }
 }
}

resource paloAltoCloudNGFWFirewall 'PaloAltoNetworks.Cloudngfw/firewalls@2023-09-01' = {
  name: name
  location: location
  properties: {
    networkProfile: {
      vnetConfiguration: {
        vnet: {
          resourceId: vnetId
        }
        trustSubnet: {
          resourceId: '/subscriptions/dbf14654-41b8-4a18-bcdd-a200d053975f/resourceGroups/nha-hub-networking/providers/Microsoft.Network/virtualNetworks/hub-vnet/subnets/NGFWPrivateSubnet'
        }
        unTrustSubnet: {
          resourceId: '/subscriptions/dbf14654-41b8-4a18-bcdd-a200d053975f/resourceGroups/nha-hub-networking/providers/Microsoft.Network/virtualNetworks/hub-vnet/subnets/NGFWPublicSubnet'
        }
        ipOfTrustSubnetForUdr: {
          address: '10.18.2.1'
        }
        
      }
      networkType: networkType
      publicIps: [
        {
          resourceId: '/subscriptions/dbf14654-41b8-4a18-bcdd-a200d053975f/resourceGroups/nha-hub-networking/providers/Microsoft.Network/publicIPAddresses/nha-hub-PaloAltoCloudNGFW-PublicIp'
        }
      ]
      enableEgressNat: 'ENABLED'
      egressNatIp: sourceNATEnabled ? [
        {
          resourceId: '/subscriptions/dbf14654-41b8-4a18-bcdd-a200d053975f/resourceGroups/nha-hub-networking/providers/Microsoft.Network/publicIPAddresses/nha-hub-PaloAltoCloudNGFW-SourceNAT-PublicIp'
        }
      ]: null
    }
    associatedRulestack: {
      resourceId: localRuleStacks.id
      location: location
      // rulestackId: 'SUBSCRIPTION~dbf14654-41b8-4a18-bcdd-a200d053975f~RG~nha-hub-networking~STACK~nha-hub-PaloAltoCloudNGFW-lrs'    
    }
    dnsSettings: {
      enableDnsProxy: 'DISABLED'
      enabledDnsType: 'CUSTOM'
    }
    isPanoramaManaged: 'FALSE'
    planData: {
      usageType: 'PAYG'
      billingCycle: 'MONTHLY'
      planId: 'panw-cloud-ngfw-payg'
    }
    marketplaceDetails: {
      offerId: 'pan_swfw_cloud_ngfw'
      publisherId: 'paloaltonetworks'
    }
  }
  
}

// resource paloAltoFirewall 'PaloAltoNetworks.Cloudngfw/firewalls@2023-09-01' = {
//   name: name
//   location: location
//   properties: {
//     networkProfile: {
//         vnetConfiguration: {
//             vnet: {
//                 resourceId: '/subscriptions/7d5b86f5-567f-4ad6-afdd-4b2bd0ae63ee/resourceGroups/nh-cc-rg-lab-hub-networking-01/providers/Microsoft.Network/virtualNetworks/nh-cc-lab-vnet-hybridhub-01'
//             },
//             trustSubnet: {
//                 resourceId: '/subscriptions/7d5b86f5-567f-4ad6-afdd-4b2bd0ae63ee/resourceGroups/nh-cc-rg-lab-hub-networking-01/providers/Microsoft.Network/virtualNetworks/nh-cc-lab-vnet-hybridhub-01/subnets/nh-cc-lab-snet-ngfw-private-01'
//             },
//             unTrustSubnet: {
//                 resourceId: '/subscriptions/7d5b86f5-567f-4ad6-afdd-4b2bd0ae63ee/resourceGroups/nh-cc-rg-lab-hub-networking-01/providers/Microsoft.Network/virtualNetworks/nh-cc-lab-vnet-hybridhub-01/subnets/nh-cc-lab-snet-ngfw-public-01'
//             },
//             ipOfTrustSubnetForUdr: {
//                 address: '10.242.128.132'
//             }
//         },
//         networkType: 'VNET',
//         publicIps: [
//             {
//                 resourceId: '/subscriptions/7d5b86f5-567f-4ad6-afdd-4b2bd0ae63ee/resourceGroups/nh-cc-rg-lab-hub-networking-01/providers/Microsoft.Network/publicIPAddresses/nh-cc-lab-hub-PaloAltoCloudNGFW-pip-01',
//                 address: '20.220.245.146'
//             }
//         ],
//         enableEgressNat: 'ENABLED',
//         egressNatIp: [
//             {
//                 resourceId: '/subscriptions/7d5b86f5-567f-4ad6-afdd-4b2bd0ae63ee/resourceGroups/nh-cc-rg-lab-hub-networking-01/providers/Microsoft.Network/publicIPAddresses/nh-cc-lab-hub-PaloAltoCloudNGFW-sourcenat-pip-01',
//                 address: '20.220.246.2'
//             }
//         ]
//     },
//     associatedRulestack: {
//         resourceId: '/subscriptions/7d5b86f5-567f-4ad6-afdd-4b2bd0ae63ee/resourceGroups/nh-cc-rg-lab-hub-networking-01/providers/PaloAltoNetworks.Cloudngfw/localRulestacks/nh-cc-lab-hub-PaloAltoCloudNGFW-lrs',
//         location: location,
//         rulestackId: 'SUBSCRIPTION~7d5b86f5-567f-4ad6-afdd-4b2bd0ae63ee~RG~nh-cc-rg-lab-hub-networking-01~STACK~nh-cc-lab-hub-PaloAltoCloudNGFW-lrs'
//     },
//     dnsSettings: {
//         enableDnsProxy: 'DISABLED',
//         enabledDnsType: 'CUSTOM'
//     },
//     isPanoramaManaged: 'FALSE',
//     provisioningState: 'Succeeded',
//     planData: {
//         usageType: 'PAYG',
//         billingCycle: 'MONTHLY',
//         planId: 'panw-cloud-ngfw-payg',
//         effectiveDate: '0001-01-01T00:00:00Z'
//     },
//     marketplaceDetails: {
//         offerId: 'pan_swfw_cloud_ngfw',
//         publisherId: 'paloaltonetworks',
//         marketplaceSubscriptionStatus: 'Subscribed',
//         marketplaceSubscriptionId: 'd7301fc7-f123-4d61-dd41-14c369e02405'
//     },
//     panEtag: '45315dfe-8409-11ee-a79b-9e7061a6911e'
// }
  
