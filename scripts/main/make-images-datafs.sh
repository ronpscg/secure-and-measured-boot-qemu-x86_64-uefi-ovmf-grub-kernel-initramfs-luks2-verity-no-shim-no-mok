#!/bin/bash
set -euo pipefail
LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
. $LOCAL_DIR/../common.sh || { echo "Please run the script from the right place" ; exit 1 ; }
cd $LOCAL_DIR

#
# Pretty much the same logic, however, here we account for a possibly empty partition that needs to be preallocated,
# most of the logic (all of it, if recreating an image and copying over to it) can be refactored to a common code. PscgBuildOS does it nicer
# I refactor the common code in this file only for now - and this should be ported to the rootfs/bootfs image creation files (problem there is different variables
#
: ${DATA_FS_FOLDER=$ARTIFACTS_DIR/data.fs.folder}
: ${DONT_RECREATE_DATAFS=false}
: ${DATAFS_IMG=$ARTIFACTS_DIR/datafs.img}
: ${DATAFS_IMG_SIZE=""}                         # One would specify the desired target size here as it is likely to be created empty
: ${DATAFS_DEFAULT_MKFS_PARAMS=""}              #
: ${DATAFS_PREPOPULATE_SOURCE_DIR=""}           # one could specify it, and then the DATA_FS_FOLDER will have contents upon creation


main() {
	. $LOCAL_DIR/make-images-ext4-common.sh 
	create_ext4_image_from_folder $DATA_FS_FOLDER $DATAFS_IMG datafs $DONT_RECREATE_DATAFS $DATAFS_IMG_SIZE
}
main $@
