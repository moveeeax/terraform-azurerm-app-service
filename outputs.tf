output "id" {
  description = "ID of the Linux web app."
  value       = azurerm_linux_web_app.this.id
}

output "name" {
  description = "Name of the Linux web app."
  value       = azurerm_linux_web_app.this.name
}

output "default_hostname" {
  description = "Default hostname of the web app."
  value       = azurerm_linux_web_app.this.default_hostname
}

output "identity_principal_id" {
  description = "Principal ID of the web app's managed identity, or null when no identity is attached. Grant this Key Vault access to use @Microsoft.KeyVault() app settings."
  value       = try(azurerm_linux_web_app.this.identity[0].principal_id, null)
}

output "service_plan_id" {
  description = "ID of the service plan hosting the web app."
  value       = azurerm_service_plan.this.id
}
