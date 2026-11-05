config {
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "azurerm" {
  enabled = true
  version = "0.33.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

# Auto-heal thresholds depend on the workload; the module leaves them to the
# caller instead of shipping arbitrary defaults.
rule "azurerm_app_service_missing_auto_heal_setting" {
  enabled = false
}
