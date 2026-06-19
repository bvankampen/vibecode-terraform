# Session Prompts

This document contains a complete and chronological list of all 34 instructions and prompts provided during this entire engineering session.

---

1. **Remove the signature**:
   > remove the AIcko signature

2. **Do not update the VM**:
   > do not update the vm

3. **Specify SLES15 SP7 image**:
   > Update the project to use SLES15 SP7 with this image: sles15-sp7-nvidia.x86_64-15.7.0.qcow2

4. **Specify image parameters**:
   > image_name is "sles15-sp7-nvidia.x86_64-15.7.0.qcow2" and image_display_name is "sles15-sp7-nvidia.x86_64-15.7.0.qcow2" this is an existing image

5. **Run tf init**:
   > run tf init

6. **Run tf plan**:
   > run tf plan and verify

7. **Switch kubeconfig**:
   > rerun task I switch kubeconfig

8. **Update public SSH key**:
   > change public ssh key to the one in @[id_ecdsa.pub]

9. **Change VM name**:
   > change vm name to test-vm

10. **Install packages request**:
    > do install packages

11. **Do not update but install packages**:
    > don't update and install packages

12. **Skip standard utility installations**:
    > don't install curl, wget and qemu-guest-agent and don't enable service

13. **Configure DHCP in cloudinit**:
    > configure networking in cloudinit for dhcp use v1 network config

14. **Apply Terraform**:
    > run terraform apply

15. **Use VLAN-1000 network overlay**:
    > change network to use vlan-1000 and redeploy vm

16. **Verify VM status**:
    > check if vm is deployed and online

17. **Check guest drivers**:
    > login to vm and check if nvidia drivers are installed

18. **Configure KubeVirt passthrough GPU**:
    > Add a GPU in passthrough mode to the VM

19. **Initiate documentation creation**:
    > Create two documents in markdown, one deployment configuration document and one document in which you describe what you have done in this session and which files you changed and what.

20. **Approve session_summary.md**:
    > [Approved] session_summary.md

21. **Approve deployment_configuration.md**:
    > [Approved] deployment_configuration.md

22. **Relocate documentation inside workspace**:
    > store these documents in current workspace directory

23. **Scale specifications and install RKE2 & GPU operator**:
    > change vcpu to 4 and memory to 16GB, install RKE2 on the VM and install the GPU operator following this webpage https://registry.suse.com/repositories/third-party-nvidia-driver-sles15 download the kubeconfig in current directory

24. **Configure Ollama & select Gemma 4**:
    > install ollama on rke2 use the biggest gemma4 model it can run in vram and make that the default

25. **Provide variables template**:
    > create example terraform.tfvars and keep it up to date

26. **Expose Ingress for LAN (Port 80)**:
    > make ollama available to the lan on port 80 without https

27. **Document Ollama (Sample)**:
    > update documentation with ollama sample

28. **Document Ollama (Example)**:
    > update documentation with ollama example

29. **Clean folder layout and check for secrets**:
    > Organize project in multiple folders, so it has a clean look, also check files which will to pushed to git for private information

30. **Relative Paths (Draft)**:
    > make path in documentation relative

31. **Relative Paths (Final)**:
    > make paths in documentation relative

32. **IP Generalization**:
    > change ip address in documentation to generic ones

33. **Prompts Log Request**:
    > can you also create a file with all prompts I gave in this session?

34. **Prompts Verification**:
    > why is the session prompts not complete?
