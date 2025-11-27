#!/bin/bash

. ../common.sh || { echo "Please run this script from the correct place" ; exit 1 ; }

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

# ./tpm-run-qemu.sh		# Run this for image separation (could also actually provide the rootfs like this for an unencrypted/unverified case...
./tpm-run-qemu-disk.sh		# Run this to run the entire disk image, as it would be present on a real hardware
