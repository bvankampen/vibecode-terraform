# Harvester GPU-Enabled SLES15 SP7 VM Deployment Configuration

This document provides the complete deployment and configuration specifications for provisioning a SUSE Linux Enterprise Server (SLES) 15 SP7 virtual machine with an attached physical NVIDIA GeForce RTX 4060 Ti GPU on a SUSE Harvester hypervisor, installing RKE2, and configuring the NVIDIA GPU Operator.

---

## 📋 1. Cluster Prerequisites

Before deploying the virtual machine, ensure the following host-level and cluster-level prerequisites are met on the Harvester cluster:

### A. IOMMU Enablement
Intel VT-d or AMD-Vi must be enabled in the BIOS/UEFI settings of the physical host nodes, and the kernel boot parameters must include `intel_iommu=on` or `amd_iommu=on`.

### B. PCI Devices Controller
The `pcidevices-controller` add-on must be enabled in the Harvester cluster (under **Advanced > Add-ons**). This controller manages the binding of PCI devices to the `vfio-pci` driver.

### C. GPU Device Passthrough Claims
The target NVIDIA GPU device must be enabled for passthrough in Harvester (**Advanced > PCI Devices**). This action generates a `PCIDeviceClaim` resource in the cluster:
*   **VGA Controller**: `harvester-node-000065000` (Address: `0000:65:00.0`, Vendor/Device ID: `10de:2803`)
*   **Audio Controller**: `harvester-node-000065001` (Address: `0000:65:00.1`, Vendor/Device ID: `10de:22bd`)

---

## 🛠️ 2. Core Infrastructure Files

The deployment is fully managed via OpenTofu in `terraform/` (relative to the repository root). The key files are defined below:

### A. Provider Configuration ([providers.tf](../terraform/providers.tf))
Configures the `harvester/harvester` provider to establish communication with the cluster API using a localized kubeconfig file.

```hcl
provider "harvester" {
  kubeconfig_path = var.kubeconfig_path
}
```

### B. Variables ([variables.tf](../terraform/variables.tf))
Declares input variables with validation schemas for CPU, memory, storage disk sizes, image lookup parameters, and network attachments.

### C. Active Values ([terraform.tfvars](../terraform/terraform.tfvars))
Defines the environment-specific configurations:
```hcl
kubeconfig_path    = "~/.kube/harvester.yaml"
vm_name            = "test-vm"
vm_namespace       = "default"
cpu                = 4
memory             = "16Gi"
disk_size          = "20Gi"
disk_bus           = "virtio"
use_existing_image = true
image_name         = "image-knp9r"
image_namespace    = "default"
network_name       = "harvester-public/vlan-1000"
create_ssh_key     = true
ssh_key_name       = "suse-ops-ssh"
ssh_public_key     = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBGjQmSndd0XroWLj3m27ntG5gCGNYCW8CuhCmCYjPhxSUPeW0Elj1cla86FQokhN6GFIaSQxBh+LXCpBREGbRY4= bas@geeko-p14s"
```

### D. Configuration Template ([terraform.tfvars.example](../terraform/terraform.tfvars.example))
A secure, anonymized variable configuration template mapping to all variables in [variables.tf](../terraform/variables.tf). It defines standard sizing defaults (4 vCPUs, 16Gi memory, 50Gi disk space) tailored for RKE2, GPU-acceleration, and Ollama:
*   Allows operators to copy-provision clean VMs with `cp terraform.tfvars.example terraform.tfvars`.
*   Keeps custom credentials (like base64 kubeconfig content or personal SSH keys) separate from tracked templates to prevent credential leakage.

### E. Network Configuration ([network-config.yaml](../terraform/network-config.yaml))
Enforces Version 1 cloud-init network config to bind DHCP on the primary physical interface:
```yaml
network:
  version: 1
  config:
    - type: physical
      name: eth0
      subnets:
        - type: dhcp
```

### F. User Data Configuration ([cloud-config.yaml](../terraform/cloud-config.yaml))
Sets up the cloud-init guest OS post-boot configuration, injecting the public key and explicitly turning off guest package upgrades to avoid drift:
```yaml
#cloud-config
ssh_authorized_keys:
  - ${ssh_public_key}

package_update: false
package_upgrade: false
```

---

## ⚙️ 3. Declarative VM Specification ([main.tf](../terraform/main.tf))

To resolve the limitation where the Harvester provider does not natively expose host GPU/PCI devices in its schema, `main.tf` is configured with a **self-healing lifecycle patch provisioner**.

```hcl
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

  depends_on = [
    harvester_image.downloaded
  ]
}
```

---

## ☸️ 4. RKE2 Installation on SLES15 SP7 Guest

