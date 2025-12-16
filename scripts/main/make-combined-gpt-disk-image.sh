#!/bin/bash
set -euo pipefail
LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
. $LOCAL_DIR/../common.sh || { echo "Please run the script from the right place" ; exit 1 ; }

# These can be common as they are defined in several scripts, but they are consistent, and there are still not too many partitions.
# It makes it easier for the learner to look at each file separately without jumping back and forth, and also clearly specifies the requirements/dependencies in the same file
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

main() {
	echo -e "\x1b[42mWelding  $ESP_FS_FOLDER $ROOTFS_ENC_IMG $DMVERITY_ROOTFS_HASH_IMG ---> \x1b[31m$OUTPUT_IMG\x1b[0m"

	# Sizes in MiB (M in dd means MiB, not MB)
	ESP_SIZE_MIB=200 # Could check the size of the disk and add some - but basically 200 is a lot, and gives >100MB for extra (test) images even if the "boot partition" is on the ESP itself (e.g. <ESP>/boot)
	# Get size of your existing images in MiB (rounded up)
	ROOT_SIZE_MIB=$(( $(du -b "$ROOTFS_ENC_IMG" | cut -f1) / 1024 / 1024 + 1 ))
	HASH_SIZE_MIB=$(( $(du -b "$DMVERITY_ROOTFS_HASH_IMG" | cut -f1) / 1024 / 1024 + 1 ))

	# Add a small buffer (10MiB) for partition alignment/headers
	TOTAL_SIZE_MIB=$((ESP_SIZE_MIB + ROOT_SIZE_MIB + HASH_SIZE_MIB + 10))


	echo "[+] Creating an empty image file..."
	echo "Calculated Image Size: ${TOTAL_SIZE_MIB}MiB. ESP: $ESP_SIZE_MIB, rootfs: $ROOT_SIZE_MIB, dmverity_hash: $HASH_SIZE_MIB)"
	dd if=/dev/zero of="$OUTPUT_IMG" bs=1M count=0 seek=$TOTAL_SIZE_MIB 

	echo "[+] Creating GPT partition table..."
	parted -s "$OUTPUT_IMG" mklabel gpt

	# 1. EFI System Partition (Name: ESP)
	parted -s "$OUTPUT_IMG" mkpart ESP fat32 1MiB ${ESP_SIZE_MIB}MiB
	parted -s "$OUTPUT_IMG" set 1 esp on

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
	P1="${LOOP_DEV}p1"
	P2="${LOOP_DEV}p2"
	P3="${LOOP_DEV}p3"

	echo "[-] Populating Partition 1 (ESP, or \"EFI Boot\")..."
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

	echo ""
	echo "These are your partitions and block ids:"
	sudo blkid ${LOOP_DEV}*
	echo ""

	echo "[+] Cleaning up..."
	teardown_loopdev
	echo -e "\x1b[32mDONE.\x1b[0m $OUTPUT_IMG created. You can refer to it from your favorite UEFI firmware, and enjoy."
}

main $@
