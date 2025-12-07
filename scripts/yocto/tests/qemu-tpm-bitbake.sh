#!/bin/bash
LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
#. $LOCAL_DIR/../common.sh || { echo "Please run the script from the right place" ; exit 1 ; }
cd $LOCAL_DIR

ARTIFACTS_DIR=/home/ron/secboot-ovmf-x86_64/yocto-artifacts
DIR=$ARTIFACTS_DIR
export OVMF_CODE=$DIR/OVMF_CODE.fd
export OVMF_VARS=$DIR/OVMF_VARS.fd


: ${ESP_FS_FOLDER=$ARTIFACTS_DIR/ESP.fs}
: ${BOOT_FS_FOLDER=$ARTIFACTS_DIR/BOOT.fs}


export FAT_ESP_FS_DIR=$ESP_FS_FOLDER 

# Unencrypted
export ROOTFS_IMG=$DIR/rootfs.img
# Encrypted
#export ROOTFS_IMG=$DIR/rootfs.enc.img
export DMVERITY_HASH_IMG=${DIR}/dmverity-hash.img 

export TPM_STATE_DIR=${DIR}/tpm-state

export GPT_COMBINED_DISK_IMG=$DIR/usb_image.hdd.img

: ${TPM_STATE_DIR=$PWD/tpm-state}
export TPM_STATE_DIR

#cd $(dirname ${BASH_SOURCE[0]})
./swtpm-start.sh || exit 1

dont_do_disk() {
set -u # will fail any unset variables, so less code on checking the user called this script properly
qemu-system-x86_64 -enable-kvm \
    -drive if=pflash,format=raw,unit=0,readonly=on,file=${OVMF_CODE} \
    -drive if=pflash,format=raw,unit=1,file=${OVMF_VARS} \
    -drive if=virtio,format=raw,file=fat:rw:$FAT_ESP_FS_DIR \
    -drive if=virtio,format=raw,file=$ROOTFS_IMG \
    -chardev socket,id=chrtpm,path=$TPM_STATE_DIR/swtpm-sock \
    -tpmdev emulator,id=tpm0,chardev=chrtpm \
    -device tpm-tis,tpmdev=tpm0 \
    -m 4G \
    $@


#    -drive if=virtio,format=raw,file=$DMVERITY_HASH_IMG \

}

dont_do_disk_encrypted() {
set -u # will fail any unset variables, so less code on checking the user called this script properly
export ROOTFS_IMG=$DIR/rootfs.enc.img
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
    $@
}
do_disk()  {
qemu-system-x86_64 -enable-kvm \
    -drive if=pflash,format=raw,unit=0,readonly=on,file=${OVMF_CODE} \
    -drive if=pflash,format=raw,unit=1,file=${OVMF_VARS} \
    -drive if=virtio,format=raw,file=$DIR/usb_image.hdd.img \
    -chardev socket,id=chrtpm,path=$TPM_STATE_DIR/swtpm-sock \
    -tpmdev emulator,id=tpm0,chardev=chrtpm \
    -device tpm-tis,tpmdev=tpm0 \
    -m 4G \
    $@
}


if [ ! "$1" = "disk" ] ; then
	#dont_do_disk
	#dont_do_disk $@ #./tpm-run-qemu.sh		# Run this for image separation (could also actually provide the rootfs like this for an unencrypted/unverified case...
	dont_do_disk_encrypted $@ #./tpm-run-qemu.sh		# Run this for image separation (could also actually provide the rootfs like this for an unencrypted/unverified case...
else
	shift
	do_disk $@ #./tpm-run-qemu-disk.sh		# Run this to run the entire disk image, as it would be present on a real hardware
fi
