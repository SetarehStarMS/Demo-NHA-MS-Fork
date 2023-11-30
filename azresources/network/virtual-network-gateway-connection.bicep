// ----------------------------------------------------------------------------------
// THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
// EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES 
// OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
// ----------------------------------------------------------------------------------
@description('Location for the deployment.')
param location string = resourceGroup().location

@description('VPN Connection Name')
param connectionName string

@description('Optional. Gateway connection connectionType.')
@allowed([
  'IPsec'
  'Vnet2Vnet'
  'ExpressRoute'
  'VPNClient'
])
param connectionType string = 'IPsec'

@allowed([
  'Default'
  'InitiatorOnly'
  'ResponderOnly'
])
@description('Optional. The connection connectionMode for this connection. Available for IPSec connections.')
param connectionMode string = 'Default'

@description('Optional. Connection connectionProtocol used for this connection. Available for IPSec connections.')
param connectionProtocol string = 'IKEv2'

@minValue(9)
@maxValue(3600)
@description('Optional. The dead peer detection timeout of this connection in seconds. Setting the timeout to shorter periods will cause IKE to rekey more aggressively, causing the connection to appear to be disconnected in some instances. The general recommendation is to set the timeout between 30 to 45 seconds.')
param dpdTimeoutSeconds int = 45

param enablePrivateLinkFastPath bool = false

@description('Optional. Bypass ExpressRoute Gateway for data forwarding. Only available when connection connectionType is Express Route.')
param expressRouteGatewayBypass bool = false

@description('Required. The primary Virtual Network Gateway.')
param virtualNetworkGateway1 object

@description('Optional. The remote Virtual Network Gateway. Used for connection connectionType [Vnet2Vnet].')
param virtualNetworkGateway2 object = {}

@description('Optional. The local network gateway. Used for connection type [IPsec].')
param localNetworkGateway2 object = {}

@description('Optional. The Authorization Key to connect to an Express Route Circuit. Used for connection type [ExpressRoute].')
@secure()
param authorizationKey string = ''

@description('Optional. The remote peer. Used for connection connectionType [ExpressRoute].')
param peer object = {}

@description('Optional. Specifies a VPN shared key. The same value has to be specified on both Virtual Network Gateways.')
@secure()
param vpnSharedKey string = ''

@description('Optional. Enable policy-based traffic selectors.')
param usePolicyBasedTrafficSelectors bool = false

@description('Optional. The IPSec Policies to be considered by this connection.')
param customIPSecPolicy object = {
  saLifeTimeSeconds: 0
  saDataSizeKilobytes: 0
  ipsecEncryption: ''
  ipsecIntegrity: ''
  ikeEncryption: ''
  ikeIntegrity: ''
  dhGroup: ''
  pfsGroup: ''
}

@description('Optional. The weight added to routes learned from this BGP speaker.')
param routingWeight int = -1

@description('Optional. Value to specify if BGP is enabled or not.')
param enableBgp bool = false

@description('Optional. Use private local Azure IP for the connection. Only available for IPSec Virtual Network Gateways that use the Azure Private IP Property.')
param useLocalAzureIpAddress bool = false


// ================//
// Deployments     //
// ================//

resource connection 'Microsoft.Network/connections@2023-04-01' = {
  name: connectionName
  location: location
  properties: {
    connectionType: connectionType
    connectionMode: connectionType == 'IPsec' ? connectionMode : null
    connectionProtocol: connectionType == 'IPsec' ? connectionProtocol : null
    dpdTimeoutSeconds: connectionType == 'IPsec' ? dpdTimeoutSeconds : null
    enablePrivateLinkFastPath: connectionType == 'ExpressRoute' ? enablePrivateLinkFastPath : null
    expressRouteGatewayBypass: connectionType == 'ExpressRoute' ? expressRouteGatewayBypass : null
    virtualNetworkGateway1: virtualNetworkGateway1
    virtualNetworkGateway2: connectionType == 'Vnet2Vnet' ? virtualNetworkGateway2 : null
    localNetworkGateway2: connectionType == 'IPsec' ? localNetworkGateway2 : null
    peer: connectionType == 'ExpressRoute' ? peer : null
    authorizationKey: connectionType == 'ExpressRoute' && !empty(authorizationKey) ? authorizationKey : null
    sharedKey: connectionType != 'ExpressRoute' ? vpnSharedKey : null
    usePolicyBasedTrafficSelectors: usePolicyBasedTrafficSelectors
    ipsecPolicies: !empty(customIPSecPolicy.ipsecEncryption) ? [
      {
        saLifeTimeSeconds: customIPSecPolicy.saLifeTimeSeconds
        saDataSizeKilobytes: customIPSecPolicy.saDataSizeKilobytes
        ipsecEncryption: customIPSecPolicy.ipsecEncryption
        ipsecIntegrity: customIPSecPolicy.ipsecIntegrity
        ikeEncryption: customIPSecPolicy.ikeEncryption
        ikeIntegrity: customIPSecPolicy.ikeIntegrity
        dhGroup: customIPSecPolicy.dhGroup
        pfsGroup: customIPSecPolicy.pfsGroup
      }
    ] : customIPSecPolicy.ipsecEncryption
    routingWeight: routingWeight != -1 ? routingWeight : null
    enableBgp: enableBgp
    useLocalAzureIpAddress: connectionType == 'IPsec' ? useLocalAzureIpAddress : null
  }
}
