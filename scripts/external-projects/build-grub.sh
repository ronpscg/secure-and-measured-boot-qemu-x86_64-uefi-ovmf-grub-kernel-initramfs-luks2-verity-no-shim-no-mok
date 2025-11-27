#!/bin/bash
set -euo pipefail

setup() (
	# GRUB2 is ~107M after syncing (as per Nov 25 2025) and is cloned quite fast
	cd $REQUIRED_PROJECTS_DIR
	git clone https://git.savannah.gnu.org/git/grub.git
	cd $GRUB_BUILDER_DIR
	echo "Uwaga - Grub update in November broke the ./bootstrap script. Checking out the commit I last worked with that worked (for 2.14-rc1)"
	git checkout 2bc0929a2fffbb60995605db6ce46aa3f979a7d2 
	./bootstrap
)

build_grub_core() (
	cd $GRUB_BUILDER_DIR
	# takes a while but less than a minute
	./configure --with-platform=efi --target=x86_64
	# faster than the configure step
	make -j$(nproc)
	echo "Done building GRUB core"
)

build_standalone_image() (
	cd $GRUB_BUILDER_DIR
	./grub-mkstandalone -O x86_64-efi -o grubx64.efi --directory=./grub-core  \
		--modules="part_gpt part_msdos ext2 linux normal boot configfile search ls cat echo test" \
			--fonts="" --locales="" --themes=""  \
		"boot/grub/grub.cfg=$GRUB_CONFIG"
)

build() (
	build_grub_core
	build_standalone_image # requires the configuration file
	echo "Build done. Please copy your artifacts from $GRUB_BUILDER_DIR/grubx64.efi"
	echo "If you want GRUB to be the default EFI boot app make sure you put in under the EFI System Partition's (ESP's) EFI/BOOT/BOOTX64.EFI file"
)

copy_artifacts() {
	cp $GRUB_BUILDER_DIR/grubx64.efi $REQUIRED_PROJECTS_ARTIFACTS_DIR
}


$1