RKE2 (v1.35.5+rke2r2) is installed in single-node control-plane mode on the VM guest.

### Installation Steps (Executed on VM Guest)
1. Install RKE2 server:
   ```bash
   curl -sfL https://get.rke2.io | INSTALL_RKE2_CHANNEL=stable INSTALL_RKE2_TYPE=server sudo sh -
   ```
2. Enable and start RKE2 systemd service:
   ```bash
   sudo systemctl enable --now rke2-server.service
   ```
3. Set up Kubeconfig access for the `sles` user:
   ```bash
   mkdir -p /home/sles/.kube
   sudo cp /etc/rancher/rke2/rke2.yaml /home/sles/.kube/config
   sudo chown -R sles:users /home/sles/.kube
   chmod 600 /home/sles/.kube/config
   ```

---

## 🚀 5. NVIDIA GPU Operator & Driver Configuration

The NVIDIA GPU Operator is configured to run on RKE2 using precompiled SLES15 drivers sourced from the SUSE Container Registry.

### Helm Configuration & Deployment
1. Register the Helm repository:
   ```bash
   helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
   helm repo update
   ```
2. Deploy the GPU Operator using SLES15 precompiled drivers and RKE2 containerd socket settings:
   ```bash
   helm install gpu-operator -n gpu-operator --create-namespace nvidia/gpu-operator \
     --version=v26.3.1 \
     --set driver.repository=registry.suse.com/third-party/nvidia \
     --set driver.version=580 \
     --set driver.usePrecompiled=true \
     --set toolkit.env[0].name=CONTAINERD_SOCKET \
     --set toolkit.env[0].value=/run/k3s/containerd/containerd.sock \
     --wait
   ```

---

## 💾 6. Local Storage Provisioner (local-path)

Because RKE2 does not include a dynamic storage provisioner by default, and to avoid custom manual hostPath volume configurations in workloads, Rancher's official lightweight **local-path-provisioner** (v0.0.35) was deployed. This provisioner manages persistent volume claims dynamically by backing them with directories in `/opt/local-path-provisioner` on the host VM.

### Installation & Configuration
1. Deploy the provisioner:
   ```bash
   kubectl --kubeconfig ./kubernetes/kubeconfig apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.35/deploy/local-path-storage.yaml
   ```
2. Set `local-path` as the default StorageClass for the cluster:
   ```bash
   kubectl --kubeconfig ./kubernetes/kubeconfig patch storageclass local-path -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'
   ```

---

## 🦙 7. Ollama & Gemma 4 Integration

Ollama is deployed in the RKE2 cluster to run the latest Gemma 4 family of models, leveraging the passthrough hardware acceleration.

### A. GPU Memory Capacity & Model Selection Analysis
The physical passthrough GPU is an **NVIDIA GeForce RTX 4060 Ti** with exactly **`8188MiB` (8.0 GB)** of dedicated VRAM (verified via `nvidia-smi` on the guest VM).
To determine the biggest **Gemma 4** model that can run **entirely in VRAM** (preventing CPU offloading which degrades inference speed), we analyzed the official Ollama download sizes:
*   `gemma4:e2b` (Effective 2B): **~7.2 GB** — Fits fully within the 8.0 GB VRAM.
*   `gemma4:e4b` (Effective 4B): **~9.6 GB** — Exceeds the 8.0 GB VRAM.
*   `gemma4:12b` (Dense 12B): **~9.6–12 GB** — Exceeds the 8.0 GB VRAM.

Thus, **`gemma4:e2b`** is the largest Gemma 4 model that can run 100% inside the GPU's VRAM.

### B. Helm Configuration ([ollama-values.yaml](../kubernetes/ollama-values.yaml))
We configure the `otwld/ollama` Helm deployment with:
1.  **Persistence**: Bound to a 30Gi claim on our `local-path` StorageClass to save downloaded weights permanently.
2.  **GPU limits**: Automatically requests and maps `nvidia.com/gpu: 1`.
3.  **Default Model Mapping**: Leverages the `create` directive to construct a custom model named `default` that inherits from `gemma4:e2b`.
4.  **LAN Access (Port 80 HTTP)**: Includes a custom `networking.k8s.io/v1` `Ingress` in `extraObjects`. By omitting the `host` matching constraint, RKE2's embedded NGINX Ingress controller routes all external port 80 LAN traffic (e.g. `http://<VM_IP>/`) directly to the backend Ollama service. High-performance timeouts are annotated to prevent 504 gateway timeouts on long LLM inference streams.

