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


# This uses grub-mkimage, which does not encapsulate the $GRUB_CONFIG in it.
# This is what you would want to do, for example, if you use Yocto Project and don't want to tinker around the recipes and add your own build step
build_nonstandalone_image() (
	cd $GRUB_BUILDER_DIR
	# Create the memdisk filesystem. You get it for granted in the standalone version
	# Don't use mktemp, and leave the tarball for debugging if someone wants. This is not the best practice but if you run into issues with it
	# it is definitely "your fault" and you know what you are doing
	rm -rf /tmp/grub-memdisk-workdir/
	mkdir -p /tmp/grub-memdisk-workdir/boot/grub/
	cp $GRUB_CONFIG /tmp/grub-memdisk-workdir/boot/grub/grub.cfg
	( cd /tmp/grub-memdisk-workdir && tar cf /tmp/grub-memdisk.tar . && tar tf /tmp/grub-memdisk.tar )

	# grub-mkimage requires specifying modules explicitly
	# minicmd has help, lsmod etc. One could include help, but there is no module for lsmod
	: ${GRUB_MODULES="
		part_gpt part_msdos ext2 linux normal boot memdisk configfile search fat ls cat echo test gcry_dsa gcry_rsa gcry_sha256 pubkey pgp \
		tar minicmd efifwsetup
		tpm \
	"}
	./grub-mkimage -O x86_64-efi -o grubx64.efi --directory=./grub-core \
		--disable-shim-lock \
		--pubkey=$GRUB_PGP_PUBLIC_KEY \
		-m /tmp/grub-memdisk.tar \
		$GRUB_MODULES
)

build_standalone_image() (
	cd $GRUB_BUILDER_DIR
	./grub-mkstandalone -O x86_64-efi -o grubx64.efi --directory=./grub-core  \
		--modules="part_gpt part_msdos ext2 linux normal boot configfile search ls cat echo test gcry_dsa gcry_rsa gcry_sha256 pubkey pgp " \
		--fonts="" --locales="" --themes=""  \
		--disable-shim-lock \
		--pubkey $GRUB_PGP_PUBLIC_KEY \
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
