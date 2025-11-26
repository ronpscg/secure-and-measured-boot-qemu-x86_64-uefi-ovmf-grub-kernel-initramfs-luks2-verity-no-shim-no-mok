#!/bin/bash
#
# https://github.com/ronpscg/initramfs-builder-for-systemd-dmcrypt-dmverity-tpm2-unlocker
#
# Note: one could use update-initramfs -c -b /tmp/bla -k 6.17.0-rc2 -v but it needs more configuration. The repo above uses dracut in a container

setup() (
	mkdir -p $REQUIRED_PROJECTS_DIR
	INITRAMFS_BUILDER_DIR=${REQUIRED_PROJECTS_DIR}/dockers/initramfs-builder
	mkdir -p $(dirname $INITRAMFS_BUILDER_DIR)
	git clone https://github.com/ronpscg/initramfs-builder-for-systemd-dmcrypt-dmverity-tpm2-unlocker $INITRAMFS_BUILDER_DIR
	cd $INITRAMFS_BUILDER_DIR
	./setup-and-build.sh
)

build() (
	echo "Basically already done by setup"
	# perhaps I will add just the docker build phase later
	return
)


copy_artifacts() {
	cp $INITRAMFS_BUILDER_DIR/workdir/fedora/initrd.img $REQUIRED_PROJECTS_ARTIFACTS_DIR # /home/ron/pscg/secureboot-qemu-x86_64-efi-grub/play/fs/boot/initrd.img
}

$1
