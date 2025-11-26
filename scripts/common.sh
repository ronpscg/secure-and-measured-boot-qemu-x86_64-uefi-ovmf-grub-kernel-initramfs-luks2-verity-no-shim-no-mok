#!/bin/bash
# Common file for paths etc.

#
# Underdocuented - but should be very clear for every bash reader... Maybe I will update it after I am done
#

set -a

BUILD_TOP=$(readlink -f $(dirname ${BASH_SOURCE[0]})/..)
# Common project dir
: ${REQUIRED_PROJECTS_DIR=$HOME/pscg/secureboot-qemu-x86_64-efi-grub/components}
DL_DIR=$REQUIRED_PROJECTS_DIR
# There is an intended reduandancy (e.g. to store initial EFI variables or initramfs or rootfs before modifying it) so you can directly copy to the ARTIFACTS_DIR if you want to.
: ${REQUIRED_PROJECTS_ARTIFACTS_DIR=$REQUIRED_PROJECTS_DIR/artifacts} # These are the separate artifacts, to allow an easy place to store the build artifacts before modifying them
: ${ARTIFACTS_DIR=$HOME/pscg/secureboot-qemu-x86_64-efi-grub/artifacts}	# This is where everything will be after its all built and signed, and where the final image will be made out of "debuging images"

mkdir -p $REQUIRED_PROJECTS_DIR $REQUIRED_PROJECTS_ARTIFACTS_DIR $ARTIFACTS_DIR || { echo "Can't (re)create base directories" ; exit 1 ; }

# Doing tarball now, can do git instead
# all tarballs will just be downloaded directly into $REQUIRED_PROJECTS_DIR. Maybe it will be changed.
# PscgBuildOS and some of my other work organizes things more nicely and ALWAYS separates the source from the build directory. Since here everything was hacked brutally quickly,
# I am presenting the in folder way. Which is fine, as it is easier for most people either way

KV=6.18-rc7
KERNEL_BUILDER_DIR=${REQUIRED_PROJECTS_DIR}/linux-$KV
KERNEL_CONFIG=$BUILD_TOP/kernel-configs/config-x86_64_tpm-dmcrypt-dmverity

GRUB_BUILDER_DIR=${REQUIRED_PROJECTS_DIR}/grub
GRUB_CONFIG=$BUILD_TOP/grub-configs/config-grub-wip.cfg

EDK2_BUILDER_DIR=${REQUIRED_PROJECTS_DIR}/edk2

INITRAMFS_BUILDER_DIR=${REQUIRED_PROJECTS_DIR}/dockers/initramfs-builder

