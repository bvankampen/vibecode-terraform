# Harvester VM Provisioning with Terraform

This project provides a production-ready, declarative Terraform template to provision and manage Virtual Machines on a [SUSE Harvester](https://harvesterhci.io/) hypervisor. 

---

## 📖 Architectural Context & Decisions ("The Why")

### 1. KubeVirt-Backed Cloud-Native Virtualization
Under the hood, Harvester acts as an enterprise hypervisor built on top of Kubernetes, KubeVirt, and Longhorn (see [Harvester Architecture](https://docs.harvesterhci.io/v1.2/architecture/)). Operating a Terraform provider allows infrastructure developers to treat virtualized workloads exactly like cloud instances. This repository ensures standard declarative management, removing the need for ad-hoc manual provisioning in the dashboard.

### 2. Mandatory QEMU Guest Agent Integration
This project injects a default cloud-init configuration (`cloud-config.yaml`) that installs and enables the `qemu-guest-agent` package inside the guest OS. This is a critical hypervisor best practice (see [Harvester VM Requirements](https://docs.harvesterhci.io/v1.2/install/requirements/#qemu-guest-agent)):
* It exposes the VM’s guest IP address directly to the Harvester console and API.
* It allows the KubeVirt controller to send graceful shutdown and reboot signals to the guest OS, preventing filesystem corruption during node maintenance.

### 3. Image Sourcing: Registry Catalog vs. On-Demand Fetch
To avoid race conditions and timeout issues, this template separates image handling:
* **Lookup (Default):** Directly references pre-staged images in the cluster's public catalog (e.g., `harvester-public` namespace), which drastically speeds up VM startup time.
* **On-Demand (`use_existing_image = false`):** Dynamically downloads, registers, and tracks the VM image using the `harvester_image` resource (see [Harvester Image Management](https://docs.harvesterhci.io/v1.2/images/)). It includes extended `timeouts` (20 minutes) to account for large QCOW2 downloads over WAN interfaces.

### 4. Dual-Mode Networking Strategy
* **Management Network (Overlay):** Default behavior utilizes the built-in Canal overlay network (see [Harvester Management Network](https://docs.harvesterhci.io/v1.2/networking/)). The template leverages this automatically when `network_name` is omitted, assigning an ephemeral pod IP suitable for internal microservice orchestration.
* **VLAN Networks (Bridge):** If `network_name` is supplied, the VM bridges directly onto physical networks using Multus CNI, allowing stable IP leases from physical DHCP systems.

---

## 📁 File Structure

```text
.
├── docs/                      # Authoritative runbooks and session logs
│   ├── deployment_configuration.md  # Comprehensive SLES/GPU/RKE2/Ollama setup guide
│   └── session_summary.md           # Engineering log of modified files and milestones
├── kubernetes/                # Kubernetes manifests and Helm value overrides
│   ├── kubeconfig             # Sanitized RKE2 cluster kubeconfig (git-ignored)
│   └── ollama-values.yaml     # Custom Helm overrides for GPU-accelerated Ollama
├── terraform/                 # OpenTofu/Terraform infrastructure modules
│   ├── cloud-config.yaml      # Default Cloud-Init user-data template
│   ├── main.tf                # Core VM resource declarations and lifecycle patches
│   ├── network-config.yaml   # Version 1 cloud-init network configuration
│   ├── outputs.tf             # Exported VM & network attributes
│   ├── providers.tf           # Harvester provider configuration block
│   ├── terraform.tfvars.example  # Secure, pre-structured variables template
│   ├── variables.tf           # Fully-typed input variables schema
│   └── versions.tf            # Provider and OpenTofu version constraints
└── README.md                  # Workspace-level entrypoint and LAN quickstart guide
```

---

## 🛠️ Prerequisites

1. **Terraform CLI**: Install Terraform `v1.3.0` or higher (see [Terraform Downloads](https://developer.hashicorp.com/terraform/downloads)).
2. **Kubeconfig Access**: Access to your Harvester cluster’s kubeconfig. You can download this from the top-right user menu in the **Harvester Dashboard** or via the support page (see [Harvester Kubeconfig Guide](https://docs.harvesterhci.io/v1.2/admin/support/#downloading-kubeconfig)).
3. **An OS Image**: Ensure a cloud-init-compatible image (such as Ubuntu, SLES, or Rocky Linux in `.qcow2` or `.raw` formats) exists in your Harvester catalog, or use the dynamic downloader.

---

## 🚀 Quick Start Guide

### Step 1: Initialize Configuration
Clone or copy this repository, change directory to the `terraform/` folder, and create your variable overrides file:
```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
```

### Step 2: Configure Your Credentials & VM Details
Open `terraform.tfvars` and adjust the variables to match your environment. At a minimum, set:
* `kubeconfig_path`: Points to your downloaded kubeconfig file.
* `vm_name`: The hostname/VM name.
* `ssh_public_key`: Your SSH public key string (for secure shell access).

Example:
```hcl
kubeconfig_path = "~/downloads/harvester-kubeconfig.yaml"
vm_name         = "prod-web-01"
create_ssh_key  = true
ssh_key_name    = "operator-key"
ssh_public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ..."
```

### Step 3: Run Terraform Operations
Initialize the directory to download the [Harvester Terraform Provider](https://registry.terraform.io/providers/harvester/harvester/latest):
```bash
terraform init
```

Generate and inspect the execution plan:
```bash
terraform plan
```

Deploy the virtual machine onto your cluster:
```bash
terraform apply
```

Confirm the deployment by typing `yes` when prompted.

---

## ⚙️ Configuration Reference

### Input Variables

| Name | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `kubeconfig_path` | `string` | `"~/.kube/config"` | Path to the kubeconfig file for the Harvester cluster. |
| `kubeconfig_content` | `string` | `""` | Raw/base64 kubeconfig content. Takes precedence over path if set. |
| `kubecontext` | `string` | `""` | Target Kubernetes context to execute under. |
| `vm_name` | `string` | **Required** | The name/hostname of the virtual machine. |
| `vm_namespace` | `string` | `"default"` | Target namespace on the cluster. |
| `cpu` | `number` | `2` | Number of CPU cores. |
| `memory` | `string` | `"2Gi"` | RAM capacity (e.g., `"4Gi"`). |
| `run_strategy` | `string` | `"RerunOnFailure"` | VM state lifecycle policy (`Always`, `RerunOnFailure`, `Halted`, `Manual`). |
| `disk_size` | `string` | `"10Gi"` | Storage space allocated to root disk. |
| `disk_bus` | `string` | `"virtio"` | The driver bus type. VirtIO is recommended for performance. |
| `use_existing_image` | `bool` | `true` | Set to false to trigger dynamic image download. |
| `image_name` | `string` | `"ubuntu-22.04..."` | Image catalog name or target name for download. |
| `image_namespace` | `string` | `"harvester-public"`| Source namespace of catalog image. |
| `create_ssh_key` | `bool` | `false` | Set to true to import a new public key. |
| `ssh_key_name` | `string` | `""` | Name of existing key or name of new key to register. |
| `ssh_public_key` | `string` | `""` | Raw public key text string. |
| `user_data` | `string` | `""` | Optional raw cloud-init YAML override. |

### Outputs

| Name | Description |
| :--- | :--- |
| `vm_id` | The cluster-wide unique ID of the virtual machine. |
| `vm_name` | The name of the provisioned VM. |
| `vm_namespace` | The namespace of the VM. |
| `image_id` | The exact image resource ID used for the root disk. |
| `ssh_key_ids` | The array of SSH Key resource IDs attached to the VM. |

---

## 🦙 Ollama LAN Inference Quick-Start

If Ollama has been deployed and exposed on port 80 via Ingress (see [ollama-values.yaml](kubernetes/ollama-values.yaml#L26-L51)), you can execute high-speed GPU-accelerated inference across your LAN without SSL constraints.

### 1. Curl Endpoint (Fast Validation)
```bash
curl -s -X POST http://<VM_IP>/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "prompt": "Why is SUSE ideal for enterprise virtualization?",
    "stream": false
  }'
```

### 2. Python Client (OpenAI SDK)
Ensure you have the standard SDK (`pip install openai`) and initialize targeting the RKE2 LAN Ingress:
```python
from openai import OpenAI

client = OpenAI(
    base_url="http://<VM_IP>/v1",
    api_key="ollama"  # Required but ignored
)

response = client.chat.completions.create(
    model="default",
    messages=[{"role": "user", "content": "Explain Kubernetes in one sentence."}],
    temperature=0.3
)

print(response.choices[0].message.content)
```

