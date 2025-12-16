#!/bin/bash
# Common file for paths etc.

#
# Underdocumented - but should be very clear for every bash reader... Maybe I will update it after I am done
#

set -a

#====================================================
#-------- Common Definitions: top directories -------
#====================================================
BUILD_TOP=$(readlink -f $(dirname ${BASH_SOURCE[0]})/..)
# Common project dir
: ${REQUIRED_PROJECTS_DIR=$HOME/pscg/secureboot-qemu-x86_64-efi-grub/components}
DL_DIR=$REQUIRED_PROJECTS_DIR
# There is an intended reduandancy (e.g. to store initial EFI variables or initramfs or rootfs before modifying it) so you can directly copy to the ARTIFACTS_DIR if you want to.
: ${REQUIRED_PROJECTS_ARTIFACTS_DIR=$REQUIRED_PROJECTS_DIR/artifacts} # These are the separate artifacts, to allow an easy place to store the build artifacts before modifying them
: ${ARTIFACTS_DIR=$HOME/pscg/secureboot-qemu-x86_64-efi-grub/artifacts}	# This is where everything will be after its all built and signed, and where the final image will be made out of "debuging images"

mkdir -p $REQUIRED_PROJECTS_DIR $REQUIRED_PROJECTS_ARTIFACTS_DIR $ARTIFACTS_DIR || { echo "Can't (re)create base directories" ; exit 1 ; }


: ${COMMON_CONFIG_FILE=$BUILD_TOP/local.config}
if [ -f $COMMON_CONFIG_FILE ] ; then
	. $COMMON_CONFIG_FILE
else
	echo -e "\x1b[33mWARN: you did not set a local configuration file. If you want to build a full image with your own GPG keys, you want to either populate $BUILD_TOP/local.config with your environment variables (for every overriden enviroment variable), or set the COMMON_CONFIG_FILE=<your config file> prior to sourcing $(basename $0)\x1b[0m"
fi

#----------------------------------------------------
# Image build tasks
#----------------------------------------------------
: ${MAKEIMAGE_STEP_DONT_COPY_KERNEL_AND_INITRAMFS=false}
: ${MAKEIMAGE_STEP_DONT_COPY_OVMF=false}
: ${MAKEIMAGE_STEP_DONT_UPDATE_GRUB_CONFIG=false}
: ${MAKEIMAGE_STEP_DONT_UPDATE_GRUB=false}
: ${MAKEIMAGE_STEP_DONT_COPY_GRUB=false}
: ${MAKEIMAGE_STEP_DONT_SIGN_GRUB_LOADED_ELEMENTS=false}
: ${MAKEIMAGE_STEP_DONT_SIGN_EFI_LOADED_ELEMENTS=false}


# Secure boot is relevant for several projects and their interaction
: ${SECURE_BOOT=true}

# A/B is relevant mostly for the imaging and QEMU. We disable it by default, to save in disk space
: ${CREATE_DUAL_BOOT_AND_ROOTFS_PARTITIONS=false}

#----------------------------------------------------
# ESP and boot materials definitions
# It is common in the sense that this is where kernel
# initramfs [device trees, cmdline if needed] will be
# accessible to the boot EFI program (e.g. GRUB) from.
#----------------------------------------------------

# Artifacts folder to do the actual "running" from
: ${ESP_FS_FOLDER=$ARTIFACTS_DIR/ESP.fs.folder}

: ${PUT_BOOT_MATERIALS_IN_ESP_FS=true}  # Note that this will affect your grub.cfg, so careful with that. 
if [ "$PUT_BOOT_MATERIALS_IN_ESP_FS" = "true" ] ; then
	BOOT_FS_FOLDER=$ESP_FS_FOLDER/boot
else
	: ${BOOT_FS_FOLDER=$ARTIFACTS_DIR/boot.fs.folder}
fi

# Location of keys certificates (PK, KEK, DB, ...) to provision to Firmware Setup menu. 
# It's easiest to just put them on the ESP partition, but you may want to put them e.g. on an another device and have it accessible only during provisioning.
# In fact if you use OVMF firmware setup menu, it's even easier to just put them directly under $ESP_FS_FOLDER as it will save you the "effort" of decending to the folder for finding the keys
# This has nothing to do with the boot loaders, only with the "Firmware Setup" menu (or its equivalents!)
: ${BOOT_UEFI_KEYS_FOLDER=$ESP_FS_FOLDER/keys}

