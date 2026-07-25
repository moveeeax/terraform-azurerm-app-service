terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      # `site_config.application_stack.docker_image_name` and
      # `docker_registry_url` were introduced in azurerm 3.63.0 (they replaced
      # `docker_image`/`docker_image_tag`, which were removed in 4.0). Anything
      # older than 3.63.0 fails with "An argument named docker_image_name is
      # not expected here", so 3.63.0 is the real floor for this module.
      source  = "hashicorp/azurerm"
      version = ">= 3.63.0, < 5.0"
    }
  }
}
