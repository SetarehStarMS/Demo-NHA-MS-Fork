// ----------------------------------------------------------------------------------
// THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
// EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES 
// OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
// ----------------------------------------------------------------------------------
@description('Location for the deployment.')
param location string = resourceGroup().location

@description('VPN Gateway Name')
param name string

@description('Availability Zones to deploy Azure Firewall.')
param zones array

@description('Required. Virtual Network resource ID.')
param vNetResourceId string

@description('Optional. Specifies the name of the Public IP used by the Virtual Network Gateway. If it\'s not provided, a \'-pip\' suffix will be appended to the gateway\'s name.')
param gatewayPipName string = '${name}-pip1'

@description('Optional. Specifies the name of the Public IP used by the Virtual Network Gateway when active-active configuration is required. If it\'s not provided, a \'-pip\' suffix will be appended to the gateway\'s name.')
param activeGatewayPipName string = '${name}-pip2'

@description('Optional. Value to specify if the Gateway should be deployed in active-active or active-passive configuration.')
param activeActive bool = false

@description('Required. Specifies the gateway type. E.g. VPN, ExpressRoute.')
@allowed([
  'Vpn'
  'ExpressRoute'
])
param gatewayType string

@description('Optional. The generation for this VirtualNetworkGateway. Must be None if virtualNetworkGatewayType is not VPN.')
@allowed([
  'Generation1'
  'Generation2'
  'None'
])
param vpnGatewayGeneration string = 'Generation2'

@description('Required. The SKU of the Gateway.')
@allowed([
  'Basic'
  'VpnGw1'
  'VpnGw2'
  'VpnGw3'
  'VpnGw4'
  'VpnGw5'
  'VpnGw1AZ'
  'VpnGw2AZ'
  'VpnGw3AZ'
  'VpnGw4AZ'
  'VpnGw5AZ'
  'Standard'
  'HighPerformance'
  'UltraPerformance'
  'ErGw1AZ'
  'ErGw2AZ'
  'ErGw3AZ'
])
param skuName string

@description('Optional. Specifies the VPN type.')
@allowed([
  'PolicyBased'
  'RouteBased'
])
param vpnType string = 'RouteBased'

@description('Optional. Value to specify if BGP is enabled or not.')
param enableBgp bool = false

@description('Optional. ASN value.')
param asn int = 65815

@description('Optional. Configures this gateway to accept traffic from remote Virtual WAN networks.')
param allowVirtualWanTraffic bool = false

@description('Optional. Configure this gateway to accept traffic from other Azure Virtual Networks. This configuration does not support connectivity to Azure Virtual WAN.')
param allowRemoteVnetTraffic bool = false

@description('Optional. disableIPSecReplayProtection flag. Used for VPN Gateways.')
param disableIPSecReplayProtection bool = false

@description('Optional. Whether private IP needs to be enabled on this gateway for connections or not. Used for configuring a Site-to-Site VPN connection over ExpressRoute private peering.')
param enablePrivateIpAddress bool = false

@description('Optional. EnableBgpRouteTranslationForNat flag. Can only be used when "natRules" are enabled on the Virtual Network Gateway.')
param enableBgpRouteTranslationForNat bool = false

@description('Optional. Whether DNS forwarding is enabled or not and is only supported for Express Route Gateways. The DNS forwarding feature flag must be enabled on the current subscription.')
param enableDnsForwarding bool = false

@description('Optional. The reference to the LocalNetworkGateway resource which represents local network site having default routes. Assign Null value in case of removing existing default site setting.')
param gatewayDefaultSiteLocalNetworkGatewayId string = ''


// ================//
// Variables       //
// ================//

// Other Variables
var zoneRedundantSkus = [
  'VpnGw1AZ'
  'VpnGw2AZ'
  'VpnGw3AZ'
  'VpnGw4AZ'
  'VpnGw5AZ'
  'ErGw1AZ'
  'ErGw2AZ'
  'ErGw3AZ'
]