#----------------------------------------------------
# more common definitions
#----------------------------------------------------
: ${LUKS_AND_DMVERITY_EXPORTED_ENV_FILE=$ARTIFACTS_DIR/luks-and-dmverity-kernel-cmdline-values.env} # aimed to be sourced when updating the bootloader materials

#====================================================
# Per external project ("component") building definitions
#====================================================

#----------------------------------------------------
# Kernel definitions
#----------------------------------------------------
# Doing tarball now, can do git instead
# all tarballs will just be downloaded directly into $REQUIRED_PROJECTS_DIR. Maybe it will be changed.
# PscgBuildOS and some of my other work organizes things more nicely and ALWAYS separates the source from the build directory. Since here everything was hacked brutally quickly,
# I am presenting the in folder way. Which is fine, as it is easier for most people either way

: ${KV=6.18}
KERNEL_BUILDER_DIR=${REQUIRED_PROJECTS_DIR}/linux-$KV
: ${KERNEL_CONFIG=$BUILD_TOP/kernel-configs/config-x86_64_tpm-dmcrypt-dmverity}

#----------------------------------------------------
# Grub definitions
#----------------------------------------------------
GRUB_BUILDER_DIR=${REQUIRED_PROJECTS_DIR}/grub
# This will be auto generated by the configuration files in the following line
: ${GRUB_CONFIG=$REQUIRED_PROJECTS_ARTIFACTS_DIR/grub.cfg}
export GRUB_CONFIG #TEMPORARY TODO FIND OUT WHY IN THE YOCTO HACK STUFF IT DOESNT APPEAR
# This is a list of one or more template configuration files to make a configuration from. The default value is just an example, modify them as you please in your local.config file
: ${GRUB_CONFIGS="\
	$BUILD_TOP/grub-configs/grub-basic-defs.cfg \
	$BUILD_TOP/grub-configs/grub-common-luks-dmverity-boot-functions.cfg \
	$BUILD_TOP/grub-configs/grub-luks-dmverity-entries.cfg \
	$BUILD_TOP/grub-configs/grub-fwsetup-between-separators.cfg \
	$BUILD_TOP/grub-configs/grub-rescue-mode-entries.cfg

"}

 : ${GRUB_CONFIGS=$BUILD_TOP/grub-configs/config-grub-wip.cfg}
 : ${GRUB_DEFAULT_ENTRY=0}
 : ${GRUB_DEFAULT_TIMEOUT=20}
# The PGP lines are required strictly for GRUB without SHIM 
# NB: (if UKI is not used - which for now it isn't for several reasons - one is ease of development, others are avoiding systemd-boot and chainloading etc.)
GRUB_PGP_PUBLIC_KEY=$ARTIFACTS_DIR/grub-pubkey.gpg
: ${GRUB_PGP_EMAIL=grubexample@thepscg.com}
: ${GRUB_GPG_KEY_ID=8A79B38F2589CE82C6BE80CB2C3D2B57F2161903}

# Everything is better with a standalone GRUB, but also allow a grub-mkimage variant.
# false: don't build standalone at all, and include some defaults and a config file (not entirely implemented yet) ; grub-mkimage - use grub-mkimage. grub-mkstandalone - use grub-mkstandalone
# my personal preference is to use grub-mkstandalone. Yocto Project's default would be to use false, but there are known issues with Scarthgap and Grub 2.12, so this entire "mechanism" is made due to that, and might be removed later altogether
: ${GRUB_BUILD_STANDALONE=false}

# Preparation for also copying or signing GRUB configuration files (this is for demonstrations and comparisons with some Yocto Project defaults)
# Could be extended to list of files and folder, but will likely not be (as I recommend to build a standalone this way or another)
: ${GRUB_COPY_FILES_TO_TARGET=true}

#----------------------------------------------------
# OVMF (EDK2) definitions
#----------------------------------------------------
EDK2_BUILDER_DIR=${REQUIRED_PROJECTS_DIR}/edk2

#----------------------------------------------------
# Initramfs (ramdisk) definitions - you mostly need it to work with encryption and verification "more easily".
#----------------------------------------------------

INITRAMFS_BUILDER_DIR=${REQUIRED_PROJECTS_DIR}/dockers/initramfs-builder


#----------------------------------------------------
# Rootfs builder (I would use PscgBuildOS for that, and presenting a specific debootstrap alternative)
#----------------------------------------------------
: ${ROOTFS_DEBOOTSTRAP_DIR=$REQUIRED_PROJECTS_ARTIFACTS_DIR/rootfs}
: ${ROOTFS_FS_FOLDER=$ROOTFS_DEBOOTSTRAP_DIR}


