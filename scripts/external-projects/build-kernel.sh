#!/bin/bash
set -euo pipefail

setup() (
	cd $REQUIRED_PROJECTS_DIR
	if [[ "$KV" = *"rc"* ]] ; then
		suffix=.tar.gz
		url=https://git.kernel.org/torvalds/t/linux-$KV.tar.gz 
	else
		suffix=.tar.xz # assuming the kernel is not very outdated
		series="v$(echo $KV | cut -b1).x"
		url=https://cdn.kernel.org/pub/linux/kernel/$series/linux-$KV.tar.xz
	fi

	# Don't bother to download or untar if you think we have already done so
	if [ ! -e linux-${KV}${suffix} ] ; then
		wget $url
	fi
	if [ ! -e linux-${KV} ] ; then
		tar xf linux-${KV}${suffix}
	fi
)

build() (
	cp $KERNEL_CONFIG $KERNEL_BUILDER_DIR/.config
	cd $KERNEL_BUILDER_DIR
	make -j$(nproc)
	echo "Build done. Please copy your artifacts from $KERNEL_BUILDER_DIR/arch/x86/boot/bzImage"
)

copy_artifacts() {
	cp $KERNEL_BUILDER_DIR/arch/x86/boot/bzImage $REQUIRED_PROJECTS_ARTIFACTS_DIR
}


$1
