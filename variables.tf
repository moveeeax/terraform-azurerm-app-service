variable "name" {
  description = "Name of the Linux web app. Must be globally unique."
  type        = string
}

variable "service_plan_name" {
  description = "Name of the service plan hosting the web app."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group in which to create the resources."
  type        = string
}

variable "location" {
  description = "Azure region in which to create the resources."
  type        = string
}

variable "sku_name" {
  description = "SKU of the service plan, e.g. B1, P1v3 or S1."
  type        = string
  default     = "B1"
}

variable "https_only" {
  description = "Whether the web app redirects all HTTP traffic to HTTPS."
  type        = bool
  default     = true
}

variable "always_on" {
  description = "Whether the web app is always kept loaded. Must be false when sku_name is \"F1\" (Free) or \"D1\" (Shared); those service plans do not support Always On."
  type        = bool
  default     = true
}

variable "minimum_tls_version" {
  description = "Minimum TLS version accepted for inbound HTTPS requests."
  type        = string
  default     = "1.2"

  validation {
    condition     = contains(["1.2", "1.3"], var.minimum_tls_version)
    error_message = "minimum_tls_version must be \"1.2\" or \"1.3\". TLS 1.0 and 1.1 are deprecated and are not accepted by this module."
  }
}

variable "ftps_state" {
  description = "State of the FTP/FTPS deployment endpoint. \"Disabled\" turns it off entirely, \"FtpsOnly\" allows FTP over TLS. \"AllAllowed\" is rejected because it accepts plaintext FTP credentials."
  type        = string
  default     = "Disabled"

  validation {
    condition     = contains(["Disabled", "FtpsOnly"], var.ftps_state)
    error_message = "ftps_state must be \"Disabled\" or \"FtpsOnly\". \"AllAllowed\" permits plaintext FTP and is not accepted by this module."
  }
}

variable "client_certificate_enabled" {
  description = "Whether the web app requests a TLS client certificate from callers."
  type        = bool
  default     = false
}

variable "client_certificate_mode" {
  description = "How the client certificate is treated when client_certificate_enabled is true. One of Required, Optional or OptionalInteractiveUser."
  type        = string
  default     = "Required"

  validation {
    condition     = contains(["Required", "Optional", "OptionalInteractiveUser"], var.client_certificate_mode)
    error_message = "client_certificate_mode must be one of Required, Optional or OptionalInteractiveUser."
  }
}

variable "identity_type" {
  description = "Managed identity to attach to the web app: SystemAssigned, UserAssigned or \"SystemAssigned, UserAssigned\". Null attaches no identity. An identity is required for @Microsoft.KeyVault() app settings."
  type        = string
  default     = null

  validation {
    condition     = var.identity_type == null || contains(["SystemAssigned", "UserAssigned", "SystemAssigned, UserAssigned"], coalesce(var.identity_type, "SystemAssigned"))
    error_message = "identity_type must be null, \"SystemAssigned\", \"UserAssigned\" or \"SystemAssigned, UserAssigned\"."
  }
}

variable "identity_ids" {
  description = "IDs of the user-assigned identities to attach. Required when identity_type includes UserAssigned."
  type        = list(string)
  default     = []
}

variable "key_vault_reference_identity_id" {
  description = "ID of the user-assigned identity used to resolve @Microsoft.KeyVault() app settings. Null uses the system-assigned identity. Requires identity_type to be set: the referenced identity must be attached via the identity block."
  type        = string
  default     = null
}

variable "docker_image_name" {
  description = "Docker image and tag to run, e.g. nginx:latest. Shorthand for application_stack.docker_image_name; cannot be combined with application_stack. Null runs the default runtime unless application_stack is set."
  type        = string
  default     = null
}

variable "docker_registry_url" {
  description = "URL of the container registry hosting the image, e.g. https://index.docker.io. Only takes effect when docker_image_name is also set. Shorthand for application_stack.docker_registry_url; cannot be combined with application_stack."
  type        = string
  default     = null
}

variable "application_stack" {
  description = <<-EOT
    Runtime of the web app. Set exactly one of docker_image_name, dotnet_version,
    go_version, java_version, node_version, php_version or python_version.
    java_version also needs java_server and java_server_version; docker_registry_url
    only applies with docker_image_name. Allowed version strings are validated by
    the azurerm provider. Null falls back to docker_image_name/docker_registry_url,
    and to the default runtime when those are null too. Cannot be combined with
    docker_image_name or docker_registry_url.
  EOT
  type = object({
    docker_image_name   = optional(string)
    docker_registry_url = optional(string)
    dotnet_version      = optional(string)
    go_version          = optional(string)
    java_version        = optional(string)
    java_server         = optional(string)
    java_server_version = optional(string)
    node_version        = optional(string)
    php_version         = optional(string)
    python_version      = optional(string)
  })
  default = null

  # Mirrors the provider's ExactlyOneOf on application_stack so a bad
  # combination fails at plan time with a message naming the input.
  validation {
    condition = var.application_stack == null ? true : length([
      for v in [
        var.application_stack.docker_image_name,
        var.application_stack.dotnet_version,
        var.application_stack.go_version,
        var.application_stack.java_version,
        var.application_stack.node_version,
        var.application_stack.php_version,
        var.application_stack.python_version,
      ] : v if v != null
    ]) == 1
    error_message = "application_stack must set exactly one of docker_image_name, dotnet_version, go_version, java_version, node_version, php_version or python_version."
  }

  # The provider requires java_version, java_server and java_server_version
  # together (RequiredWith on each of them).
  validation {
    condition = var.application_stack == null ? true : length(compact([
      var.application_stack.java_version,
      var.application_stack.java_server,
      var.application_stack.java_server_version,
    ])) % 3 == 0
    error_message = "application_stack.java_version, java_server and java_server_version must be set together."
  }

  validation {
    condition     = var.application_stack == null ? true : (var.application_stack.docker_registry_url == null || var.application_stack.docker_image_name != null)
    error_message = "application_stack.docker_registry_url has no effect unless application_stack.docker_image_name is also set."
  }
}

variable "app_settings" {
  description = "Map of application settings exposed to the web app as environment variables. Marked sensitive so values are not printed in plan output; pass secrets as @Microsoft.KeyVault(SecretUri=...) references rather than literals."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "tags" {
  description = "Map of tags applied to the resources."
  type        = map(string)
  default     = {}
}
