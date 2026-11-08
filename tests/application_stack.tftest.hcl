# Requires Terraform >= 1.7 (or OpenTofu >= 1.7) for `mock_provider`.
mock_provider "azurerm" {
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

# Upgrade guard: the top-level docker inputs must keep rendering the same
# application_stack block as before application_stack existed, with every
# code runtime left unset.
run "docker_shorthand_renders_unchanged_block" {
  command = plan

  variables {
    docker_image_name   = "nginx:latest"
    docker_registry_url = "https://index.docker.io"
  }

  assert {
    condition     = length(azurerm_linux_web_app.this.site_config[0].application_stack) == 1
    error_message = "docker_image_name must still render one application_stack block."
  }

  assert {
    condition     = azurerm_linux_web_app.this.site_config[0].application_stack[0].docker_registry_url == "https://index.docker.io"
    error_message = "docker_registry_url must still be passed through."
  }

  assert {
    condition = alltrue([
      azurerm_linux_web_app.this.site_config[0].application_stack[0].dotnet_version == null,
      azurerm_linux_web_app.this.site_config[0].application_stack[0].go_version == null,
      azurerm_linux_web_app.this.site_config[0].application_stack[0].java_version == null,
      azurerm_linux_web_app.this.site_config[0].application_stack[0].java_server == null,
      azurerm_linux_web_app.this.site_config[0].application_stack[0].java_server_version == null,
      azurerm_linux_web_app.this.site_config[0].application_stack[0].node_version == null,
      azurerm_linux_web_app.this.site_config[0].application_stack[0].php_version == null,
      azurerm_linux_web_app.this.site_config[0].application_stack[0].python_version == null,
    ])
    error_message = "The docker shorthand must not set any code runtime."
  }
}

run "node_stack" {
  command = plan

  variables {
    application_stack = {
      node_version = "20-lts"
    }
  }

  assert {
    condition     = azurerm_linux_web_app.this.site_config[0].application_stack[0].node_version == "20-lts"
    error_message = "application_stack.node_version must be passed through."
  }

  assert {
    condition     = azurerm_linux_web_app.this.site_config[0].application_stack[0].docker_image_name == null
    error_message = "A code stack must not set docker_image_name."
  }
}

run "python_stack" {
  command = plan

  variables {
    application_stack = {
      python_version = "3.12"
    }
  }

  assert {
    condition     = azurerm_linux_web_app.this.site_config[0].application_stack[0].python_version == "3.12"
    error_message = "application_stack.python_version must be passed through."
  }
}

run "java_stack" {
  command = plan

  variables {
    application_stack = {
      java_version        = "17"
      java_server         = "JAVA"
      java_server_version = "17"
    }
  }

  assert {
    condition     = azurerm_linux_web_app.this.site_config[0].application_stack[0].java_server == "JAVA"
    error_message = "application_stack.java_server must be passed through."
  }
}

run "container_stack_via_application_stack" {
  command = plan

  variables {
    application_stack = {
      docker_image_name   = "nginx:latest"
      docker_registry_url = "https://index.docker.io"
    }
  }

  assert {
    condition     = azurerm_linux_web_app.this.site_config[0].application_stack[0].docker_image_name == "nginx:latest"
    error_message = "application_stack.docker_image_name must be passed through."
  }
}

run "rejects_two_runtimes" {
  command = plan

  variables {
    application_stack = {
      node_version   = "20-lts"
      python_version = "3.12"
    }
  }

  expect_failures = [var.application_stack]
}

run "rejects_empty_application_stack" {
  command = plan

  variables {
    application_stack = {}
  }

  expect_failures = [var.application_stack]
}

run "rejects_partial_java_stack" {
  command = plan

  variables {
    application_stack = {
      java_version = "17"
    }
  }

  expect_failures = [var.application_stack]
}

run "rejects_registry_url_without_image_in_stack" {
  command = plan

  variables {
    application_stack = {
      node_version        = "20-lts"
      docker_registry_url = "https://index.docker.io"
    }
  }

  expect_failures = [var.application_stack]
}

run "rejects_application_stack_with_docker_shorthand" {
  command = plan

  variables {
    docker_image_name = "nginx:latest"
    application_stack = {
      node_version = "20-lts"
    }
  }

  expect_failures = [azurerm_linux_web_app.this]
}
