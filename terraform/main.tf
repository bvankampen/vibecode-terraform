locals {
  # Use either the looked-up existing image ID or the newly downloaded image ID.
  image_id = var.use_existing_image ? data.harvester_image.selected[0].id : harvester_image.downloaded[0].id

  # Use either the newly created SSH key ID or the formatted ID of an existing key.
  ssh_keys = var.create_ssh_key ? [harvester_ssh_key.new[0].id] : (var.ssh_key_name != "" ? ["${var.vm_namespace}/${var.ssh_key_name}"] : [])

  # If custom user_data is provided, use it; otherwise, use the default cloud-config.yaml template.
  user_data = var.user_data != "" ? var.user_data : templatefile("${path.module}/cloud-config.yaml", {
    ssh_public_key = var.ssh_public_key
  })
}

# -----------------------------------------------------------------------------
# IMAGE CONFIGURATION
# -----------------------------------------------------------------------------

# Search for an existing Harvester Image if use_existing_image is true
data "harvester_image" "selected" {
  count     = var.use_existing_image ? 1 : 0
  name      = var.image_name
  namespace = var.image_namespace
}

# Create a new Harvester Image via download if use_existing_image is false
resource "harvester_image" "downloaded" {
  count        = var.use_existing_image ? 0 : 1
  name         = var.image_name
  namespace    = var.vm_namespace
  display_name = var.image_display_name
  source_type  = "download"
  url          = var.image_download_url

  # Images can be large; extend timeouts to prevent premature provisioning failures.
  timeouts {
    create = "20m"
    update = "20m"
    delete = "2m"
  }
}

# -----------------------------------------------------------------------------
# SSH KEY CONFIGURATION
# -----------------------------------------------------------------------------

# Optionally create a new SSH key resource in Harvester
resource "harvester_ssh_key" "new" {
  count      = var.create_ssh_key ? 1 : 0
  name       = var.ssh_key_name
  namespace  = var.vm_namespace
  public_key = var.ssh_public_key
}

# -----------------------------------------------------------------------------
# VIRTUAL MACHINE PROVISIONING
# -----------------------------------------------------------------------------

resource "harvester_virtualmachine" "vm" {
  name                 = var.vm_name
  namespace            = var.vm_namespace
  restart_after_update = false
  
  cpu          = var.cpu
  memory       = var.memory
  run_strategy = var.run_strategy
  machine_type = "q35"
  
  ssh_keys = local.ssh_keys

  network_interface {
    name           = "nic-0"
    network_name   = var.network_name != "" ? var.network_name : null
    wait_for_lease = true
  }

  disk {
    name        = "rootdisk"
    type        = "disk"
    size        = var.disk_size
    bus         = var.disk_bus
    boot_order  = 1
    image       = local.image_id
    auto_delete = true
  }

  cloudinit {
    type         = "noCloud"
    user_data    = local.user_data
    network_data = file("${path.module}/network-config.yaml")
  }

  # Self-healing GPU passthrough patch
  provisioner "local-exec" {
    command = "kubectl --kubeconfig ${var.kubeconfig_path} patch virtualmachine ${self.name} -n ${self.namespace} --type='json' -p='[{\"op\": \"add\", \"path\": \"/spec/template/spec/domain/devices/gpus\", \"value\": [{\"deviceName\": \"nvidia.com/AD106_GEFORCE_RTX_4060_TI\", \"name\": \"gpu0\"}]}]'"
  }

  # If dynamically provisioning a new image, ensure it completes before starting the VM.
  depends_on = [
    harvester_image.downloaded
  ]
}
