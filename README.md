# Managing Memory Tiers with CXL in Virtualized Environments

This repository contains source code and instructions to reproduce key results in the paper. There are four major components:
* Modified Linux kernel (based on v5.19) that supports page coloring and page exchange
* Modified QEMU (based on v6.2) with page coloring support
* Orchestrator for estimating VM slowdown and exchanging pages between VMs to improve performance

## Getting Started

First, clone this repository in a place that is large enough to compile Linux kernel:
```
git clone https://yuhong_zhong@bitbucket.org/yuhong_zhong/memstrata.git
cd memstrata
git submodule init
git submodule update --recursive
```

Compile and install Linux kernel:
```
./build_and_install_kernel.sh
```
This step will take some time since it needs to download the source code, install dependencies, and compile the kernel from scratch.

After the kernel is compiled and installed, you will be prompted to reboot into the Memstrata kernel:
```
sudo grub-reboot "Advanced options for Ubuntu>Ubuntu, with Linux 5.19.0-memstrata+"
sudo reboot
```
Note that other components can only be compiled when you are in the Memstrata kernel.

Then, build and install QEMU:
```
./build_and_install_qemu.sh
```

After that, build the orchestrator:
```
./build_orchestrator.sh
```

After building and installing all the components, you can create VMs by `./create_vm.sh [vm domain name (e.g., vm1)]`. The workloads used in our evaluation can be installed by running `./vm_install_workloads.sh` inside each VM. Note that SPEC and GAPBS workloads need to be install manually.

The VM configuration (number of cores and VM memory size) of each workload can be found in the `workload_scripts` folder, along with the scripts to prepare and run each workload in a VM.
