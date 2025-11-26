#!/bin/bash
set -euo pipefail
LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
. $LOCAL_DIR/../common.sh || { echo "Please run the script from the right place" ; exit 1 ; }


echo "[+] Creating the rootfs image"
ROOTFS_SIZE_MIB=$(echo "$(( ($(sudo du -sb $ROOTFS_FS_FOLDER  | cut  -f 1) ) )) * 1.4 / 1024/1024 + 1" | bc) # size of the current folder +40% for metadata and some extra working space
ROOTFS_IMG=$ARTIFACTS_DIR/rootfs.img
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

echo "Please update the GRUB config with the relevant UUIDs and values, and rerun make-images.sh"

