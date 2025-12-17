#!/bin/bash
set -euo pipefail
LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
. $LOCAL_DIR/../common.sh || { echo "Please run the script from the right place" ; exit 1 ; }
cd $LOCAL_DIR

: ${BOOTFS_IMG=$ARTIFACTS_DIR/bootfs.img}
: ${DONT_RECREATE_BOOTFS=false}
: ${BOOTFS_IMG_SIZE=""}


main() {
	. $LOCAL_DIR/make-images-ext4-common.sh 
	create_ext4_image_from_folder $BOOT_FS_FOLDER $BOOTFS_IMG datafs $DONT_RECREATE_BOOTFS $BOOTFS_IMG_SIZE
}
main $@
