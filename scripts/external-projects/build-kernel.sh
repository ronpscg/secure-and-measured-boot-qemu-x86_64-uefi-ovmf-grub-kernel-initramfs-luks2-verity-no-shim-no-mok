#!/bin/bash
set -euo pipefail

setup() (
	cd $REQUIRED_PROJECTS_DIR
	wget https://git.kernel.org/torvalds/t/linux-$KV.tar.gz  # note: the suffix will change if it's an rc... but it will fail and it will be easy for you to go to kernel.org and figure it out in a jiffie
	tar xf linux-$KV.tar.gz
)

build() (
	cp $KERNEL_CONFIG $KERNEL_BUILDER_DIR/.config
	cd $KERNEL_BUILDER_DIR
	make -j$(nproc)
	echo "Build done. Please copy your artifacts from $KERNEL_BUILDER_DIR/arch/x86/boot/bzImage"
)

copy_artifacts() {
	:
}


$1
