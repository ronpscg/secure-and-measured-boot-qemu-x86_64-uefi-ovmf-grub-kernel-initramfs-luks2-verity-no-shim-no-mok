#!/bin/bash
#
# Underdocuented - but should be very clear for every bash reader... Maybe I will update it after I am done
#

# Common project dir
REQUIRED_PROJECTS_DIR=/home/ron/pscg/secureboot-qemu-x86_64-efi-grub/

#
# https://github.com/ronpscg/initramfs-builder-for-systemd-dmcrypt-dmverity-tpm2-unlocker
#
# Note: one could use update-initramfs -c -b /tmp/bla -k 6.17.0-rc2 -v but it needs more configuration. The repo above uses dracut in a container

mkdir -p $REQUIRED_PROJECTS_DIR
INITRAMFS_BUILDER_DIR=${REQUIRED_PROJECTS_DIR}/dockers/initramfs-builder
mkdir -p $(dirname $INITRAMFS_BUILDER_DIR)
git clone https://github.com/ronpscg/initramfs-builder-for-systemd-dmcrypt-dmverity-tpm2-unlocker $INITRAMFS_BUILDER_DIR

(
cd $INITRAMFS_BUILDER_DIR
./setup-and-build.sh

cp $INITRAMFS_BUILDER_DIR/workdir/fedora/initrd.img /home/ron/pscg/secureboot-qemu-x86_64-efi-grub/play/fs/boot/initrd.img
)



