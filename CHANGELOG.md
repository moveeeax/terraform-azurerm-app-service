# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `application_stack` input for code-based apps: exactly one of
  `dotnet_version`, `go_version`, `java_version` (with `java_server` and
  `java_server_version`), `node_version`, `php_version`, `python_version` or
  `docker_image_name` (with optional `docker_registry_url`). Validation
  rejects zero or several runtimes, a partial Java triple, and a registry URL
  without an image. Defaults to `null`, so existing plans do not change.
- The top-level `docker_image_name` and `docker_registry_url` inputs stay as
  a shorthand for a container stack and render the same block as before. A
  precondition rejects combining them with `application_stack`.

## [1.1.0] - 2026-11-05

### Added

- Plan-time preconditions: `always_on = true` on `F1`/`D1` plans,
  `key_vault_reference_identity_id` without an attached identity, and
  `docker_registry_url` without `docker_image_name`.

### Changed

- Allow azurerm 5.x (`< 6.0`).
- CI: bump actions, pin OpenTofu 1.13.8, add a tflint job, restrict the
  workflow token to `contents: read`, add Dependabot.

## [1.0.0]

Initial release (`v0.1.0` points at the same commit).

[Unreleased]: https://github.com/moveeeax/terraform-azurerm-app-service/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/moveeeax/terraform-azurerm-app-service/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/moveeeax/terraform-azurerm-app-service/releases/tag/v1.0.0
