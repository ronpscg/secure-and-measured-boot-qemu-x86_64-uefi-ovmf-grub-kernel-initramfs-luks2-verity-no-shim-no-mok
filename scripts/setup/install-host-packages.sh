#!/bin/bash
# Important note: Python/Bitbake/who knows what arre most likely BROKEN on 25.10
# Tested successfully on ubuntu:24.04, ubuntu,25.04

if lsb_release -d | grep "Ubuntu 2[0-9].[0-9][0-9]" ; then
	:
else
	echo -e "\e[31mThis was tested on several Ubuntu versions. Should work on recent Debian as well, but you may want to modify some of the packages names. Should also work on Fedora, with the equivalent packages\e[0m"
	exit 1
fi
	

export DEBIAN_FRONTEND=noninteractive
# Linux kernel standard stuff (nasm/iasl are not needed for the kernel. efitools - depends, usually you don't need them either. EDK2/OVMF requires all of them)
# libncurses is for make menuconfig
PACKAGES+=" build-essential nasm iasl efitools bison flex libelf-dev libssl-dev  bc libncurses-dev"
# General things that are useful
PACKAGES+=" git vim bash-completion"
# Debootstrap and rootfs tools (if you want to avoid superuser for debootstrapping you can use fakeroot or pseudo)
PACKAGES+=" sudo debootstrap"
# Native initramfs generation (without using Docker inside Docker)
PACKAGES+=" tpm2-tools"
# If you install dracut on your host, you need to be careful, so you may want to skip it unless you are sure you want to do it.
PACKAGES_SPECIAL+=" dracut"
# EDK2/OVMF
PACKAGES+=" uuid-runtime uuid-dev nasm iasl efitools python3-virt-firmware"
# Keep GRUB bootstrap and make (gawk) happy
PACKAGES+=" gettext libtool pkg-config autoconf autoconf-archive autopoint gawk"

: ${INSTALL_DOCKER=false}
if ! command -v docker >& /dev/null ; then
	if [ "$INSTALL_DOCKER" = "true" ] ; then
		# This step is for seamless integration with the current scripts, and running it within docker in docker. Do be careful of the chmod of the artifacts, all might need to be considered
		# Could change the building of the initramfs to be in the same docker instead (but it was mostly tested with Fedora)
		PACKAGES+=" docker.io"
	else
		echo -e "\e[33mWe prefer you take care of your own Docker installation, should you need it\e[0m"
		exit 1
	fi
fi

# Running OVMF with TPM
PACKAGES+=" swtpm qemu-system-x86"
# Rootfs encrpytion
PACKAGES+=" tpm2-tools cryptsetup"
# Image packaging (kpartx to avoid having udev inside Docker)
PACKAGES+=" parted dosfstools kpartx"

# Additions for building Yocto Project with KAS
PACKAGES+=" kas"
PACKAGES+=" locales chrpath diffstat lz4"

# Additions for squashfs support
PACKAGES+=" squashfs-tools"

# Could do with --no-install-recommends. However most people don't care so let it be this way
sudo apt-get install -y $PACKAGES && sudo locale-gen "en_US.UTF-8"

: ${INSTALL_SPECIAL_PACKAGES=false} 
if [ "$INSTALL_SPECIAL_PACKAGES" = "true" ]; then
	# The special packages include dracut or initramfs-tools - and they affect the host. You should NOT install them unless you know what you are doing, and do it manually
	# or make sure things are configured the way you want. A little slip and your host may become unbootable so careful here (hence the build in Docker solution)
	sudo apt-get install -y $PACKAGES_SPECIAL
fi
