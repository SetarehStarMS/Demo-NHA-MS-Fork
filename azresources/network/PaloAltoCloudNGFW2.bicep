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

// @description('virtual network ID that NGFW reside in')
// param vnetId string

// @description('Network configuration for the spoke virtual network.  It includes name, dnsServers, address spaces, vnet peering and subnets.')
// param network object

// @description('Network Type for NGFW: VNET or VWAN')
// param networkType string

@description('Whether to enable Source NAT for NGFW with different public IP Address.')
param sourceNATEnabled bool

// @description('If enableDnsProxy')
// param enableDnsProxy bool

@description('If enableDnsProxy')
param resourceGroupName string


resource ngfwManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'ngfw-managed-identity'
  location: location
}

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

// resource localRuleStacks 'PaloAltoNetworks.Cloudngfw/localRulestacks@2023-09-01' = {
//   name: '${name}-lrs'
//   location: location
//   properties: {
//     scope: 'LOCAL'
//     defaultMode: 'IPS'
//     securityServices: {
//         vulnerabilityProfile: 'BestPractice'
//         antiSpywareProfile: 'BestPractice'
//         antiVirusProfile: 'BestPractice'
//         urlFilteringProfile: 'BestPractice'
//         fileBlockingProfile: 'BestPractice'
//         dnsSubscription: 'BestPractice'
//     }
//  }
// }

resource localRuleStacksDeploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'Deploy--PaloAlto-cloud-NGFW-LocalRuleStacks'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${ngfwManagedIdentity.id}' : {}
    }
  }
  properties: {
    azPowerShellVersion: '10.4.1'
    arguments: '-Name ${name}-lrs -resourceGroupName ${resourceGroupName} -Location ${location}'
    scriptContent: '''
     param(
       [string] $Name, 
       [string] $resourceGroupName
       [string] $Location    
       )
             
     $localRuleStacks = New-AzPaloAltoNetworksLocalRulestack -Name $Name -ResourceGroupName $resourceGroupName -Location $location'
     $ResourceExists = $null -ne $localRuleStacks
     $DeploymentScriptOutputs = @{}
     $DeploymentScriptOutputs['Result'] = $ResourceExists
     '''
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
}

// var networkProfile = [
//   {
//     networkProfile: {
//       vnetConfiguration: {
//         vnet: {
//           resourceId: vnetId
//         }
//         trustSubnet: {
//           resourceId: '/subscriptions/83b401c0-df5f-48fa-80c2-7087954217e8/resourceGroups/nha-hub-networking/providers/Microsoft.Network/virtualNetworks/hub-vnet/subnets/NGFWPrivateSubnet'
//         }
//         unTrustSubnet: {
//           resourceId: '/subscriptions/83b401c0-df5f-48fa-80c2-7087954217e8/resourceGroups/nha-hub-networking/providers/Microsoft.Network/virtualNetworks/hub-vnet/subnets/NGFWPublicSubnet'
//         }
//         ipOfTrustSubnetForUdr: {
//           address: '10.18.2.1'
//         }
        
//       }
//       networkType: networkType
//       publicIps: [
//         {
//           resourceId: '/subscriptions/83b401c0-df5f-48fa-80c2-7087954217e8/resourceGroups/nha-hub-networking/providers/Microsoft.Network/publicIPAddresses/nha-hub-PaloAltoCloudNGFW-PublicIp'
//         }
//       ]
//       enableEgressNat: 'DISABLED'
//       egressNatIp: sourceNATEnabled ? [
//         {
//           resourceId: '/subscriptions/83b401c0-df5f-48fa-80c2-7087954217e8/resourceGroups/nha-hub-networking/providers/Microsoft.Network/publicIPAddresses/nha-hub-PaloAltoCloudNGFW-SourceNAT-PublicIp'
//         }
//       ]: null
//     }
//   }
// ]

