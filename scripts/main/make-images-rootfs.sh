#!/bin/bash
set -euo pipefail
LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
. $LOCAL_DIR/../common.sh || { echo "Please run the script from the right place" ; exit 1 ; }
cd $LOCAL_DIR

: ${ROOTFS_IMG=$ARTIFACTS_DIR/rootfs.img}
: ${ROOTFS_ENC_IMG="$ARTIFACTS_DIR/rootfs.enc.img"}
: ${LUKS_MAPPER_NAME="dmcryptdevice-luks"}
: ${ROOTFS_DECRYPTED_IMG="${ROOTFS_IMG}"}  # See notes if you want to set it to "/dev/mapper/${LUKS_MAPPER_NAME}
: ${DMVERITY_ROOTFS_HASH_IMG=$ARTIFACTS_DIR/dmverity-hash.img}
: ${DMVERITY_HEADER_TEXT_FILE=$ARTIFACTS_DIR/dmverity-header.txt}
: ${LUKS_AND_DMVERITY_EXPORTED_ENV_FILE=$ARTIFACTS_DIR/luks-and-dmverity-kernel-cmdline-values.env} # aimed to be sourced when updating the bootloader materials

# If the verity hash is created separately from the LUKS image (i.e. directly from the cleantext rootfs)
# one must NOT resize or fsck the hash. We give both options there, and it makes for a great exercise as well.
if [ ! "$ROOTFS_DECRYPTED_IMG" = "/dev/mapper/${LUKS_MAPPER_NAME}" ] ; then
	export LUKS_DONT_RESIZE_TARGET_FS=true
	export LUKS_DONT_FSCK_TARGET_FS=true
fi

echo "[+] Creating the rootfs image"
if [ -f $ROOTFS_IMG ] ; then
	echo "WARNING: rootfs.img existed. Would you like to remove it? [y/n/^C]"
	read
	case $REPLY in
		y|Y)
			rm $ROOTFS_IMG
			;;
		""|n)
			# maybe make the default remove it instead
			echo "Keeping the current rootfs image"
			;;
		*)
			exit 1
			;;
	esac	
fi

ROOTFS_SIZE_MIB=$(echo "$(( ($(sudo du -sb $ROOTFS_FS_FOLDER  | cut  -f 1) ) )) * 1.4 / 1024/1024 + 1" | bc) # size of the current folder +40% for metadata and some extra working space
ROOTFS_MOUNT=$ARTIFACTS_DIR/rootfs.mount
fallocate -l ${ROOTFS_SIZE_MIB}MiB $ROOTFS_IMG
# would be better to check for existence, in previous scripts etc., but if something doesn't check out it's easy to trace to that, and unmount/losetup -d etc. manually and I simply don't have the time for that now
mkdir $ROOTFS_MOUNT
LOOPDEV=$(losetup -f)
sudo losetup -Pf $ROOTFS_IMG
sudo mkfs.ext4 $LOOPDEV
sudo mount $LOOPDEV $ROOTFS_MOUNT
sudo cp -a $ROOTFS_FS_FOLDER/* $ROOTFS_MOUNT
# maybe also copy ./... but in our debootstrap for now there won't be any under the root filesystem so it's simpler to follow

sudo umount $ROOTFS_MOUNT
sudo e2fsck -f $LOOPDEV
sudo resize2fs $LOOPDEV
sudo losetup -d $LOOPDEV
rmdir $ROOTFS_MOUNT
sync

echo "OK"

export LUKS_MAPPER_NAME ROOTFS_ENC_IMG
export ROOTFS_DECRYPTED_IMG

export DMVERITY_ROOTFS_HASH_IMG DMVERITY_HEADER_TEXT_FILE
export SOURCE_SIZE_MIB=$ROOTFS_SIZE_MIB

export LUKS_AND_DMVERITY_EXPORTED_ENV_FILE
./6-luks-and-dmverity-image.sh


echo "Please update the GRUB config with the relevant UUIDs and values, and rerun make-images-boot-materials.sh"

