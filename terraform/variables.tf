variable "kubeconfig_path" {
  type        = string
  default     = "~/.kube/config"
  description = "The path to the kubeconfig file for the Harvester cluster. Ignored if kubeconfig_content is provided."
}

variable "kubeconfig_content" {
  type        = string
  default     = ""
  description = "The raw or base64-encoded kubeconfig content. Takes precedence over kubeconfig_path."
  sensitive   = true
}

variable "kubecontext" {
  type        = string
  default     = ""
  description = "The specific context to use within the kubeconfig file."
}

variable "vm_name" {
  type        = string
  description = "The name of the virtual machine to provision."
}

variable "vm_namespace" {
  type        = string
  default     = "default"
  description = "The Kubernetes namespace in Harvester to provision the virtual machine."
}

variable "cpu" {
  type        = number
  default     = 2
  description = "The number of CPU cores to allocate to the virtual machine."
}

variable "memory" {
  type        = string
  default     = "2Gi"
  description = "The amount of memory to allocate to the virtual machine (e.g., 2Gi, 4Gi)."
}

variable "run_strategy" {
  type        = string
  default     = "RerunOnFailure"
  description = "The run strategy for the VM. Options include: Always, RerunOnFailure, Halted, Manual."
}

variable "disk_size" {
  type        = string
  default     = "10Gi"
  description = "The disk space to allocate for the root volume (e.g., 10Gi, 20Gi)."
}

variable "disk_bus" {
  type        = string
  default     = "virtio"
  description = "The storage bus type for the disk. Options include: virtio, scsi, sata."
}

variable "use_existing_image" {
  type        = bool
  default     = true
  description = "Whether to use an existing image in Harvester or download a new one."
}

variable "image_name" {
  type        = string
  default     = "image-knp9r"
  description = "The name of the image (used if use_existing_image is true or to search for an existing image)."
}

variable "image_namespace" {
  type        = string
  default     = "default"
  description = "The namespace of the existing image (used if use_existing_image is true)."
}

variable "image_display_name" {
  type        = string
  default     = "sles15-sp7-nvidia.x86_64-15.7.0.qcow2"
  description = "The display name for the new image resource (used if use_existing_image is false)."
}

variable "image_download_url" {
  type        = string
  default     = "http://your-local-image-server/sles15-sp7-nvidia.x86_64-15.7.0.qcow2"
  description = "The URL to download the new image (used if use_existing_image is false)."
}

variable "network_name" {
  type        = string
  default     = ""
  description = "The NetworkAttachmentDefinition ID (e.g., namespace/network-name) to attach the VM to. If empty, the VM uses the default management network."
}

variable "create_ssh_key" {
  type        = bool
  default     = false
  description = "Whether to create a new SSH key resource in Harvester."
}

variable "ssh_key_name" {
  type        = string
  default     = ""
  description = "The name of an existing SSH key in Harvester, or the name to give the newly created SSH key."
}

variable "ssh_public_key" {
  type        = string
  default     = ""
  description = "The SSH public key content to import if create_ssh_key is true, or to inject via cloud-init."
}

variable "user_data" {
  type        = string
  default     = ""
  description = "Custom cloud-init user-data to configure the guest OS. If empty, a default configuration will be generated."
}
