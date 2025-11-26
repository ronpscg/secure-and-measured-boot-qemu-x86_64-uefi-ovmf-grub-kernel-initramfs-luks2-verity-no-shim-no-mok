#!/bin/bash
# start QEMU with TPM2 support (via swtpm2)
# Expectes the following variables to be set:
# 	OVMF_CODE OVMF_VARS
#	FAT_ESP_FS_DIR
#	ROOTFS_IMG
#	DMVERITY_HASH_IMG

set -a
: ${OVMF_CODE=}
: ${OVMF_VARS=}
: ${FAT_ESP_FS_DIR=}
: ${ROOTFS_IMG=}
: ${DMVERITY_HASH_IMG=}
: ${TPM_STATE_DIR=$PWD/tpm-state}
set +a

cd $(dirname ${BASH_SOURCE[0]})
./swtpm-start.sh || exit 1

set -u # will fail any unset variables, so less code on checking the user called this script properly
qemu-system-x86_64 -enable-kvm \
    -drive if=pflash,format=raw,unit=0,readonly=on,file=${OVMF_CODE} \
    -drive if=pflash,format=raw,unit=1,file=${OVMF_VARS} \
    -drive if=virtio,format=raw,file=fat:rw:$FAT_ESP_FS_DIR \
    -drive if=virtio,format=raw,file=$ROOTFS_IMG \
    -drive if=virtio,format=raw,file=$DMVERITY_HASH_IMG \
    -chardev socket,id=chrtpm,path=$TPM_STATE_DIR/swtpm-sock \
    -tpmdev emulator,id=tpm0,chardev=chrtpm \
    -device tpm-tis,tpmdev=tpm0 \
    -m 4G \
    -nographic


