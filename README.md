# terraform-azurerm-app-service

Terraform module that manages an [Azure](https://azure.microsoft.com/) App
Service on Linux. It creates a service plan and a Linux web app together,
supports running a custom container image, and exposes the app's default
hostname.

## Usage

```hcl
module "app_service" {
  source = "github.com/moveeeax/terraform-azurerm-app-service"

  name                = "prod-webapp01"
  service_plan_name   = "prod-asp"
  resource_group_name = "prod-rg"
  location            = "eastus"
  sku_name            = "P1v3"

  identity_type = "SystemAssigned"

  app_settings = {
    WEBSITES_PORT = "8080"
  }

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Security defaults

The module ships with a hardened transport posture, all of it overridable:

| Setting                | Default      | Effect                                                        |
|------------------------|--------------|---------------------------------------------------------------|
| `https_only`           | `true`       | Plaintext HTTP is redirected to HTTPS.                        |
| `minimum_tls_version`  | `"1.2"`      | TLS 1.0/1.1 are rejected by validation, not just discouraged. |
| `ftps_state`           | `"Disabled"` | No FTP/FTPS deployment endpoint at all.                       |

`ftps_state = "AllAllowed"` accepts FTP credentials and deployment payloads in
the clear and is deliberately rejected by input validation; use `"FtpsOnly"` if
you need the endpoint. `minimum_tls_version` and `ftps_state` are set explicitly
on the resource rather than left to the provider's own defaults, so the module's
posture cannot silently weaken across a provider upgrade.

### `always_on` on Free and Shared plans

`always_on` defaults to `true`, but the Free (`sku_name = "F1"`) and Shared
(`sku_name = "D1"`) service plans don't support it — Azure rejects the apply
with "Always On is not supported for Free or Shared plans." A plan-time
precondition catches this combination before it reaches Azure; set
`always_on = false` explicitly when using either of those SKUs.

### Secrets in app settings

`app_settings` values are written to state and, without this module's
`sensitive` marking, would be echoed in plan output and CI logs. Do not put
secrets there as literals. Attach a managed identity, grant it read access on
the vault, and reference the secret instead:

```hcl
identity_type = "SystemAssigned"

app_settings = {
  DB_PASSWORD = "@Microsoft.KeyVault(SecretUri=https://<vault>.vault.azure.net/secrets/db-password/)"
}
```

Use `key_vault_reference_identity_id` when the vault should be reached through a
specific user-assigned identity rather than the system-assigned one. The
identity's principal ID is exposed as the `identity_principal_id` output so you
can wire up the Key Vault access policy or role assignment.
`key_vault_reference_identity_id` requires `identity_type` to be set — the
identity it names must actually be attached via the `identity` block, so
setting it with no identity attached is rejected at plan time.

## Requirements

| Name      | Version              |
|-----------|----------------------|
| terraform | >= 1.5               |
| azurerm   | >= 3.63.0, < 5.0     |

The azurerm floor is not cosmetic: `site_config.application_stack` only gained
`docker_image_name` and `docker_registry_url` in azurerm **3.63.0** (they
replaced `docker_image`/`docker_image_tag`, which 4.0 removed). On 3.62.1 and
older this module fails with `An argument named "docker_image_name" is not
expected here`.

Running the test suite additionally needs Terraform or OpenTofu >= 1.7 for
`mock_provider`; the module itself does not.

## Inputs

| Name                  | Description                                                        | Type          | Default | Required |
|-----------------------|--------------------------------------------------------------------|---------------|---------|:--------:|
| `name`                | Name of the Linux web app. Globally unique.                        | `string`      | n/a     |   yes    |
| `service_plan_name`   | Name of the service plan hosting the web app.                      | `string`      | n/a     |   yes    |
| `resource_group_name` | Name of the resource group in which to create the resources.       | `string`      | n/a     |   yes    |
| `location`            | Azure region in which to create the resources.                     | `string`      | n/a     |   yes    |
| `sku_name`            | SKU of the service plan.                                           | `string`      | `"B1"`  |    no    |
| `https_only`          | Whether the web app redirects all HTTP traffic to HTTPS.           | `bool`        | `true`  |    no    |
| `always_on`           | Whether the web app is always kept loaded. Must be `false` on `F1`/`D1` SKUs. | `bool` | `true`  |    no    |
| `minimum_tls_version` | Minimum TLS version for inbound HTTPS. One of `1.2`, `1.3`.        | `string`      | `"1.2"` |    no    |
| `ftps_state`          | FTP/FTPS endpoint state. One of `Disabled`, `FtpsOnly`.            | `string`      | `"Disabled"` | no  |
| `client_certificate_enabled` | Whether a TLS client certificate is requested from callers. | `bool`        | `false` |    no    |
| `client_certificate_mode` | Client certificate handling: `Required`, `Optional`, `OptionalInteractiveUser`. | `string` | `"Required"` | no |
| `identity_type`       | Managed identity: `SystemAssigned`, `UserAssigned`, `"SystemAssigned, UserAssigned"`, or null for none. | `string` | `null` | no |
| `identity_ids`        | User-assigned identity IDs. Required when `identity_type` includes `UserAssigned`. | `list(string)` | `[]` | no |
| `key_vault_reference_identity_id` | Identity used to resolve `@Microsoft.KeyVault()` app settings. Requires `identity_type`. | `string` | `null` | no |
| `docker_image_name`   | Docker image and tag to run. Null runs the default runtime.        | `string`      | `null`  |    no    |
| `docker_registry_url` | URL of the container registry hosting the image. Only effective with `docker_image_name` set. | `string` | `null` |    no    |
| `app_settings`        | Application settings exposed as environment variables. Sensitive.  | `map(string)` | `{}`    |    no    |
| `tags`                | Map of tags applied to the resources.                              | `map(string)` | `{}`    |    no    |

## Outputs

| Name               | Description                                    |
|--------------------|------------------------------------------------|
| `id`               | ID of the Linux web app.                       |
| `name`             | Name of the Linux web app.                     |
| `default_hostname` | Default hostname of the web app.               |
| `identity_principal_id` | Principal ID of the managed identity, or null when none is attached. |
| `service_plan_id`  | ID of the service plan hosting the web app.    |

## Testing

```sh
terraform init -backend=false
terraform test
```

The suite in [`tests/`](tests) uses `mock_provider`, so it runs with no Azure
credentials and no network.

## License

[MIT](LICENSE)
