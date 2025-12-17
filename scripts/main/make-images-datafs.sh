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


#
# $1: src folder
# $2: dst image file name
# $3: name # for now just used to create a mountpoint, can be decided if we want to give it to some LABEL etc. PscgBuildOS does it nicer
# $4: true to not recreate the file (and then do nothing) false otherwise
# $5: size of target FS. If 0 - size will be decided accorduing to the src folder
create_ext4_image_from_folder() {
	local src=$1
	local dst=$2
	local mountname=$3 # can be changed
	local dontrecreate=$4
	local size=${5-0}

	# keeping names in capital letters to be as identical as possible to the other scripts that do the exact same logic for diff purposes
	local SIZE_MIB
	local MOUNTPOINT

	if [ ! "$dontrecreate" = "true" ] ; then
		echo "[+] Creating the $(basename $dst) image"
		if [ -f $dst ] ; then
			echo "WARNING: $(basename $dst) existed. Would you like to remove it? [y/n/^C]"
			read
			case $REPLY in
				y|Y)
					rm $dst
					;;
				""|n)
					echo "Keeping the current $(basename $dst) image - be sure you know what you are doing"
					;;
				*)
					exit 1
					;;
			esac	
		fi

		if [ ! -d "$src" ] ; then
			echo "[+] Creating $src for the first time, and assuming you are looking to create an empty file system of size $size"
			mkdir -p $src
		fi

		if [ "$size" = "0" ] ; then
			# If the source directory is empty, by default, on ext4 you will get:
			# size  used avail    of
			# 976K   24K  884K
			# From which 16K will be lost+found
			# This of course can change between systems if you have other default tunables for mkfs.ext4
			SIZE_MIB=$(echo "$(( ($(sudo du -sb $src  | cut  -f 1) ) )) * 1.4 / 1024/1024 + 1" | bc) # size of the current folder +40% for metadata and some extra working space
		else
			SIZE_MIB=$size
		fi

		MOUNTPOINT=$ARTIFACTS_DIR/$mountname.mount
		fallocate -l ${SIZE_MIB}MiB $dst
		# would be better to check for existence, in previous scripts etc., but if something doesn't check out it's easy to trace to that, and unmount/losetup -d etc. manually and I simply don't have the time for that now
		mkdir $MOUNTPOINT
		LOOPDEV=$(losetup -f)
		sudo losetup -Pf $dst
		sudo mkfs.ext4 $LOOPDEV
		sudo mount $LOOPDEV $MOUNTPOINT
		sudo cp -aT $src $MOUNTPOINT  #  could rsync instead but systems do not come with rsync by default

		sudo umount $MOUNTPOINT
		sudo e2fsck -f $LOOPDEV
		sudo resize2fs $LOOPDEV
		sudo losetup -d $LOOPDEV
		rmdir $MOUNTPOINT
		sync

		echo "OK"
	else
		SIZE_MIB=$(echo "$(( ($(sudo du -sb $dst  | cut  -f 1) ) )) * 1.4 / 1024/1024 + 1" | bc)
		echo "Using $dst. Size: $SIZE_MIB MiB"
	fi
}


main() {
	create_ext4_image_from_folder $DATA_FS_FOLDER $DATAFS_IMG datafs $DONT_RECREATE_DATAFS $DATAFS_IMG_SIZE
}
main $@
