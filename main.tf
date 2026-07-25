resource "azurerm_service_plan" "this" {
  name                = var.service_plan_name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = var.sku_name

  tags = var.tags
}

resource "azurerm_linux_web_app" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.this.id

  https_only = var.https_only

  client_certificate_enabled = var.client_certificate_enabled
  client_certificate_mode    = var.client_certificate_mode

  site_config {
    always_on = var.always_on

    # Pinned rather than left to the provider default so the module's transport
    # security posture cannot drift with a provider upgrade.
    minimum_tls_version = var.minimum_tls_version
    ftps_state          = var.ftps_state

    # `application_stack` requires exactly one of docker_image_name,
    # dotnet_version, go_version, java_version, node_version, php_version,
    # python_version or ruby_version. Emitting the block with a null
    # docker_image_name fails the provider's ExactlyOneOf check, so the block is
    # only rendered when an image is actually requested.
    dynamic "application_stack" {
      for_each = var.docker_image_name == null ? [] : [var.docker_image_name]

      content {
        docker_image_name   = application_stack.value
        docker_registry_url = var.docker_registry_url
      }
    }
  }

  app_settings = var.app_settings

  # Needed for `@Microsoft.KeyVault(...)` app settings: without an identity the
  # app has nothing to authenticate to Key Vault with, so secrets can only be
  # passed as plaintext values.
  dynamic "identity" {
    for_each = var.identity_type == null ? [] : [var.identity_type]

    content {
      type         = identity.value
      identity_ids = var.identity_ids
    }
  }

  key_vault_reference_identity_id = var.key_vault_reference_identity_id

  tags = var.tags

  lifecycle {
    # Expressed here rather than as a variable validation because cross-variable
    # validation requires Terraform >= 1.9 and this module supports >= 1.5.
    precondition {
      condition     = var.identity_type == null || !can(regex("UserAssigned", var.identity_type)) || length(var.identity_ids) > 0
      error_message = "identity_ids must contain at least one identity when identity_type includes UserAssigned."
    }
  }
}