// resource ngfwDeploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
//   name: 'Deploy--PaloAlto-cloud-NGFW'
//   location: location
//   kind: 'AzurePowerShell'
//   identity: {
//     type: 'UserAssigned'
//     userAssignedIdentities: {
//       '${ngfwManagedIdentity.id}' : {}
//     }
//   }
//   properties: {
//     azPowerShellVersion: '10.4.1'
//     arguments: '-Name ${name} -resourceGroupName ${resourceGroupName} -Location ${location} -NetworkProfile ${networkProfile} -AssociatedRulestackResourceId ${localRuleStacks.id} -AssociatedRulestackLocation ${location} -DnsSettingEnableDnsProxy DISABLED -DnsSettingEnabledDnsType CUSTOM -MarketplaceDetailOfferId "pan_swfw_cloud_ngfw" -MarketplaceDetailPublisherId "paloaltonetworks" -PlanDataBillingCycle "MONTHLY" -PlanDataPlanId "panw-cloud-ngfw-payg" '
//     scriptContent: '''
//      param(
//        [string] $Name, 
//        [string] $resourceGroupName
//        [string] $Location
//        [INetworkProfile] $NetworkProfile
//        [string] $AssociatedRulestackResourceId
//        [string] $AssociatedRulestackLocation
//        [EnabledDnsType] $DnsSettingEnabledDnsType
//        [DnsProxy] $DnsSettingEnableDnsProxy
//        [string] $MarketplaceDetailOfferId
//        [string] $MarketplaceDetailPublisherId 
//        [BillingCycle] $PlanDataBillingCycle
//        [string] $PlanDataPlanId
//        )
    
//      Write-Host $NetworkProfile
//      $PaloAltoClloudNGFW = New-AzPaloAltoNetworksFirewall -Name $Name -ResourceGroupName $resourceGroupName -Location $location -NetworkProfile $networkProfile -AssociatedRulestackId $AssociatedRulestackResourceId -AssociatedRulestackLocation $AssociatedRulestackLocation -DnsSettingEnabledDnsType $DnsSettingEnabledDnsType -DnsSettingEnableDnsProxy $DnsSettingEnableDnsProxy -MarketplaceDetailOfferId $MarketplaceDetailOfferId -MarketplaceDetailPublisherId $MarketplaceDetailPublisherId -PlanDataBillingCycle $PlanDataBillingCycle -PlanDataPlanId $PlanDataPlanId
//      $ResourceExists = $null -ne $PaloAltoClloudNGFW
//      $DeploymentScriptOutputs = @{}
//      $DeploymentScriptOutputs['Result'] = $ResourceExists
//      '''
//     cleanupPreference: 'OnSuccess'
//     retentionInterval: 'P1D'
//   }
// }


// resource paloAltoCloudNGFWFirewall 'PaloAltoNetworks.Cloudngfw/firewalls@2023-09-01' = {
//   name: name
//   location: location
//   properties: {
//     networkProfile: {
//       vnetConfiguration: {
//         vnet: {
//           resourceId: vnetId
//         }
//         trustSubnet: {
//           resourceId: network.subnets.ngfwPrivateSubnet.id
//         }
//         unTrustSubnet: {
//           resourceId: network.subnets.ngfwPublicSubnet.id
//         }
//         ipOfTrustSubnetForUdr: {
//           address: network.subnets.ngfwPrivateSubnet.properties.addressPrefixes[0]
//         }
        
//       }
//       networkType: networkType
//       publicIps: [
//         {
//           resourceId: ngfwPublicIp.id
//         }
//       ]
//       enableEgressNat: '${sourceNATEnabled}'
//       egressNatIp: sourceNATEnabled ? [
//         {
//           resourceId: sourceNATPublicIp.id
//         }
//       ]: null
//     }
//     associatedRulestack: {
//       resourceId: localRuleStacks.id
//       location: location
//       // rulestackId: 'SUBSCRIPTION~dbf14654-41b8-4a18-bcdd-a200d053975f~RG~nha-hub-networking~STACK~nha-hub-PaloAltoCloudNGFW-lrs'    
//     }
//     dnsSettings: {
//       enableDnsProxy: '${enableDnsProxy}'
//       enabledDnsType: 'CUSTOM'
//     }
//     isPanoramaManaged: 'FALSE'
//     planData: {
//       usageType: 'PAYG'
//       billingCycle: 'MONTHLY'
//       planId: 'panw-cloud-ngfw-payg'
//     }
//     marketplaceDetails: {
//       offerId: 'pan_swfw_cloud_ngfw'
//       publisherId: 'paloaltonetworks'
//     }
//   }
  
// }

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
  
