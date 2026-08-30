# Render per-VM cloud-init user-data / meta-data from templates
resource "local_file" "user_data" {
  for_each = var.vms

  filename = "${var.vm_base_path}/${each.key}/cidata-src/user-data"
  content = templatefile("${path.module}/templates/user-data.tmpl", {
    hostname    = each.value.hostname
    ip_address  = each.value.ip_address
    gateway     = var.network_gateway
    dns_servers = join(", ", var.network_dns)
  })
}

resource "local_file" "meta_data" {
  for_each = var.vms

  filename = "${var.vm_base_path}/${each.key}/cidata-src/meta-data"
  content = templatefile("${path.module}/templates/meta-data.tmpl", {
    hostname = each.value.hostname
  })
}

# Build the cloud-init seed ISO for each VM using the local PowerShell helper
resource "null_resource" "cloud_init_iso" {
  for_each = var.vms

  depends_on = [local_file.user_data, local_file.meta_data]

  triggers = {
    user_data_hash = local_file.user_data[each.key].content_md5
    meta_data_hash = local_file.meta_data[each.key].content_md5
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      ${path.module}/scripts/Build-CloudInitIso.ps1 `
        -SourceDir "${var.vm_base_path}/${each.key}/cidata-src" `
        -OutputIso "${var.vm_base_path}/${each.key}/cidata.iso"
    EOT
  }
}

# Differencing disk cloned from the Packer golden image - each VM gets its
# own thin disk that only stores the delta from the base image
resource "hyperv_vhd" "vm_disk" {
  for_each = var.vms

  path      = "${var.vm_base_path}/${each.key}/${each.key}.vhdx"
  parent_path   = var.golden_image_path
  vhd_type  = "Differencing"
}

resource "hyperv_machine_instance" "vm" {
  for_each = var.vms

  name                             = each.value.hostname
  generation                       = 2
  processor_count                  = each.value.cpus
  static_memory                    = true
  memory_startup_bytes             = each.value.memory_mb * 1024 * 1024
  automatic_critical_error_action  = "Pause"

  vm_firmware {
    enable_secure_boot = "Off"
  }

  hard_disk_drives {
    controller_type     = "Scsi"
    controller_number   = 0
    controller_location = 0
    path                = replace(hyperv_vhd.vm_disk[each.key].path, "/", "\\")
  }

  dvd_drives {
    controller_number   = 0
    controller_location = 1
    path                = "${var.vm_base_path}/${each.key}/cidata.iso"
  }

  network_adaptors {
    name        = "Network Adapter"
    switch_name = var.vm_switch_name
  }

  depends_on = [
    hyperv_vhd.vm_disk,
    null_resource.cloud_init_iso
  ]
}
