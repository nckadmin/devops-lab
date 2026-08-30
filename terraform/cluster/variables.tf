variable "hyperv_user" {
  type        = string
  description = "Windows user for WinRM authentication (e.g. .\\User for local account)"
}

variable "hyperv_password" {
  type        = string
  sensitive   = true
  description = "Password for the WinRM user"
}
