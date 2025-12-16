#!/bin/bash
set -euo pipefail
LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
. $LOCAL_DIR/../common.sh || { echo "Please run the script from the right place" ; exit 1 ; }

# These can be common as they are defined in several scripts, but they are consistent, and there are still not too many partitions.
# It makes it easier for the learner to look at each file separately without jumping back and forth, and also clearly specifies the requirements/dependencies in the same file
: ${BOOTFS_IMG=$ARTIFACTS_DIR/bootfs.img}
: ${ROOTFS_IMG=$ARTIFACTS_DIR/rootfs.img}
: ${ROOTFS_ENC_IMG="$ARTIFACTS_DIR/rootfs.enc.img"}
: ${DMVERITY_ROOTFS_HASH_IMG=$ARTIFACTS_DIR/dmverity-hash.img}
: ${GPT_COMBINED_DISK_IMG=$ARTIFACTS_DIR/usb_image.hdd.img}

OUTPUT_IMG=$GPT_COMBINED_DISK_IMG

# Handle systemd-less/udveless containers (especially if they are privileged [not that they should be, but remembering which CAP are required for what is harder ;-) ])
setup_loopdev() {
	LOOP_DEV=$(sudo losetup -P --show -f "$OUTPUT_IMG")
	echo "    Mapped to $LOOP_DEV"

	# Inside docker (unless run with systemd), do a manual step to probe the partitions
	# It will happen if you see something like "systemd-udevd is not running." from parted above
	if ! pgrep systemd-udevd ; then
		_LOOP_DEV=${LOOP_DEV}
		sudo kpartx -a ${LOOP_DEV}
		LOOP_DEV=/dev/mapper/$(basename $LOOP_DEV)
	fi
}

teardown_loopdev() {
	if [[ "$LOOP_DEV" =~ /dev/mapper ]] ; then
		sudo kpartx -d $_LOOP_DEV
	fi
	sudo losetup -d "$_LOOP_DEV"
}

