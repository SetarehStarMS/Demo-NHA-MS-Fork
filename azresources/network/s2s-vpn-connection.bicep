// ----------------------------------------------------------------------------------
// THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
// EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES 
// OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
// ----------------------------------------------------------------------------------
@description('Location for the deployment.')
param location string = resourceGroup().location

@description('Local Network Gateway Name')
param localNetworkGatewayName string

@description('VPN Connection Name')
param vpnConnectionName string

@description('Required. List of the local (on-premises) IP address ranges.')
param localAddressPrefixes array

@description('Optional. FQDN of local network gateway.')
param fqdn string = ''

@description('Required. Public IP of the local gateway.')
param localGatewayPublicIpAddress string

@description('Optional. The BGP speaker\'s ASN. Not providing this value will automatically disable BGP on this Local Network Gateway resource.')
param localAsn string = ''

@description('Optional. The BGP peering address and BGP identifier of this BGP speaker. Not providing this value will automatically disable BGP on this Local Network Gateway resource.')
param localBgpPeeringAddress string = ''

@description('Optional. The weight added to routes learned from this BGP speaker. This will only take effect if both the localAsn and the localBgpPeeringAddress values are provided.')
param localPeerWeight string = ''

@description('Required. The name of VPN gateway')
param virtualNetworkGatewayName string

@description('Optional. Expected bandwidth in MBPS.')
param connectionBandwidth int = 10

@description('Optional. Enable BGP flag.')
param enableBgp bool = false

@description('Optional. Enable internet security.')
param enableInternetSecurity bool = false

@description('Optional. Enable rate limiting.')
param enableRateLimiting bool = false

@description('Optional. The IPSec policies to be considered by this connection.')
param ipsecPolicies array = []

@description('Optional. Reference to a VPN site to link to.')
param remoteVpnSiteResourceId string = ''

@description('Optional. Routing configuration indicating the associated and propagated route tables for this connection.')
param routingConfiguration object = {}

@description('Optional. Routing weight for VPN connection.')
param routingWeight int = 0

@description('Optional. SharedKey for the VPN connection.')
@secure()
param sharedKey string = ''

@description('Optional. The traffic selector policies to be considered by this connection.')
param trafficSelectorPolicies array = []

@description('Optional. Use local Azure IP to initiate connection.')
param useLocalAzureIpAddress bool = false

@description('Optional. Enable policy-based traffic selectors.')
param usePolicyBasedTrafficSelectors bool = false

@description('Optional. Gateway connection protocol.')
@allowed([
  'IKEv1'
  'IKEv2'
])
param vpnConnectionProtocolType string = 'IKEv2'

@description('Optional. List of all VPN site link connections to the gateway.')
param vpnLinkConnections array = []

// ================//
// Variables       //
// ================//

var bgpSettings = {
  asn: localAsn
  bgpPeeringAddress: localBgpPeeringAddress
  peerWeight: !empty(localPeerWeight) ? localPeerWeight : '0'
}

// ================//
// Deployments     //
// ================//

// Create local network Gateway
resource localNetworkGateway 'Microsoft.Network/localNetworkGateways@2023-05-01' = {
  name: localNetworkGatewayName
  location: location
  properties: {
    localNetworkAddressSpace: {
      addressPrefixes: localAddressPrefixes
    }
    fqdn: !empty(fqdn) ? fqdn : null
    gatewayIpAddress: localGatewayPublicIpAddress
    bgpSettings: !empty(localAsn) && !empty(localBgpPeeringAddress) ? bgpSettings : null
  }
}

// Get VPN Gateway 
resource vpnGateway 'Microsoft.Network/vpnGateways@2023-05-01' existing = {
  name: virtualNetworkGatewayName
  scope: resourceGroup()
}


// Create S2S VPN Connection
resource vpnConnection 'Microsoft.Network/vpnGateways/vpnConnections@2023-05-01' = {
  name: vpnConnectionName
  parent: vpnGateway
  properties: {
    connectionBandwidth: connectionBandwidth
    enableBgp: enableBgp
    enableInternetSecurity: enableInternetSecurity
    enableRateLimiting: enableRateLimiting
    ipsecPolicies: ipsecPolicies
    remoteVpnSite: !empty(remoteVpnSiteResourceId) ? {
      id: remoteVpnSiteResourceId
    } : null
    routingConfiguration: routingConfiguration
    routingWeight: routingWeight
    sharedKey: sharedKey
    trafficSelectorPolicies: trafficSelectorPolicies
    useLocalAzureIpAddress: useLocalAzureIpAddress
    usePolicyBasedTrafficSelectors: usePolicyBasedTrafficSelectors
    vpnConnectionProtocolType: vpnConnectionProtocolType
    vpnLinkConnections: vpnLinkConnections
  }
  
}
