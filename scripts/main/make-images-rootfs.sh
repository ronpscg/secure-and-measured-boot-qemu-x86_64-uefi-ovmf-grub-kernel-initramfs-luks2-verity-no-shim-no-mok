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

: ${ROOTFS_SIZE_MIB=""}
: ${DONT_RECREATE_ROOTFS=false}
. $LOCAL_DIR/make-images-ext4-common.sh 
create_ext4_image_from_folder $ROOTFS_FS_FOLDER $ROOTFS_IMG rootfs $DONT_RECREATE_ROOTFS $ROOTFS_SIZE_MIB

if [ -z "$ROOTFS_SIZE_MIB" -o -n "$ROOTFS_SIZE_MIB" -a ! "$ROOTFS_SIZE_MIB" = "0" ] ; then
	# The next line is not needed as it makes us calculate the same thing 3 times
	# However the called scripts might expect it, so let's keep it like this
	ROOTFS_SIZE_MIB=$(( $(du -b "$ROOTFS_IMG" | cut -f1) / 1024 / 1024 + 1 ))
	echo "Using $ROOTFS_IMG. Size: $ROOTFS_SIZE_MIB MiB"
fi

export ROOTFS_IMG
export LUKS_MAPPER_NAME ROOTFS_ENC_IMG
export ROOTFS_DECRYPTED_IMG

export DMVERITY_ROOTFS_HASH_IMG DMVERITY_HEADER_TEXT_FILE
export SOURCE_SIZE_MIB=$ROOTFS_SIZE_MIB

export LUKS_AND_DMVERITY_EXPORTED_ENV_FILE
./6-luks-and-dmverity-image.sh


echo "Please update the GRUB config with the relevant UUIDs and values, and rerun make-images-boot-materials.sh"

