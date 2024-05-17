#!/bin/bash
set -eux -o pipefail

if [ "$(uname -r)" !=  "5.19.0-memstrata+" ]; then
    printf "Not in Memstrata kernel. Please run the following commands to boot into Memstrata kernel:\n"
    printf "    sudo grub-reboot \"Advanced options for Ubuntu>Ubuntu, with Linux 5.19.0-memstrata+\"\n"
    printf "    sudo reboot\n"
    exit 1
fi

domain_name="$1"

sudo mkdir -p /var/lib/libvirt/images/$domain_name
sudo qemu-img create -f qcow2 -F qcow2 -o \
    backing_file=/var/lib/libvirt/images/base/focal-server-cloudimg-amd64.img \
    /var/lib/libvirt/images/$domain_name/$domain_name.qcow2
sudo qemu-img resize /var/lib/libvirt/images/$domain_name/$domain_name.qcow2 225G

cd /tmp
cat >meta-data <<EOF
local-hostname: $domain_name
EOF

export PUB_KEY=$(sudo cat /root/.ssh/id_rsa.pub)
if [ -z "$PUB_KEY" ]; then
    echo "Cannot find the public key of root"
    exit 1
fi

cat >user-data <<EOF
#cloud-config
users:
  - name: ubuntu
    ssh-authorized-keys:
      - $PUB_KEY
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: sudo
    shell: /bin/bash
runcmd:
  - echo "AllowUsers ubuntu" >> /etc/ssh/sshd_config
  - restart ssh
EOF

sudo genisoimage -output /var/lib/libvirt/images/$domain_name/$domain_name-cidata.iso -volid cidata -joliet -rock user-data meta-data

sudo virt-install --connect qemu:///system --virt-type kvm --name $domain_name \
    --ram $((32 * 1024)) --vcpus=16 -os-variant ubuntu20.04 \
    --disk path=/var/lib/libvirt/images/$domain_name/$domain_name.qcow2,format=qcow2 \
    --disk /var/lib/libvirt/images/$domain_name/$domain_name-cidata.iso,device=cdrom \
    --import --network network=default --noautoconsole

# TODO: modify XML to disable disk cache

sudo uvt-kvm wait $domain_name --insecure
