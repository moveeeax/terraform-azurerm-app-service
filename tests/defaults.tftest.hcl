# Requires Terraform >= 1.7 (or OpenTofu >= 1.7) for `mock_provider`.
# The module itself still supports >= 1.5 — this requirement is test-only.
mock_provider "azurerm" {
  # The provider validates that service_plan_id is a well-formed ARM ID, so the
  # mock has to return one instead of a random string. Placeholder subscription.
  mock_resource "azurerm_service_plan" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Web/serverFarms/test-asp"
    }
  }
}

variables {
  name                = "test-webapp01"
  service_plan_name   = "test-asp"
  resource_group_name = "test-rg"
  location            = "eastus"
}

run "defaults_are_safe" {
  command = plan

  assert {
    condition     = azurerm_linux_web_app.this.https_only == true
    error_message = "https_only must default to true so plaintext HTTP is redirected."
  }

  assert {
    condition     = azurerm_linux_web_app.this.site_config[0].minimum_tls_version == "1.2"
    error_message = "minimum_tls_version must default to 1.2."
  }

  assert {
    condition     = azurerm_linux_web_app.this.site_config[0].ftps_state == "Disabled"
    error_message = "ftps_state must default to Disabled so no FTP endpoint is exposed."
  }

  assert {
    condition     = length(azurerm_linux_web_app.this.identity) == 0
    error_message = "No managed identity should be attached unless identity_type is set."
  }
}

# Regression guard: application_stack must not be emitted when no docker image
# is requested, otherwise the provider's ExactlyOneOf check rejects the plan.
run "no_application_stack_without_docker_image" {
  command = plan

  assert {
    condition     = length(azurerm_linux_web_app.this.site_config[0].application_stack) == 0
    error_message = "application_stack must be omitted when docker_image_name is null."
  }
}

run "application_stack_set_when_docker_image_given" {
  command = plan

  variables {
    docker_image_name   = "nginx:latest"
    docker_registry_url = "https://index.docker.io"
  }

  assert {
    condition     = azurerm_linux_web_app.this.site_config[0].application_stack[0].docker_image_name == "nginx:latest"
    error_message = "application_stack must carry the requested docker image."
  }
}

run "rejects_plaintext_ftp" {
  command = plan

  variables {
    ftps_state = "AllAllowed"
  }

  expect_failures = [var.ftps_state]
}

run "rejects_obsolete_tls" {
  command = plan

  variables {
    minimum_tls_version = "1.0"
  }

  expect_failures = [var.minimum_tls_version]
}

run "rejects_invalid_client_certificate_mode" {
  command = plan

  variables {
    client_certificate_mode = "Whenever"
  }

  expect_failures = [var.client_certificate_mode]
}

run "rejects_invalid_identity_type" {
  command = plan

  variables {
    identity_type = "SystemManaged"
  }

  expect_failures = [var.identity_type]
}

run "user_assigned_identity_requires_ids" {
  command = plan

  variables {
    identity_type = "UserAssigned"
    identity_ids  = []
  }

  expect_failures = [azurerm_linux_web_app.this]
}

run "ftps_only_is_allowed" {
  command = plan

  variables {
    ftps_state = "FtpsOnly"
  }

  assert {
    condition     = azurerm_linux_web_app.this.site_config[0].ftps_state == "FtpsOnly"
    error_message = "ftps_state should be configurable to FtpsOnly."
  }
}

run "system_assigned_identity_is_attached" {
  command = plan

  variables {
    identity_type = "SystemAssigned"
  }

  assert {
    condition     = azurerm_linux_web_app.this.identity[0].type == "SystemAssigned"
    error_message = "identity_type should attach a system-assigned identity."
  }
}

# Regression guard: Free and Shared service plans reject always_on = true at
# apply time ("Always On is not supported for Free or Shared plans"). The
# module's own always_on default is true, so picking sku_name = "F1" without
# also overriding always_on must fail at plan time, not at apply time against
# the Azure API.
run "rejects_always_on_with_free_sku" {
  command = plan

  variables {
    sku_name = "F1"
  }

  expect_failures = [azurerm_linux_web_app.this]
}

run "rejects_always_on_with_shared_sku" {
  command = plan

  variables {
    sku_name = "D1"
  }

  expect_failures = [azurerm_linux_web_app.this]
}

run "allows_always_on_disabled_on_free_sku" {
  command = plan

  variables {
    sku_name  = "F1"
    always_on = false
  }

  assert {
    condition     = azurerm_linux_web_app.this.site_config[0].always_on == false
    error_message = "always_on = false must be accepted on the F1 (Free) service plan."
  }
}

# Regression guard: key_vault_reference_identity_id references an identity
# that must actually be attached via the identity block, otherwise the
# @Microsoft.KeyVault() reference has nothing to authenticate with.
run "rejects_key_vault_reference_identity_without_identity" {
  command = plan

  variables {
    key_vault_reference_identity_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/test-id"
  }

  expect_failures = [azurerm_linux_web_app.this]
}

run "allows_key_vault_reference_identity_with_identity" {
  command = plan

  variables {
    identity_type                   = "SystemAssigned"
    key_vault_reference_identity_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/test-id"
  }

  assert {
    condition     = azurerm_linux_web_app.this.key_vault_reference_identity_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/test-id"
    error_message = "key_vault_reference_identity_id should be accepted when an identity is attached."
  }
}

# Regression guard: docker_registry_url is only rendered inside
# application_stack, which requires docker_image_name. Setting the registry
# URL alone silently does nothing without this check.
run "rejects_docker_registry_url_without_image" {
  command = plan

  variables {
    docker_registry_url = "https://index.docker.io"
  }

  expect_failures = [azurerm_linux_web_app.this]
}
