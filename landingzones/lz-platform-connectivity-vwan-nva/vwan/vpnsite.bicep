param vpnSiteName string
param deviceVendor string
param deviceModel string
param linkSpeedInMbps int
@description('Location for the deployment.')
param location string = resourceGroup().location

@description('A set of key/value pairs of tags assigned to the resource group and resources.')
param tags object

param vHUBId string
resource virtualGatewaySite 'Microsoft.Network/vpnSites@2020-05-01' = {
  name: vpnSiteName
  location: location
  tags: tags
  properties: {
    deviceProperties: {
      deviceVendor: deviceVendor
      deviceModel: deviceModel
      linkSpeedInMbps: linkSpeedInMbps
    }
    virtualWan: {
      id: vHUBId
    }
  }
}
