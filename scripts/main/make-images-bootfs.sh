#!/bin/bash
set -euo pipefail
LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
. $LOCAL_DIR/../common.sh || { echo "Please run the script from the right place" ; exit 1 ; }
cd $LOCAL_DIR

: ${BOOTFS_IMG=$ARTIFACTS_DIR/bootfs.img}

: ${DONT_RECREATE_BOOTFS=false}
if [ ! "$DONT_RECREATE_BOOTFS" = "true" ] ; then
	echo "[+] Creating the bootfs image (where the Linux boot materials will reside)"
	if [ -f $BOOTFS_IMG ] ; then
		echo "WARNING: bootfs.img existed. Would you like to remove it? [y/n/^C]"
		read
		case $REPLY in
			y|Y)
				rm $BOOTFS_IMG
				;;
			""|n)
				echo "Keeping the current bootfs image - be sure you know what you are doing"
				;;
			*)
				exit 1
				;;
		esac	
	fi



	BOOTFS_SIZE_MIB=$(echo "$(( ($(sudo du -sb $BOOT_FS_FOLDER  | cut  -f 1) ) )) * 1.4 / 1024/1024 + 1" | bc) # size of the current folder +40% for metadata and some extra working space
	BOOTFS_MOUNT=$ARTIFACTS_DIR/bootfs.mount
	fallocate -l ${BOOTFS_SIZE_MIB}MiB $BOOTFS_IMG
	# would be better to check for existence, in previous scripts etc., but if something doesn't check out it's easy to trace to that, and unmount/losetup -d etc. manually and I simply don't have the time for that now
	mkdir $BOOTFS_MOUNT
	LOOPDEV=$(losetup -f)
	sudo losetup -Pf $BOOTFS_IMG
	sudo mkfs.ext4 $LOOPDEV
	sudo mount $LOOPDEV $BOOTFS_MOUNT
	sudo cp -a $BOOT_FS_FOLDER/* $BOOTFS_MOUNT
	# maybe also copy ./... but in our debootstrap for now there won't be any under the root filesystem so it's simpler to follow

	sudo umount $BOOTFS_MOUNT
	sudo e2fsck -f $LOOPDEV
	sudo resize2fs $LOOPDEV
	sudo losetup -d $LOOPDEV
	rmdir $BOOTFS_MOUNT
	sync

	echo "OK"
else
	BOOTFS_SIZE_MIB=$(echo "$(( ($(sudo du -sb $BOOTFS_IMG  | cut  -f 1) ) )) * 1.4 / 1024/1024 + 1" | bc)
	echo "Using $BOOTFS_IMG. Size: $BOOTFS_SIZE_MIB MiB"
fi
