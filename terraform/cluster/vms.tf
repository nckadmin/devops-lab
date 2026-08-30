variable "golden_image_path" {
  type        = string
  description = "Path to the Packer-built golden image VHDX"
  default     = "C:/devops-lab/packer/output/Virtual Hard Disks/ubuntu-base.vhdx"
}

variable "vm_switch_name" {
  type        = string
  description = "Hyper-V virtual switch to attach VMs to"
  default     = "Local"
}

variable "vm_base_path" {
  type        = string
  description = "Directory where cloned VM disks and config will live"
  default     = "C:/devops-lab/vms"
}

variable "network_gateway" {
  type    = string
  default = "192.168.50.254"
}

variable "network_dns" {
  type    = list(string)
  default = ["8.8.8.8", "1.1.1.1"]
}

# One entry per VM in the cluster. IPs are static, chosen outside the
# router's DHCP range (which handed out .73/.75 earlier) to avoid collisions.
variable "vms" {
  type = map(object({
    hostname   = string
    ip_address = string
    cpus       = number
    memory_mb  = number
    disk_gb    = number
  }))
  default = {
    "ctrl-01" = {
      hostname   = "ctrl-01"
      ip_address = "192.168.50.210"
      cpus       = 2
      memory_mb  = 4096
      disk_gb    = 40
    }
    "worker-01" = {
      hostname   = "worker-01"
      ip_address = "192.168.50.211"
      cpus       = 2
      memory_mb  = 4096
      disk_gb    = 40
    }
    "ci-01" = {
      hostname   = "ci-01"
      ip_address = "192.168.50.212"
      cpus       = 2
      memory_mb  = 4096
      disk_gb    = 40
    }
    "vault-01" = {
      hostname   = "vault-01"
      ip_address = "192.168.50.213"
      cpus       = 1
      memory_mb  = 2048
      disk_gb    = 20
    }
  }
}
