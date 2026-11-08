locals {
  # The top-level docker_image_name/docker_registry_url inputs predate
  # application_stack and stay supported as a shorthand for a container stack.
  # They render exactly the block they rendered before, so existing callers get
  # an unchanged plan.
  application_stack = var.application_stack != null ? var.application_stack : (
    var.docker_image_name == null ? null : {
      docker_image_name   = var.docker_image_name
      docker_registry_url = var.docker_registry_url
      dotnet_version      = null
      go_version          = null
      java_version        = null
      java_server         = null
      java_server_version = null
      node_version        = null
      php_version         = null
      python_version      = null
    }
  )
}

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
    # dotnet_version, go_version, java_version, node_version, php_version or
    # python_version. Emitting the block with all of them null fails the
    # provider's ExactlyOneOf check, so the block is only rendered when a stack
    # is actually requested (see local.application_stack).
    dynamic "application_stack" {
      for_each = local.application_stack == null ? [] : [local.application_stack]

      content {
        docker_image_name   = application_stack.value.docker_image_name
        docker_registry_url = application_stack.value.docker_registry_url
        dotnet_version      = application_stack.value.dotnet_version
        go_version          = application_stack.value.go_version
        java_version        = application_stack.value.java_version
        java_server         = application_stack.value.java_server
        java_server_version = application_stack.value.java_server_version
        node_version        = application_stack.value.node_version
        php_version         = application_stack.value.php_version
        python_version      = application_stack.value.python_version
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
    # Expressed here rather than as variable validation because cross-variable
    # validation requires Terraform >= 1.9 and this module supports >= 1.5.
    precondition {
      condition     = var.identity_type == null || !can(regex("UserAssigned", var.identity_type)) || length(var.identity_ids) > 0
      error_message = "identity_ids must contain at least one identity when identity_type includes UserAssigned."
    }

    # The provider defaults site_config.always_on to true, but Free (F1) and
    # Shared (D1) service plans reject that outright at apply time: "Always On
    # is not supported for Free or Shared plans." Catching it here turns an
    # apply-time Azure API error into a plan-time message that names the
    # actual fix.
    precondition {
      condition     = !contains(["F1", "D1"], var.sku_name) || var.always_on == false
      error_message = "always_on must be false when sku_name is \"F1\" (Free) or \"D1\" (Shared); these service plans do not support Always On."
    }

    # key_vault_reference_identity_id must name an identity that is actually
    # attached via the identity block; the provider accepts the value with no
    # identity assigned and the reference then silently fails to resolve at
    # runtime instead of failing plan or apply.
    precondition {
      condition     = var.key_vault_reference_identity_id == null || var.identity_type != null
      error_message = "key_vault_reference_identity_id requires identity_type to be set; the referenced identity must be assigned via the identity block."
    }

    # docker_registry_url only has an effect inside the application_stack
    # block, which is only rendered when docker_image_name is set (see
    # above). Without this check, setting docker_registry_url alone is
    # silently dropped rather than surfaced as a misconfiguration.
    precondition {
      condition     = var.docker_image_name != null || var.docker_registry_url == null
      error_message = "docker_registry_url has no effect unless docker_image_name is also set."
    }

    # docker_image_name and docker_registry_url are kept as shorthands for a
    # container stack. Combining them with application_stack would leave it
    # ambiguous which one wins, so the two styles are mutually exclusive.
    precondition {
      condition     = var.application_stack == null || (var.docker_image_name == null && var.docker_registry_url == null)
      error_message = "Set either application_stack or docker_image_name/docker_registry_url, not both. Move the image into application_stack.docker_image_name."
    }
  }
}
