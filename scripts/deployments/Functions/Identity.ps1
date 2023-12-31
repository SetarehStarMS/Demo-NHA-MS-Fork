<#
----------------------------------------------------------------------------------
Copyright (c) Microsoft Corporation.
Licensed under the MIT license.

THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES 
OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
----------------------------------------------------------------------------------
#>

function Set-Identity {
    param (
        [Parameter(Mandatory = $true)]
        $Context,

        [Parameter(Mandatory = $true)]
        [String]$Region,

        [Parameter(Mandatory = $true)]
        [String]$ManagementGroupId,

        [Parameter(Mandatory = $true)]
        [String]$SubscriptionId,

        [Parameter(Mandatory = $true)]
        [String]$ConfigurationFilePath,

        [Parameter(Mandatory = $true)]
        [String]$LogAnalyticsWorkspaceResourceId
    )

    Set-AzContext -Subscription $SubscriptionId
    Write-Output $SubscriptionId
    Write-Output $LogAnalyticsWorkspaceResourceId


    $SchemaFilePath = "$($Context.SchemaDirectory)/landingzones/lz-platform-identity.json"
    
    Write-Output "Validation JSON parameter configuration using $SchemaFilePath"
    Get-Content -Raw $ConfigurationFilePath | Test-Json -SchemaFile $SchemaFilePath

    # Load networking configuration
    $Configuration = Get-Content $ConfigurationFilePath | ConvertFrom-Json -Depth 100

    #region Check if Log Analytics Workspace Id is provided.  Otherwise set it.
    $LogAnalyticsWorkspaceResourceIdInFile = $Configuration.parameters | Get-Member -Name logAnalyticsWorkspaceResourceId
    
    if ($null -eq $LogAnalyticsWorkspaceResourceIdInFile -or $Configuration.parameters.logAnalyticsWorkspaceResourceId.value -eq "") {
        $LogAnalyticsWorkspaceIdElement = @{
        logAnalyticsWorkspaceResourceId = @{
            value = $LogAnalyticsWorkspaceResourceId
        }
        }

        $Configuration.parameters | Add-Member $LogAnalyticsWorkspaceIdElement -Force
    }
    #endregion
    
    $PopulatedParametersFilePath = $ConfigurationFilePath.Split('.')[0] + '-populated.json'

    Write-Output "Creating new file with runtime populated parameters: $PopulatedParametersFilePath"
    $Configuration | ConvertTo-Json -Depth 100 | Set-Content $PopulatedParametersFilePath

    # Write-Output "Moving Subscription ($SubscriptionId) to Management Group ($ManagementGroupId)"
    # New-AzManagementGroupDeployment `
    #     -ManagementGroupId $ManagementGroupId `
    #     -Location $Context.DeploymentRegion `
    #     -TemplateFile "$($Context.WorkingDirectory)/landingzones/utils/mg-move/move-subscription.bicep" `
    #     -TemplateParameterObject @{
    #         managementGroupId = $ManagementGroupId
    #         subscriptionId = $SubscriptionId
    #     } `
    #     -Verbose
        
    Write-Output "Deploying Identity to $SubscriptionId in $Region with $ConfigurationFilePath"
    New-AzSubscriptionDeployment `
        -Name "main-$Region" `
        -Location $Region `
        -TemplateFile "$($Context.WorkingDirectory)/landingzones/lz-platform-identity/main.bicep" `
        -TemplateParameterFile $PopulatedParametersFilePath `
        -Verbose
    

  #region Check if Private DNS Zones are managed in the Identity Susbcription.  If so, enable Private DNS Zones policy assignment
  if ($Configuration.parameters.privateDnsZones.value.enabled -eq $true) {
    $PolicyAssignmentFilePath = "$($Context.PolicySetCustomAssignmentsDirectory)/DNSPrivateEndpoints.bicep"

    Write-Output "Identity Network will manage private dns zones, creating Azure Policy assignment to automatically create Private Endpoint DNS Zones."
    Write-Output "Deploying policy assignment using $PolicyAssignmentFilePath"

    $Parameters = @{
      policyAssignmentManagementGroupId = $Context.Variables['var-NHA-managementGroupId']
      policyDefinitionManagementGroupId = $Context.Variables['var-NHA-managementGroupId']
      privateDNSZoneSubscriptionId = $SubscriptionId
      privateDNSZoneResourceGroupName = $Configuration.parameters.privateDnsZones.value.resourceGroupName
    }

    New-AzManagementGroupDeployment `
      -ManagementGroupId $Context.Variables['var-NHA-managementGroupId'] `
      -Location $Context.DeploymentRegion `
      -TemplateFile $PolicyAssignmentFilePath `
      -TemplateParameterObject $Parameters
  }
  else {
    Write-Output "Identity Network will not manage private dns zones.  Azure Policy assignment will be skipped."
  }
  #endregion

}