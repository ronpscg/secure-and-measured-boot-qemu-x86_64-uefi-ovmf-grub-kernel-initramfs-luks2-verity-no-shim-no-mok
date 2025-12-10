#!/bin/bash
LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
cd $LOCAL_DIR

# There is common code, if this is comitted into source control it is just for 
# my personal use as I quickly hack things there
#----------- this section is common to the yocto file really ---------------------
: ${COMMON_CONFIG_FILE:=$LOCAL_DIR/../bitbake.env}

# Could run bitbake -e and get some environment variables, but I won't do that
: ${YOCTO_BUILD_DIR=$HOME/yocto/build-scarthgap-x86_64}
: ${MACHINE=genericx86-64}
: ${IMAGE_BASENAME=signing-wip}

TOPDIR=${YOCTO_BUILD_DIR}
DEPLOY_DIR=${TOPDIR}/tmp/deploy
DEPLOY_DIR_IMAGE=${DEPLOY_DIR}/images/${MACHINE}
SECURE_ARTIFACTS_BASE_SYMLINK="${DEPLOY_DIR_IMAGE}/secure-boot-work"
#--------------------------------------------------------------------------------
ARTIFACTS_DIR=$SECURE_ARTIFACTS_BASE_SYMLINK/artifacts
DIR=$ARTIFACTS_DIR
: ${OVMF_DIR=$(readlink -f $LOCAL_DIR/../../../OVMF-local)}
export OVMF_DIR
export OVMF_CODE=$OVMF_DIR/OVMF_CODE.fd
export OVMF_VARS=$OVMF_DIR/OVMF_VARS.fd
: ${TPM_STATE_DIR=$OVMF_DIR/tpm-state}
export TPM_STATE_DIR
SWTPM_SCRIPT=$LOCAL_DIR/../../qemu/swtpm-start.sh


: ${ESP_FS_FOLDER=$ARTIFACTS_DIR/ESP.fs}
: ${BOOT_FS_FOLDER=$ARTIFACTS_DIR/BOOT.fs}


export FAT_ESP_FS_DIR=$ESP_FS_FOLDER 

# Unencrypted
export ROOTFS_IMG=$DIR/rootfs.img
# Encrypted
#export ROOTFS_IMG=$DIR/rootfs.enc.img
export DMVERITY_HASH_IMG=${DIR}/dmverity-hash.img 


export GPT_COMBINED_DISK_IMG=$DIR/usb_image.hdd.img


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

check_ovmf_exists() {
	for ent in $OVMF_DIR $OVMF_CODE $OVMF_VARS ; do
		if [ ! -e $ent ] ; then
			error=true;
			echo -e "\e[31m$ent does not exist\e[0m"
		fi
	done
	if [ "$error" = "true" ] ; then
		recdir=/tmp/OVMF_dir_tmp/OVMF-local/
		echo "You don't have the OVMF materials. You can get an example, for example, from
		git clone https://github.com/ronpscg/example-test-secboot-qemu.git $recdir"
		echo "Then you can run
		OVMF_DIR=$recdir $0"

		exit 1
	fi
}

run_swtpm() {
	$SWTPM_SCRIPT || exit 1
}

main() {
	check_ovmf_exists
	if [ ! -e "$DIR" ] ; then
		echo -e "\e[31m${DIR} does not exist.\e[0m"
		echo "Please make sure it exists / set YOCTO_BUILD_DIR to the right path and make sure you have the correct materials there."
		exit 1
	fi
		
	run_swtpm

	if [ ! "$1" = "disk" ] ; then
		#dont_do_disk
		#dont_do_disk $@ #./tpm-run-qemu.sh		# Run this for image separation (could also actually provide the rootfs like this for an unencrypted/unverified case...
		dont_do_disk_encrypted $@ #./tpm-run-qemu.sh		# Run this for image separation (could also actually provide the rootfs like this for an unencrypted/unverified case...
	else
		shift
		do_disk $@ #./tpm-run-qemu-disk.sh		# Run this to run the entire disk image, as it would be present on a real hardware
	fi
}

main $@
