#!/bin/bash

set -euo pipefail

if [ -d $ROOTFS_DEBOOTSTRAP_DIR ] ; then
	echo "Assuming the rootfs is already setup"
	exit 0
fi
echo "[+] Debootstrapping Trixie"
sudo debootstrap --variant=minbase trixie $ROOTFS_DEBOOTSTRAP_DIR  
echo "Done debootstrapping $ROOTFS_DEBOOTSTRAP_DIR"

echo "[+} Adding more packages"
sudo chroot $ROOTFS_DEBOOTSTRAP_DIR bash -c "apt-get install -y tpm2-tools iproute2 iputils-ping vim fwupd efitools" 

sudo chroot $ROOTFS_DEBOOTSTRAP_DIR bash -c "apt-get clean"
# Could also remove $ROOTFS_DEBOOTSTRAP_DIR/var/lib/apt/lists/* won't do it here (It's ~55MB for what is installed in the previous line)

echo "[+] Applying some configurations"
sudo chroot $ROOTFS_DEBOOTSTRAP_DIR bash -c "echo -e 'root\nroot\n' | passwd root"
sudo chroot $ROOTFS_DEBOOTSTRAP_DIR bash -c "echo PscgSecureOS > /etc/hostname"


echo "DONE. Careful though: If you boot this rootfs as RO without taking care of writable places - you will be able to work - but login will likely be slow. This is expected, and per design"