var gatewayPipSku = contains(zoneRedundantSkus, skuName) ? 'Standard' : 'Basic'
var gatewayPipAllocationMethod = contains(zoneRedundantSkus, skuName) ? 'Static' : 'Dynamic'

var isActiveActiveValid = gatewayType != 'ExpressRoute' ? activeActive : false
var virtualGatewayPipNameVar = isActiveActiveValid ? [
  gatewayPipName
  activeGatewayPipName
] : [
  gatewayPipName
]

var vpnTypeVar = gatewayType != 'ExpressRoute' ? vpnType : 'PolicyBased'

var isBgpValid = gatewayType != 'ExpressRoute' ? enableBgp : false
var bgpSettings = {
  asn: asn
}


// Potential configurations (active-active vs active-passive)
var ipConfiguration = isActiveActiveValid ? [
  {
    properties: {
      privateIPAllocationMethod: 'Dynamic'
      subnet: {
        id: '${vNetResourceId}/subnets/GatewaySubnet'
      }
      publicIPAddress: {
        id: az.resourceId('Microsoft.Network/publicIPAddresses', gatewayPipName)
      }
    }
    name: 'vNetGatewayConfig1'
  }
  {
    properties: {
      privateIPAllocationMethod: 'Dynamic'
      subnet: {
        id: '${vNetResourceId}/subnets/GatewaySubnet'
      }
      publicIPAddress: {
        id: isActiveActiveValid ? az.resourceId('Microsoft.Network/publicIPAddresses', activeGatewayPipName) : az.resourceId('Microsoft.Network/publicIPAddresses', gatewayPipName)
      }
    }
    name: 'vNetGatewayConfig2'
  }
] : [
  {
    properties: {
      privateIPAllocationMethod: 'Dynamic'
      subnet: {
        id: '${vNetResourceId}/subnets/GatewaySubnet'
      }
      publicIPAddress: {
        id: az.resourceId('Microsoft.Network/publicIPAddresses', gatewayPipName)
      }
    }
    name: 'vNetGatewayConfig1'
  }
]


// ================//
// Deployments     //
// ================//

// Public IPs
@batchSize(1)
resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2023-05-01' = [for (virtualGatewayPublicIpName, index) in virtualGatewayPipNameVar: {
  name: virtualGatewayPublicIpName
  location: location
  sku: {
    name: gatewayPipSku
    tier: 'Regional'
  }
  zones: !empty(zones) ? zones : null
  properties: {
    publicIPAllocationMethod: gatewayPipAllocationMethod
  }
}]


// VNET Gateway
// ============
resource virtualNetworkGateway 'Microsoft.Network/virtualNetworkGateways@2023-04-01' = {
  name: name
  location: location
  properties: {
    ipConfigurations: ipConfiguration
    activeActive: isActiveActiveValid
    allowRemoteVnetTraffic: allowRemoteVnetTraffic
    allowVirtualWanTraffic: allowVirtualWanTraffic
    enableBgp: isBgpValid
    bgpSettings: isBgpValid ? bgpSettings : null
    disableIPSecReplayProtection: disableIPSecReplayProtection
    enableDnsForwarding: gatewayType == 'ExpressRoute' ? enableDnsForwarding : null
    enablePrivateIpAddress: enablePrivateIpAddress
    enableBgpRouteTranslationForNat: enableBgpRouteTranslationForNat
    gatewayType: gatewayType
    gatewayDefaultSite: !empty(gatewayDefaultSiteLocalNetworkGatewayId) ? {
      id: gatewayDefaultSiteLocalNetworkGatewayId
    } : null
    sku: {
      name: skuName
      tier: skuName
    }
    vpnType: vpnTypeVar
    vpnGatewayGeneration: gatewayType == 'Vpn' ? vpnGatewayGeneration : 'None'
  }
  dependsOn: [
    publicIPAddress
  ]
}
