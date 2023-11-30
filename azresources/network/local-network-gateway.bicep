// ----------------------------------------------------------------------------------
// THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
// EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES 
// OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
// ----------------------------------------------------------------------------------
@description('Location for the deployment.')
param location string = resourceGroup().location

@description('Local Network Gateway Name')
param localNetworkGatewayName string

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
