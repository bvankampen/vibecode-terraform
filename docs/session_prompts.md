# Session Prompts

This document contains a chronological list of all instructions and prompts provided during this engineering session to provision, configure, and document the GPU-accelerated RKE2 guest environment on SUSE Harvester.

---

1. **Store documents**:
   > store these documents in current workspace directory

2. **Provision VM & RKE2**:
   > change vcpu to 4 and memory to 16GB, install RKE2 on the VM and install the GPU operator following this webpage https://registry.suse.com/repositories/third-party-nvidia-driver-sles15 download the kubeconfig in current directory

3. **Install Ollama**:
   > install ollama on rke2 use the biggest gemma4 model it can run in vram and make that the default

4. **Variables Template**:
   > create example terraform.tfvars and keep it up to date

5. **LAN Service Exposure**:
   > make ollama available to the lan on port 80 without https

6. **Documentation Update (Sample)**:
   > update documentation with ollama sample

7. **Documentation Update (Example)**:
   > update documentation with ollama example

8. **Restructuring & Security**:
   > Organize project in multiple folders, so it has a clean look, also check files which will to pushed to git for private information

9. **Relative Paths (First Request)**:
   > make path in documentation relative

10. **Relative Paths (Refinement)**:
    > make paths in documentation relative

11. **IP Address Generalization**:
    > change ip address in documentation to generic ones

12. **Prompts Log Request**:
    > can you also create a file with all prompts I gave in this session?
