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

#
# Make a copy of the images that will be dual slots, to keep QEMU happy
#
init_b_slots() {
	ROOTFS_IMG_B=$ROOTFS_IMG.b
	DMVERITY_HASH_IMG_B=$DMVERITY_HASH_IMG.b
	BOOT_FS_FOLDER_B=$BOOT_FS_FOLDER.b

	cp $ROOTFS_IMG $ROOTFS_IMG_B
	cp $DMVERITY_HASH_IMG $DMVERITY_HASH_IMG_B
	cp -aT $BOOT_FS_FOLDER $BOOT_FS_FOLDER_B

}

# Use this to add more drives, e.g. to account for the boot materials NOT being in the ESP partition, and to acount for A/B partition cases
set_a_b_params() {
	init_b_slots
	QEMU_DRIVE_PARAMS_P1=" -drive if=virtio,format=raw,file=fat:rw:$FAT_ESP_FS_DIR"
	if  [ "$PUT_BOOT_MATERIALS_IN_ESP_FS" = "true" ] ; then
		# rootfs partition
		QEMU_DRIVE_PARAMS_P2=" -drive if=virtio,format=raw,file=$ROOTFS_IMG"
		QEMU_DRIVE_PARAMS_P3=" -drive if=virtio,format=raw,file=$DMVERITY_HASH_IMG"
		if [ "$CREATE_DUAL_BOOT_AND_ROOTFS_PARTITIONS" = "true" ] ; then
			echo -e "\e[32mDual partitions - boot materials in ESP\e[0m"
			# redundant rootfs partition
			QEMU_DRIVE_PARAMS_P4=" -drive if=virtio,format=raw,file=$ROOTFS_IMG_B"
			QEMU_DRIVE_PARAMS_P5=" -drive if=virtio,format=raw,file=$DMVERITY_HASH_IMG_B"
		else
			echo -e "\e[32mBoot materials in ESP, single rootfs partition\e[0m"
		fi
	else
		# boot materials partition
		QEMU_DRIVE_PARAMS_P2=" -drive if=virtio,format=raw,file=fat:rw:$BOOT_FS_FOLDER"
		if [ "$CREATE_DUAL_BOOT_AND_ROOTFS_PARTITIONS" = "true" ] ; then
			echo -e "\e[32mDual partitions - boot materials in boot partitions\e[0m"
			# redundant boot materials partition
			QEMU_DRIVE_PARAMS_P3=" -drive if=virtio,format=raw,file=fat:rw:$BOOT_FS_FOLDER_B"
			# rootfs partition
			QEMU_DRIVE_PARAMS_P4=" -drive if=virtio,format=raw,file=$ROOTFS_IMG"
			QEMU_DRIVE_PARAMS_P5=" -drive if=virtio,format=raw,file=$DMVERITY_HASH_IMG"
			# redundant rootfs partition
			QEMU_DRIVE_PARAMS_P6=" -drive if=virtio,format=raw,file=$ROOTFS_IMG_B"
			QEMU_DRIVE_PARAMS_P7=" -drive if=virtio,format=raw,file=$DMVERITY_HASH_IMG_B"
		else
			echo -e "\e[32mSingle rootfs and boot partitions, boot materials in boot partition\e[0m"
			# rootfs partition
			QEMU_DRIVE_PARAMS_P3=" -drive if=virtio,format=raw,file=$ROOTFS_IMG"
			QEMU_DRIVE_PARAMS_P4=" -drive if=virtio,format=raw,file=$DMVERITY_HASH_IMG"
		fi
	fi
}

# For this let's just assume the previous default behavior, with 
set_a_only_params() {
	QEMU_DRIVE_PARAMS_P1=" -drive if=virtio,format=raw,file=fat:rw:$FAT_ESP_FS_DIR"
	if  [ "$PUT_BOOT_MATERIALS_IN_ESP_FS" = "true" ] ; then
		# rootfs partition
		QEMU_DRIVE_PARAMS_P2=" -drive if=virtio,format=raw,file=$ROOTFS_IMG"
		QEMU_DRIVE_PARAMS_P3=" -drive if=virtio,format=raw,file=$DMVERITY_HASH_IMG"
		echo -e "\e[32mBoot materials in ESP, single rootfs partition\e[0m"
	else
		# boot materials partition
		QEMU_DRIVE_PARAMS_P2=" -drive if=virtio,format=raw,file=fat:rw:$BOOT_FS_FOLDER"
		# rootfs partition
		QEMU_DRIVE_PARAMS_P3=" -drive if=virtio,format=raw,file=$ROOTFS_IMG"
		QEMU_DRIVE_PARAMS_P4=" -drive if=virtio,format=raw,file=$DMVERITY_HASH_IMG"
		echo -e "\e[32mSingle rootfs and boot partitions, boot materials in boot partition\e[0m"
	fi
}

add_data_partition() {
	# We could alternatively create an image file, and use it as another drive.
	# This will be done in the disks scripts, as this is a wonderful example of host mounts with QEMU, for filesystems that are not fat
	# Using virtiofsd is better performing, but is far my complex, so lets use 9p. Don't get too crazy about the features you use with 9p. It's powerful, but not all too powerful
	QEMU_DRIVE_PARAMS_DATA="-fsdev local,id=datafs,path=${DATA_FS_FOLDER},security_model=none \
				-device virtio-9p-pci,fsdev=datafs,mount_tag=host-datafs"

	if [ ! -d "$DATA_FS_FOLDER" ] ; then
		mkdir -p $DATA_FS_FOLDER || { echo "Failed to create $DATA_FS_FOLDER" ; exit 1 ; }
	fi

	# then, on target (assuming /data/ or your desired mountpoint exists):
	# grep -q host-datafs /sys/bus/virtio/drivers/9pnet_virtio/virtio*/mount_tag && mount -t 9p -o trans=virtio host-datafs /data
}

# Of course things could be done more elegantly. The entire thing here, or "challenge" is that using two different drives with the same image, will make QEMU unhappy
# 
main() {
	# the separation is to assist in debugging, and to not waste much time on scripting cleverness
	#set_a_only_params
	set_a_b_params
	QEMU_DRIVE_PARAMS_DATA=""
	QEMU_DRIVE_PARAMS=$(set | grep '^QEMU_DRIVE_PARAMS_P[0-9][0-9]*=' | cut -d= -f2- | tr -d \')
	add_data_partition

	echo -e "\e[34mUsing the following QEMU drive parameters: \n$QEMU_DRIVE_PARAMS\e[0m"

	./swtpm-start.sh || exit 1

	set -u # will fail any unset variables, so less code on checking the user called this script properly
	qemu-system-x86_64 -enable-kvm \
		-drive if=pflash,format=raw,unit=0,readonly=on,file=${OVMF_CODE} \
		-drive if=pflash,format=raw,unit=1,file=${OVMF_VARS} \
		$QEMU_DRIVE_PARAMS \
		$QEMU_DRIVE_PARAMS_DATA \
		-chardev socket,id=chrtpm,path=$TPM_STATE_DIR/swtpm-sock \
		-tpmdev emulator,id=tpm0,chardev=chrtpm \
		-device tpm-tis,tpmdev=tpm0 \
		-m 4G \
		-serial mon:stdio \
		"$@"
}

main $@

