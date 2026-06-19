output "vm_id" {
  description = "The ID of the provisioned Harvester Virtual Machine."
  value       = harvester_virtualmachine.vm.id
}

output "vm_name" {
  description = "The name of the provisioned Harvester Virtual Machine."
  value       = harvester_virtualmachine.vm.name
}

output "vm_namespace" {
  description = "The namespace of the provisioned Harvester Virtual Machine."
  value       = harvester_virtualmachine.vm.namespace
}

output "image_id" {
  description = "The ID of the Harvester image used for the virtual machine's root disk."
  value       = local.image_id
}

output "ssh_key_ids" {
  description = "The IDs of the SSH keys attached to the virtual machine."
  value       = local.ssh_keys
}