```yaml
persistentVolume:
  enabled: true
  storageClass: "local-path"
  size: 30Gi

ollama:
  gpu:
    enabled: true
    type: "nvidia"
    number: 1
    nvidiaResource: "nvidia.com/gpu"
  models:
    pull:
      - "gemma4:e2b"
    create:
      - name: default
        template: |
          FROM gemma4:e2b

# Extra Kubernetes manifests to deploy
extraObjects:
  - apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: ollama-lan-ingress
      namespace: ollama
      annotations:
        nginx.ingress.kubernetes.io/proxy-read-timeout: "1800"
        nginx.ingress.kubernetes.io/proxy-send-timeout: "1800"
        nginx.ingress.kubernetes.io/proxy-body-size: "4g"
    spec:
      ingressClassName: nginx
      rules:
        - http:
            paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: ollama
                    port:
                      number: 11434
```

### C. Installation Command
```bash
helm upgrade --install ollama otwld/ollama \
  --namespace ollama --create-namespace \
  -f ./kubernetes/ollama-values.yaml \
  --kubeconfig ./kubernetes/kubeconfig
```

---

## 🔎 8. Post-Deployment Verification

### A. Verify GPU Operator Pod Status
All operator pods should be in `Running` or `Completed` state:
```bash
kubectl --kubeconfig ./kubernetes/kubeconfig get pods -n gpu-operator
```

### B. Verify GPU Allocation inside RKE2 Node
Describing the node will show `nvidia.com/gpu: 1` in both `Capacity` and `Allocatable` blocks:
```bash
kubectl --kubeconfig ./kubernetes/kubeconfig get node test-vm -o jsonpath='{.status.allocatable}'
```

### C. Verify Ollama Pod & Storage Bounds
Check that the Ollama pod is running and its PVC is successfully bound:
```bash
kubectl --kubeconfig ./kubernetes/kubeconfig get pods,pvc -n ollama
```

### D. Verify Ollama Model Pull & Custom Creation Logs
Verify that Ollama successfully pulled `gemma4:e2b` and registered the `default` model:
```bash
kubectl --kubeconfig ./kubernetes/kubeconfig logs -n ollama -l app.kubernetes.io/name=ollama --tail=100
```

### E. Run Local Inference Test
Exec into the Ollama container and test that the `default` model responds correctly and runs on the RTX 4060 Ti GPU:
```bash
kubectl --kubeconfig ./kubernetes/kubeconfig exec -it -n ollama deploy/ollama -- ollama run default "Why is SLES 15 SP7 ideal for edge workloads?"
```

---

## 🚀 9. LAN API Usage Examples & Samples

Once Ollama is deployed and exposed via the custom LAN Ingress (configured in [ollama-values.yaml](../kubernetes/ollama-values.yaml#L26-L51)), clients across the network can query the API server remotely on standard HTTP port 80 using the node's LAN IP address (`<VM_IP>`).

### A. Command-Line Interface (cURL)

#### 1. Text Generation (Non-Streaming)
```bash
curl -s -X POST http://<VM_IP>/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "prompt": "Explain the benefit of KubeVirt in 2 sentences.",
    "stream": false
  }'
```

#### 2. OpenAI-Compatible Chat Completions
Ollama exposes an OpenAI-compliant gateway. This allows you to point any OpenAI-compatible app directly to your local cluster:
```bash
curl -s -X POST http://<VM_IP>/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "messages": [
      {"role": "system", "content": "You are a helpful SUSE cloud architect."},
      {"role": "user", "content": "Why run Ollama on RKE2?"}
    ],
    "temperature": 0.2
  }'
```

### B. Python Integration Samples

#### 1. Standard HTTP Client (`requests`)
```python
import requests

url = "http://<VM_IP>/api/generate"
payload = {
    "model": "default",
    "prompt": "What are the core components of RKE2?",
    "stream": False
}

try:
    response = requests.post(url, json=payload, timeout=60)
    response.raise_for_status()
    print(response.json().get("response"))
except Exception as e:
    print(f"Failed to query Ollama: {e}")
```

#### 2. Official `openai` SDK Integration
You can use the official OpenAI Python package (`pip install openai`) by pointing the base URL to your cluster's ingress gateway:
```python
from openai import OpenAI

# Initialize client pointing to the RKE2 LAN Ingress
client = OpenAI(
    base_url="http://<VM_IP>/v1",
    api_key="ollama"  # Required by the SDK block, but ignored by Ollama
)

try:
    response = client.chat.completions.create(
        model="default",
        messages=[
            {"role": "user", "content": "Compare RKE2 and K3s in one sentence."}
        ],
        temperature=0.3
    )
    print(response.choices[0].message.content)
except Exception as e:
    print(f"Error querying OpenAI SDK endpoint: {e}")
```


