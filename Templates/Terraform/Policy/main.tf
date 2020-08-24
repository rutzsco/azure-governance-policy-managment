# Configure the Microsoft Azure Provider.
provider "azurerm" {
    version = "=1.32.0"
}

# Define Azure Policy Definition
resource "azurerm_policy_definition" "policy" {
  name         = "VM-Naming-Convention"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Governance - IaaS: Virtual Machine Naming Convention"

  metadata     = <<METADATA
    {
    "category": "IaaS"
    }
  METADATA

  policy_rule = <<POLICY_RULE
    {
    "if": {
		"allOf":[
			{
				"not":{
					"field":"name",
					"match":"[parameters('namePattern')]"
				}
			},
			{
				"field": "type",
				"equals": "Microsoft.Compute/virtualMachines"
			}
		]
    },
    "then": { 
      "effect": "deny"
    }
  }
POLICY_RULE

  parameters = <<PARAMETERS
    {
		"namePattern":{
			"type": "String",
			"metadata":{
				"displayName": "namePattern",
				"description": "? for letter, # for numbers"
			}
		}
  }
PARAMETERS
}

# Define Azure Policy Assignment
resource "azurerm_policy_assignment" "policy-assignment" {
  name                 = "Governance-IaaS-Naming-Convention-Assignment"
  scope                = "/subscriptions/164a84cf-b099-4567-a527-c2a8143a32c7"
  policy_definition_id = "${azurerm_policy_definition.policy.id}"
  description          = "Naming convention for VM"
  display_name         = "Governance - IaaS: Virtual Machine Naming Convention"

  parameters = <<PARAMETERS
{
  "namePattern": {
    "value": "vm-#"
  }
}
PARAMETERS
}

resource "azurerm_policy_definition" "Deploy_SQL_Server_Auditing_Security" {
    name                    = "DB_DNE_SQL_S_AS"
    policy_type             = "Custom"
    mode                    = "Indexed"
    display_name            = "Deploy_SQL_Server_Auditing_Security"
    description             = "Governance - Database: This Policy will deploy Auditing and Advanced Data Security to Azure SQL servers."
    
    metadata = <<METADATA
        {
            "version": "1.0.0",
            "category": "SQL"
        }
    METADATA

    parameters = <<PARAMETERS
        {
            "effect": {
                "type": "String",
                "metadata": {
                    "displayName": "Effect",
                    "description": "Enable or disable the execution of the policy"
                },
                "allowedValues": [
                    "DeployIfNotExists",
                    "Disabled"
                ],
                "defaultValue": "DeployIfNotExists"
            }
        }
    PARAMETERS

    policy_rule = <<POLICY_RULE
        {
            "if": {
                "allOf": [
                    {
                        "field": "type",
                        "equals": "Microsoft.Sql/servers"
                    },
                    {
                        "value": "[resourceGroup().name]",
                        "notcontains": "workspacemanagedrg"
                    }
                ]
            },
            "then": {
                "effect": "[parameters('effect')]",
                "details": {
                    "type": "Microsoft.Sql/servers/securityAlertPolicies",
                    "name": "Default",
                    "existenceCondition": {
                        "field": "Microsoft.Sql/securityAlertPolicies.state",
                        "equals": "Enabled"
                    },
                    "roleDefinitionIds": [
                        "/providers/microsoft.authorization/roleDefinitions/056cd41c-7e88-42e1-933e-88ba6a50c9c3",
                        "/providers/microsoft.authorization/roleDefinitions/17d1049b-9a84-46fb-8f53-869881c3d3ab"
                    ],
                    "deployment": {
                        "properties": {
                            "mode": "incremental",
                            "template": {
                                "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
                                "contentVersion": "1.0.0.0",
                                "parameters": {
                                    "serverName": {
                                        "type": "string"
                                    },
                                    "location": {
                                        "type": "string"
                                    }
                                },
                                "variables": {
                                    "serverResourceGroupName": "[resourceGroup().name]",
                                    "subscriptionId": "[subscription().subscriptionId]",
                                    "uniqueStorage": "[uniqueString(variables('subscriptionId'), variables('serverResourceGroupName'), parameters('location'))]",
                                    "storageName": "[tolower(concat('sqltest', variables('uniqueStorage')))]"
                                },
                                "resources": [
                                    {
                                        "type": "Microsoft.Storage/storageAccounts",
                                        "name": "[variables('storageName')]",
                                        "apiVersion": "2019-04-01",
                                        "location": "[parameters('location')]",
                                        "sku": {
                                            "name": "Standard_LRS"
                                        },
                                        "kind": "StorageV2",
                                        "properties": {
                                            "supportsHttpsTrafficOnly": true,
                                            "allowBlobPublicAccess": false
                                        }
                                    },
                                    {
                                        "name": "[concat(parameters('serverName'), '/auditSettings')]",
                                        "type": "Microsoft.Sql/servers/auditingSettings",
                                        "apiVersion": "2017-03-01-preview",
                                        "properties": {
                                            "state": "Enabled",
                                            "storageEndpoint": "[concat(reference(resourceId('Microsoft.Storage/storageAccounts', variables('storageName'))).primaryEndpoints.blob, 'vulnerability-assessment')]",
                                            "storageAccountAccessKey": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', variables('storageName')), '2018-02-01').keys[0].value]",
                                            "retentionDays": 0,
                                            "auditActionsAndGroups": [
                                                "SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP",
                                                "FAILED_DATABASE_AUTHENTICATION_GROUP",
                                                "BATCH_COMPLETED_GROUP"
                                            ],
                                            "storageAccountSubscriptionId": "[subscription().subscriptionId]",
                                            "isStorageSecondaryKeyInUse": false,
                                            "isAzureMonitorTargetEnabled": false
                                        },
                                        "dependsOn": [
                                            "[concat('Microsoft.Storage/storageAccounts/', variables('storageName'))]"
                                        ]
                                    },
                                    {
                                        "name": "[concat(parameters('serverName'), '/alertSettings')]",
                                        "type": "Microsoft.Sql/servers/securityAlertPolicies",
                                        "apiVersion": "2017-03-01-preview",
                                        "properties": {
                                            "state": "Enabled",
                                            "emailAccountAdmins": false,
                                            "emailAddresses": ["scrutz@microsoft.com"]
                                        }
                                    },
                                    {
                                        "name": "[concat(parameters('serverName'), '/vulnerabilitySettings')]",
                                        "type": "Microsoft.Sql/servers/vulnerabilityAssessments",
                                        "apiVersion": "2018-06-01-preview",
                                        "properties": {
                                            "storageContainerPath": "[concat(reference(resourceId('Microsoft.Storage/storageAccounts', variables('storageName'))).primaryEndpoints.blob, 'vulnerability-assessment')]",
                                            "storageAccountAccessKey": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', variables('storageName')), '2018-02-01').keys[0].value]",
                                            "recurringScans": {
                                                "isEnabled": true,
                                                "emailSubscriptionAdmins": false,
                                                "emails": ["scrutz@microsoft.com"]
                                            }
                                        },
                                        "dependsOn": [
                                            "[concat('Microsoft.Storage/storageAccounts/', variables('storageName'))]",
                                            "[concat('Microsoft.Sql/servers/', parameters('serverName'), '/securityAlertPolicies/alertSettings')]"
                                        ]
                                    }
                                ]
                            },
                            "parameters": {
                                "serverName": {
                                    "value": "[field('name')]"
                                },
                                "location": {
                                    "value": "[field('location')]"
                                }
                            }
                        }
                    }
                }
            }
        }
    POLICY_RULE
}
