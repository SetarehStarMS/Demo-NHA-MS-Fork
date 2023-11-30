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

@description('Network configuration for the hub virtual network.  It includes name, dnsServers, address spaces, vnet peering and subnets.')
param network object

@description('Network Type for NGFW: VNET or VWAN')
param networkType string

@description('Whether to enable Source NAT for NGFW with different public IP Address.')
param sourceNATEnabled bool

@description('If enableDnsProxy')
param enableDnsProxy string

@description('resourceGroupName')
param resourceGroupName string

@description('ipOfTrustSubnetForUdr')
param ipOfTrustSubnetForUdr string

// @description('logAnalyticsWorkspaceResourceId')
// param logAnalyticsWorkspaceResourceId string

// Create Log Analytics Workspace for PaloAlto Cloud NGFW
resource workspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: '${name}-log'
  location: location
  properties: {
    sku: {
      name: 'PerNode'
    }
    retentionInDays: 730
  }
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

resource lrs 'PaloAltoNetworks.Cloudngfw/localRulestacks@2023-09-01' existing = {
  name: '${name}-lrs'
  scope: resourceGroup(resourceGroupName)
}
output LocalRuleStackID string = lrs.id

resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing ={
  name: network.name
  scope: resourceGroup(resourceGroupName)
}

resource ngfwPriavteSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing =  {
  name : network.subnets.ngfwPrivateSubnet.name
  parent: vnet
}
output ngfwPriavteSubnetResourceId string = ngfwPriavteSubnet.id

resource ngfwPublicSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing =  {
  name : network.subnets.ngfwPublicSubnet.name
  parent: vnet
}
output ngfwPublicSubnetResourceId string = ngfwPublicSubnet.id

resource ngfwPip 'Microsoft.Network/publicIPAddresses@2021-02-01' existing = {
  name: ngfwPublicIp.name
  scope: resourceGroup(resourceGroupName)
}
output ngfwPipResourceID string = ngfwPip.id

resource ngfwSourceNATPip 'Microsoft.Network/publicIPAddresses@2021-02-01' existing = {
  name: sourceNATPublicIp.name
  scope: resourceGroup(resourceGroupName)
}
output ngfwSourceNATPipResourceID string = ngfwSourceNATPip.id

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
          
          resourceId: ngfwPriavteSubnet.id
        }
        unTrustSubnet: {
          
          resourceId: ngfwPublicSubnet.id
        }
        ipOfTrustSubnetForUdr: {
          address: ipOfTrustSubnetForUdr
        }
        
      }
      networkType: networkType
      publicIps: [
        {
          
          resourceId: ngfwPip.id
        }
      ]
      enableEgressNat: sourceNATEnabled? 'ENABLED' : 'DISABLED'
      egressNatIp: sourceNATEnabled ? [
        {
          
          resourceId: ngfwSourceNATPip.id
        }
      ]: null
    }
    associatedRulestack: {
      resourceId: lrs.id
      location: location      
    }
    dnsSettings: {
      enableDnsProxy: enableDnsProxy
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

output ngfwResourceId string = paloAltoCloudNGFWFirewall.id
