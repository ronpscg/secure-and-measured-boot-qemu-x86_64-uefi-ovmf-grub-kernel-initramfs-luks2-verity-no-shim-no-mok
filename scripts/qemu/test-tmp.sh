#!/bin/bash
LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
. $LOCAL_DIR/../common.sh || { echo "Please run the script from the right place" ; exit 1 ; }
cd $LOCAL_DIR

DIR=$ARTIFACTS_DIR
export OVMF_CODE=$DIR/OVMF_CODE.fd
export OVMF_VARS=$DIR/OVMF_VARS.fd
export FAT_ESP_FS_DIR=$ESP_FS_FOLDER 

# Unencrypted
#export ROOTFS_IMG=$DIR/rootfs.img
# Encrypted
export ROOTFS_IMG=$DIR/rootfs.enc.img
export DMVERITY_HASH_IMG=${DIR}/dmverity-hash.img 

export TPM_STATE_DIR=${DIR}/tpm-state

export GPT_COMBINED_DISK_IMG=$DIR/usb_image.hdd.img

# If provided by an environmnet variable, pass them on. Otherwise - forget about them
# TODO: check := / = in common.sh or wherever that's used, as I dont remember exactly what I did, and probably need to make all the exports organized (used set -a)
export CREATE_DUAL_BOOT_AND_ROOTFS_PARTITIONS
export PUT_BOOT_MATERIALS_IN_ESP_FS

echo "Redundant boot/rootfs: $CREATE_DUAL_BOOT_AND_ROOTFS_PARTITIONS"
echo "Boot materials in ESP: $PUT_BOOT_MATERIALS_IN_ESP_FS"


if [ ! "$1" = "disk" ] ; then
	./tpm-run-qemu.sh $@		# Run this for image separation (could also actually provide the rootfs like this for an unencrypted/unverified case...
else
	shift
	./tpm-run-qemu-disk.sh $@	# Run this to run the entire disk image, as it would be present on a real hardware
fi
