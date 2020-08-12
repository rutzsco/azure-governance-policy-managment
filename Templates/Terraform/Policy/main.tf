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