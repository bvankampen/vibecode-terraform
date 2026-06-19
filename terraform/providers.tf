provider "harvester" {
  kubeconfig  = var.kubeconfig_content != "" ? var.kubeconfig_content : (var.kubeconfig_path != "" ? pathexpand(var.kubeconfig_path) : null)
  kubecontext = var.kubecontext != "" ? var.kubecontext : null
}
