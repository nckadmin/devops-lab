terraform {
  required_providers {
    hyperv = {
      source  = "taliesins/hyperv"
      version = ">= 1.2.1"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
  }
}

# Terraform runs on the same Windows host as Hyper-V, so we connect
# back to ourselves over WinRM (127.0.0.1). In a real remote-server
# setup, this would point at the Hyper-V host address instead,
# ideally over HTTPS with certificates rather than plain Basic auth.
provider "hyperv" {
  user            = var.hyperv_user
  password        = var.hyperv_password
  host            = "127.0.0.1"
  port            = 5985
  https           = false
  insecure        = true
  use_ntlm        = true
  tls_server_name = ""
  cacert_path     = ""
  cert_path       = ""
  key_path        = ""
  script_path     = "C:/Temp/terraform_%RAND%.cmd"
  timeout         = "30s"
}