#
# This was the original implementation, and is left here as it resembles simplicity and is easier to look at.
#
set_a_only_partitions_boot_materials_in_esp() {
	# 2. RootFS Partition (Name: ROOTFS - I usually like calling them "system" [because of Android really, just stuck with me over the years] - but as this is an EFI tutorial, it can be confusing)
	# We use 'ext4' as a placeholder type for a Linux data partition. Could be any other file system.
	# We will overwrite the actual filesystem with dd later.
	START_ROOT=${ESP_SIZE_MIB}
	END_ROOT=$((START_ROOT + ROOT_SIZE_MIB))
	parted -s "$OUTPUT_IMG" mkpart ROOTFS ext4 ${START_ROOT}MiB ${END_ROOT}MiB

	# 3. Verity Hash Partition (Name: HASH)
	START_HASH=${END_ROOT}
	END_HASH=$((START_HASH + HASH_SIZE_MIB))
	parted -s "$OUTPUT_IMG" mkpart DMVERITY_HASH ext4 ${START_HASH}MiB ${END_HASH}MiB
	echo "[+] Setting up a work phase loop device and mapping the image..."
	setup_loopdev
	# Define partition devices (handling loop device naming like /dev/loop0p1)
	# ESP
	P1="${LOOP_DEV}p1"
	P2="${LOOP_DEV}p2"
	P3="${LOOP_DEV}p3"

	echo "[+] Populating Partition 1 (ESP, or \"EFI Boot\")..."
	sudo mkfs.vfat -F 32 -n "ESP_EFIBOOT" "$P1"
	MOUNTPOINT=$(mktemp -d)
	sudo mount "$P1" "$MOUNTPOINT"
	echo "    Copying files from $ESP_FS_FOLDER..."
	sudo cp -r "$ESP_FS_FOLDER"/* "$MOUNTPOINT"/
	sudo umount "$MOUNTPOINT"
	rmdir "$MOUNTPOINT"


	echo "[+] Populating Partition 2 (rootfs)..."
	sudo dd if="$ROOTFS_ENC_IMG" of="$P2" bs=4M status=progress

	echo "[+] Populating Partition 3 (DM_VERITY hash image)..."
	sudo dd if="$DMVERITY_ROOTFS_HASH_IMG" of="$P3" bs=4M status=progress
}


#
# This is a helper function etting the partition table
# Let's assume here that we want dual partitions for both rootfs and boot, and that the boot materials are in boot
#
setup_partition_table() {
	echo "Setting dual boot partitions"
	START_P2=${ESP_SIZE_MIB}
	END_P2=$((START_P2 + BOOT_SIZE_MIB))
	TYPE_P2=ext4
	parted -s "$OUTPUT_IMG" mkpart BOOT_A ext4 ${START_P2}MiB ${END_P2}MiB

	START_P3=${END_P2}
	END_P3=$((START_P3 + BOOT_SIZE_MIB))
	TYPE_P3=ext4
	parted -s "$OUTPUT_IMG" mkpart BOOT_B ext4 ${START_P3}MiB ${END_P3}MiB

	echo "Setting dual rootfs + verity hash image partition"
	START_P4=${END_P3}
	END_P4=$((START_P4 + ROOT_SIZE_MIB))
	TYPE_P4=ext4
	parted -s "$OUTPUT_IMG" mkpart ROOTFS_A ext4 ${START_P4}MiB ${END_P4}MiB

	START_P5=${END_P4}
	END_P5=$((START_P5 + HASH_SIZE_MIB))
	TYPE_P5=ext4
	parted -s "$OUTPUT_IMG" mkpart DMVERITY_HASH_A ext4 ${START_P5}MiB ${END_P5}MiB

	START_P6=${END_P5}
	END_P6=$((START_P6 + ROOT_SIZE_MIB))
	TYPE_P6=ext4
	parted -s "$OUTPUT_IMG" mkpart ROOTFS_B ext4 ${START_P6}MiB ${END_P6}MiB

	START_P7=${END_P6}
	END_P7=$((START_P7 + HASH_SIZE_MIB))
	TYPE_P7=ext4
	parted -s "$OUTPUT_IMG" mkpart DMVERITY_HASH_B ext4 ${START_P7}MiB ${END_P7}MiB
}

#
# This function accounts for the boot materials NOT being in the ESP partition, and to acount for A/B partition cases
# If you flash both banks of a partition, and have a look by the UUID for loading, e.g. a ROOTFS, you need to be carfeul of your OS choice.
# PscgBuildOS explains it in a greater detail. In general, usually you won't be flashing all banks, always. But you may choose to do so if you want to
#
set_a_b_partitions() {
	if [ "$PUT_BOOT_MATERIALS_IN_ESP_FS" = "true" -a "$CREATE_DUAL_BOOT_AND_ROOTFS_PARTITIONS" = "false" ] ; then
		set_a_only_partitions_boot_materials_in_esp
		return
	fi

	setup_partition_table

	echo "[+] Setting up a work phase loop device and mapping the image..."
	setup_loopdev

	P1=${LOOP_DEV}p1
	echo "[+] Populating Partition 1 (ESP, or \"EFI Boot\")..."
	sudo mkfs.vfat -F 32 -n "ESP_EFIBOOT" "$P1"
	MOUNTPOINT=$(mktemp -d)
	sudo mount "$P1" "$MOUNTPOINT"
	echo "    Copying files from $ESP_FS_FOLDER..."
	sudo cp -r "$ESP_FS_FOLDER"/* "$MOUNTPOINT"/
	sudo umount "$MOUNTPOINT"
	rmdir "$MOUNTPOINT"

	echo "[+] Populating the rest of the Linux partitions"
        if  [ "$PUT_BOOT_MATERIALS_IN_ESP_FS" = "true" ] ; then
		bootfs_a=""
		bootfs_b=""
		rootfs_a=p2
		dmverity_hash_a=p3
		if [ "$CREATE_DUAL_BOOT_AND_ROOTFS_PARTITIONS" = "true" ] ; then
			rootfs_b=p4
			dmverity_hash_b=p5
		fi
	else
		bootfs_a=p2
		bootfs_b=p3
		rootfs_a=p4
		dmverity_hash_a=p5
		if [ "$CREATE_DUAL_BOOT_AND_ROOTFS_PARTITIONS" = "true" ] ; then
			rootfs_b=p6
			dmverity_hash_b=p7
		fi
	fi

	if [ -n "$bootfs_a" ] ; then
		echo "[+] Populating $bootfs_a (bootfs)..."
		sudo dd bs=4M status=progress if="$BOOTFS_IMG" of=${LOOP_DEV}${bootfs_a} 
	fi
	if [ -n "$bootfs_b" ] ; then
		echo "[+] Populating $bootfs_b (bootfs)..."
		sudo dd bs=4M status=progress if="$BOOTFS_IMG" of=${LOOP_DEV}${bootfs_b} 
	fi
	if [ -n "$rootfs_a" ] ; then
		echo "[+] Populating $rootfs_a (rootfs)..."
		sudo dd bs=4M status=progress if="$ROOTFS_ENC_IMG" of=${LOOP_DEV}${rootfs_a} 
	fi
	if [ -n "$rootfs_b" ] ; then
		echo "[+] Populating $rootfs_b (rootfs)..."
		sudo dd bs=4M status=progress if="$ROOTFS_ENC_IMG" of=${LOOP_DEV}${rootfs_b} 
	fi
	if [ -n "$dmverity_hash_a" ] ; then
		echo "[+] Populating $dmverity_hash_a (DM_VERITY hash image)..."
		sudo dd bs=4M status=progress if="$DMVERITY_ROOTFS_HASH_IMG" of=${LOOP_DEV}${dmverity_hash_a} 
	fi
	if [ -n "$dmverity_hash_b" ] ; then
		echo "[+] Populating $dmverity_hash_b (DM_VERITY hash image)..."
		sudo dd bs=4M status=progress if="$DMVERITY_ROOTFS_HASH_IMG" of=${LOOP_DEV}${dmverity_hash_b} 
	fi
}

#
# This is not done in the boot materials generation, because it is not really needed there, but it would make more sense to make it there
# 
make_boot_image_partition() {
	$LOCAL_DIR/make-images-bootfs.sh
}

create_gpt_image_simple_a_only_partitions_boot_materials_in_esp() {
	echo -e "\x1b[42mWelding  $ESP_FS_FOLDER $ROOTFS_ENC_IMG $DMVERITY_ROOTFS_HASH_IMG ---> \x1b[31m$OUTPUT_IMG\x1b[0m"

	# Sizes in MiB (M in dd means MiB, not MB)
	ESP_SIZE_MIB=200 # Could check the size of the disk and add some - but basically 200 is a lot, and gives >100MB for extra (test) images even if the "boot partition" is on the ESP itself (e.g. <ESP>/boot)
	BOOT_SIZE_MIB=$(( $(du -b "$BOOTFS_IMG" | cut -f1) / 1024 / 1024 + 1 ))
	# Get size of your existing images in MiB (rounded up)
	ROOT_SIZE_MIB=$(( $(du -b "$ROOTFS_ENC_IMG" | cut -f1) / 1024 / 1024 + 1 ))
	HASH_SIZE_MIB=$(( $(du -b "$DMVERITY_ROOTFS_HASH_IMG" | cut -f1) / 1024 / 1024 + 1 ))

	# Add a small buffer (10MiB) for partition alignment/headers
	TOTAL_SIZE_MIB=$((ESP_SIZE_MIB + ROOT_SIZE_MIB + HASH_SIZE_MIB + 10))


	echo "[+] Creating an empty image file..."
	echo "Calculated Image Size: ${TOTAL_SIZE_MIB}MiB. ESP: $ESP_SIZE_MIB, rootfs: $ROOT_SIZE_MIB, dmverity_hash: $HASH_SIZE_MIB)"
	dd if=/dev/zero of="$OUTPUT_IMG" bs=1M count=0 seek=$TOTAL_SIZE_MIB 
}

create_gpt_image() {
	TOTAL_SIZE_MIB=0
	COUNT_TIMES=1
	if [ "$CREATE_DUAL_BOOT_AND_ROOTFS_PARTITIONS" = "true" ] ; then
		COUNT_TIMES=2
	fi
	if [ "$PUT_BOOT_MATERIALS_IN_ESP_FS" = "false" ] ; then
		ESP_SIZE_MIB=10 # ESP is not detected by OVMF with such a small value! Wouldn't work also with 32MB. And these things are not so trivial to think of!
		ESP_SIZE_MIB=64 
		BOOT_SIZE_MIB=$(( $(du -b "$BOOTFS_IMG" | cut -f1) / 1024 / 1024 + 1 ))
	else
		ESP_SIZE_MIB=200 # Could check the size of the disk and add some - but basically 200 is a lot, and gives >100MB for extra (test) images even if the "boot partition" is on the ESP itself (e.g. <ESP>/boot)
		BOOT_SIZE_MIB=0
	fi

	echo -e "\x1b[42mWelding  $ESP_FS_FOLDER $ROOTFS_ENC_IMG $DMVERITY_ROOTFS_HASH_IMG ---> \x1b[31m$OUTPUT_IMG\x1b[0m"

	# Sizes in MiB (M in dd means MiB, not MB)
	# Get size of your existing images in MiB (rounded up)
	ROOT_SIZE_MIB=$(( $(du -b "$ROOTFS_ENC_IMG" | cut -f1) / 1024 / 1024 + 1 ))
	HASH_SIZE_MIB=$(( $(du -b "$DMVERITY_ROOTFS_HASH_IMG" | cut -f1) / 1024 / 1024 + 1 ))

	# Add a small buffer (10MiB) for partition alignment/headers
	TOTAL_SIZE_MIB=$((ESP_SIZE_MIB + (BOOT_SIZE_MIB + ROOT_SIZE_MIB + HASH_SIZE_MIB) * COUNT_TIMES  + 10))


	echo "[+] Creating an empty image file..."
	echo "Calculated Image Size: ${TOTAL_SIZE_MIB}MiB. ESP: $ESP_SIZE_MIB, bootfs, $BOOT_SIZE_MIB, rootfs: $ROOT_SIZE_MIB, dmverity_hash: $HASH_SIZE_MIB). Redunant partitions: $COUNT_TIMES"
	dd if=/dev/zero of="$OUTPUT_IMG" bs=1M count=0 seek=$TOTAL_SIZE_MIB 
}

main() {
	make_boot_image_partition # This would be better done at the boot-materials script - however it will make it run slower, so I deliberately include it in the only place that cares about it - when we work with GPT and the disk
	#create_gpt_image_simple_a_only_partitions_boot_materials_in_esp
	create_gpt_image
	echo "[+] Creating GPT partition table..."
	parted -s "$OUTPUT_IMG" mklabel gpt

	# 1. EFI System Partition (Name: ESP)
	parted -s "$OUTPUT_IMG" mkpart ESP fat32 1MiB ${ESP_SIZE_MIB}MiB
	parted -s "$OUTPUT_IMG" set 1 esp on

	#set_a_only_partitions_boot_materials_in_esp

	set_a_b_partitions

	echo ""
	echo "These are your partitions and block ids:"
	sudo blkid ${LOOP_DEV}*
	echo ""

	echo "[+] Cleaning up..."
	teardown_loopdev
	echo -e "\x1b[32mDONE.\x1b[0m $OUTPUT_IMG created. You can refer to it from your favorite UEFI firmware, and enjoy."
}

main $@
