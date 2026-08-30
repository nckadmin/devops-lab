packer {
  required_plugins {
    hyperv = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/hyperv"
    }
  }
}

variable "iso_path" {
  type    = string
  default = "C:/iso/ubuntu-22.04.5.iso"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:9bc6028870aef3f74f4e16b900008179e78b130e6b0b9a140635434a46aa98b0"
}

variable "vm_name" {
  type    = string
  default = "ubuntu-base"
}

variable "output_dir" {
  type    = string
  default = "C:/devops-lab/packer/output"
}

variable "ssh_username" {
  type    = string
  default = "devops"
}

variable "ssh_password" {
  type      = string
  sensitive = true
}

source "hyperv-iso" "ubuntu" {
  vm_name          = var.vm_name
  iso_url          = var.iso_path
  iso_checksum     = var.iso_checksum
  output_directory = var.output_dir
  ssh_host         = "192.168.50.201"

  cpus      = 2
  memory    = 2048
  disk_size = 20480

  generation         = 2
  enable_secure_boot = false
  switch_name        = "Local"

  http_directory = "../http"
  http_port_min  = 8000
  http_port_max  = 8100

  boot_command = [
    "c<wait5>",
    "linux /casper/vmlinuz quiet autoinstall ds=nocloud-net\\;s=http://{{.HTTPIP}}:{{.HTTPPort}}/ ---<enter><wait5>",
    "initrd /casper/initrd<enter><wait5>",
    "boot<enter>"
  ]
  boot_wait = "15s"

  ssh_username     = var.ssh_username
  ssh_password     = var.ssh_password
  ssh_timeout      = "30m"
  shutdown_command = "sudo shutdown -h now"
  shutdown_timeout = "15m"
}

build {
  name    = "ubuntu-golden-image"
  sources = ["source.hyperv-iso.ubuntu"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y curl vim net-tools",
      "sudo cloud-init clean",
      "sudo rm -f /etc/ssh/ssh_host_*",
      "sudo truncate -s 0 /etc/machine-id"
    ]
  }
}
