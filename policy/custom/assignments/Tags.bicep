// ----------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.
//
// THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
// EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES 
// OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
// ----------------------------------------------------------------------------------

targetScope = 'managementGroup'

@description('Location for the deployment.')
param location string = deployment().location

@description('Management Group scope for the policy definition.')
param policyDefinitionManagementGroupId string

@description('Management Group scope for the policy assignment.')
param policyAssignmentManagementGroupId string

@allowed([
  'Default'
  'DoNotEnforce'
])
@description('Policy set assignment enforcement mode.  Possible values are { Default, DoNotEnforce }.  Default value:  Default')
param enforcementMode string = 'Default'

var scope = tenantResourceId('Microsoft.Management/managementGroups', policyAssignmentManagementGroupId)
var policyDefinitionScope = tenantResourceId('Microsoft.Management/managementGroups', policyDefinitionManagementGroupId)


// Telemetry - Azure customer usage attribution
// Reference:  https://learn.microsoft.com/azure/marketplace/azure-partner-customer-usage-attribution
var telemetry = json(loadTextContent('../../../config/telemetry.json'))
module telemetryCustomerUsageAttribution '../../../azresources/telemetry/customer-usage-attribution-management-group.bicep' = if (telemetry.customerUsageAttribution.enabled) {
  name: 'pid-${telemetry.customerUsageAttribution.modules.policy}-tags'
}

// Tags Inherited from Subscription to Resource Groups
var rgInheritedPolicyFromSubscriptionToResourceGroupId = 'tags-inherited-from-subscription-to-resource-group'
var rgInheritedAssignmentFromSubscriptionToResourceGroupName = 'NHA - ALZ - Tags inherited from subscription to resource group if missing'

resource rgInheritedPolicySetFromSubscriptionToResourceGroupAssignment 'Microsoft.Authorization/policyAssignments@2020-03-01' = {
  name: 'tags-torg-${uniqueString('tags-torg-', policyAssignmentManagementGroupId)}'
  properties: {
    displayName: rgInheritedAssignmentFromSubscriptionToResourceGroupName
    policyDefinitionId: extensionResourceId(policyDefinitionScope, 'Microsoft.Authorization/policySetDefinitions', rgInheritedPolicyFromSubscriptionToResourceGroupId)
    scope: scope
    notScopes: []
    parameters: {}
    enforcementMode: enforcementMode
  }
  identity: {
    type: 'SystemAssigned'
  }
  location: location
}

resource rgPolicySetRoleAssignmentFromSubscriptionToResourceGroupContributor 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(rgInheritedAssignmentFromSubscriptionToResourceGroupName, 'RgRemediation', 'Contributor')
  scope: managementGroup()
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions','b24988ac-6180-42a0-ab88-20f7382dd24c')
    principalId: rgInheritedPolicySetFromSubscriptionToResourceGroupAssignment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Tags Inherited from Resource Groups
var rgInheritedPolicyId = 'tags-inherited-from-resource-group'
var rgInheritedAssignmentName = 'NHA - ALZ - Tags inherited from resource group if missing'

resource rgInheritedPolicySetAssignment 'Microsoft.Authorization/policyAssignments@2020-03-01' = {
  name: 'tags-rg-${uniqueString('tags-from-rg-', policyAssignmentManagementGroupId)}'
  properties: {
    displayName: rgInheritedAssignmentName
    policyDefinitionId: extensionResourceId(policyDefinitionScope, 'Microsoft.Authorization/policySetDefinitions', rgInheritedPolicyId)
    scope: scope
    notScopes: []
    parameters: {}
    enforcementMode: enforcementMode
  }
  identity: {
    type: 'SystemAssigned'
  }
  location: location
}

resource rgPolicySetRoleAssignmentContributor 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(policyAssignmentManagementGroupId, 'RgRemediation', 'Contributor')
  scope: managementGroup()
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions','b24988ac-6180-42a0-ab88-20f7382dd24c')
    principalId: rgInheritedPolicySetAssignment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Required Tags on Resource Group
var rgRequiredPolicyId = 'required-tags-on-resource-group'
var rgRequiredAssignmentName = 'NHA - ALZ - Required tags on resource group'

resource rgRequiredPolicySetAssignment 'Microsoft.Authorization/policyAssignments@2020-03-01' = {
  name: 'tags-rg-${uniqueString('tags-required-', policyAssignmentManagementGroupId)}'
  properties: {
    displayName: rgRequiredAssignmentName
    policyDefinitionId: extensionResourceId(policyDefinitionScope, 'Microsoft.Authorization/policySetDefinitions', rgRequiredPolicyId)
    scope: scope
    notScopes: []
    parameters: {}
    enforcementMode: enforcementMode
  }
  identity: {
    type: 'SystemAssigned'
  }
  location: location
}

// Audit for Tags on Resources
var resourcesPolicyId = 'audit-required-tags-on-resources'
var resourcesAssignmentName = 'NHA - ALZ - Audit for required tags on resources'

resource resourcesAuditPolicySetAssignment 'Microsoft.Authorization/policyAssignments@2020-03-01' = {
  name: 'tags-r-${uniqueString('tags-missing-', policyAssignmentManagementGroupId)}'
  properties: {
    displayName: resourcesAssignmentName
    policyDefinitionId: extensionResourceId(policyDefinitionScope, 'Microsoft.Authorization/policySetDefinitions', resourcesPolicyId)
    scope: scope
    notScopes: []
    parameters: {}
    enforcementMode: enforcementMode
  }
  identity: {
    type: 'SystemAssigned'
  }
  location: location
}
