#!/bin/bash
set -euo pipefail

setup() (
	cd $REQUIRED_PROJECTS_DIR
	if [[ "$KV" = *"rc"* ]] ; then
		suffix=.tar.gz
		wget https://git.kernel.org/torvalds/t/linux-$KV.tar.gz 
	else
		suffix=.tar.xz # assuming the kernel is not very outdated
		series="v$(echo $KV | cut -b1).x"
		wget https://cdn.kernel.org/pub/linux/kernel/$series/linux-$KV.tar.xz
	fi
	tar xf linux-${KV}${suffix}
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
