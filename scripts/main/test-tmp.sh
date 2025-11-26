#!/bin/bash

DIR2=/home/ron/pscg/secureboot-qemu-x86_64-efi-grub/play


#export OVMF_CODE=/home/ron/pscg/secureboot-qemu-x86_64-efi-grub/edk2/Build/OvmfX64/RELEASE_GCC/FV/OVMF_CODE.fd
#export OVMF_VARS=${DIR}/OVMF_VARS_custom.fd

. ../common.sh
DIR=$ARTIFACTS_DIR
export OVMF_CODE=$DIR/OVMF_CODE.fd
export OVMF_VARS=$DIR/OVMF_VARS.fd
export FAT_ESP_FS_DIR=$ESP_FS_FOLDER 
export ROOTFS_IMG=$DIR/rootfs.img #${DIR2}/tmp-play/rootfs.enc.img 
export DMVERITY_HASH_IMG=${DIR2}/tmp-play/dmverity-hash.img 
export TPM_STATE_DIR=${DIR}/tpm-state

./tpm-run-qemu.sh
