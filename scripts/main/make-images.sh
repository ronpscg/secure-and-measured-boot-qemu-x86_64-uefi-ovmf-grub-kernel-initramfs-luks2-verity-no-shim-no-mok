#!/bin/bash
LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
cd $LOCAL_DIR

usage() {
	echo "$0:"
	echo "all: makes all images, fine if you need to build all, slower otherwise"
	echo "all-no-disk: doesn't make the combined GPT image"
	echo "boot: fast, updates the boot materials"
	echo "rootfs: updates the rootfs images, including verity and encrption"
	echo "gpt: repackages the disk image, and only it"
}

case $1 in
	all)
		./make-images-rootfs.sh
		./make-images-boot-materials.sh
		./make-combined-gpt-disk-image.sh
		;;
	boot)
		./make-images-boot-materials.sh
		;;
	rootfs)
		./make-images-rootfs.sh
		;;
	gpt)
		./make-combined-gpt-disk-image.sh
		;;
	all-no-disk)
		./make-images-rootfs.sh
		./make-images-boot-materials.sh
		;;
	*)
		usage
		exit 1
esac

