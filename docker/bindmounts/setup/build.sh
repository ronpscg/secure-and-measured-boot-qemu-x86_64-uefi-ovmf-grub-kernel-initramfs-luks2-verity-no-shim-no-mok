#!/bin/bash

: ${CLONE_REPOS=false}
: ${SETUP_KEYS=false}
: ${BUILD_PROJECTS=false}
: ${PACKAGE_IMAGES=false}  # might make it default to true though
: ${BUILD_YOCTO=false} # would not be a part of this script anyway probably
: ${RUN_QEMU=false}

: ${BUILDER_SRC_DIR=$HOME/secboot-ovmf-x86_64}
: ${SCRIPTS_DIR=$BUILDER_SRC_DIR/scripts}
: ${COMMON_CONFIG_FILE=$BUILDER_SRC_DIR/local.config}
export COMMON_CONFIG_FILE

clone_repos() {
	git clone https://github.com/ronpscg/secure-and-measured-boot-qemu-x86_64-uefi-ovmf-grub-kernel-initramfs-luks2-verity-no-shim-no-mok.git -b docker ~/secboot-ovmf-x86_64
	# There is no real need in this repo - but it can be easier to test like this externally build folders that follow our Yocto Project image conventions, so it is cloned as well
	git clone https://github.com/ronpscg/example-test-secboot-qemu.git ~/example-test-secboot
}

setup_keys() {
	# Expected to be called separately, here for the sake of completion
	./prepare-keys.sh
}

build_external_projects() {
	echo "Building external projects"
	cd $BUILDER_SRC_DIR
	scripts/external-projects/setup-or-build.sh all
}

package_images() {
	echo "Packaging images"
	$SCRIPTS_DIR/main/make-images.sh all
}

build_yocto() {
	$SCRIPTS_DIR/yocto/build-yocto.sh
}

run_qemu_on_default_build() {
	echo "Running QEMU without graphics to not exahust your docker setup/storage with graphic packages"
	$SCRIPTS_DIR/qemu/test-tmp.sh disk -nographic
}


usage() {
	echo -e "$0 [-c|-k|-b|-p]\n  -c: clone repos\n  -k setup keys\n  -b: build external projects\n  -p: package images\n  q: run QEMU"
	exit $1
}

main() {
	while getopts "kcbhpqy" opt ; do
		case $opt in
			k)
				SETUP_KEYS=true
				echo "Requested to setup keys"
				;;
			c)
				CLONE_REPOS=true
				echo "Will clone repos"
				;;
			b)
				BUILD_PROJECTS=true
				;;
			p)
				PACKAGE_IMAGES=true
				;;
			q)
				RUN_QEMU=true
				;;
			y)
				BUILD_YOCTO=true;
				;;
			h)
				usage 0
				;;
			\?)
				echo "Invalid option: -$OPTARG" >&2
				exit 1
				;;
			:)
				echo "Option -$OPTARG requires an argument." >&2
				usage 1
				;;
		esac
	done

	if [ "$OPTIND" -eq 1 ]; then
		echo "Error: No options provided." >&2
		usage
		exit 1
	fi

	# Shift processed options so positional arguments start at $1
	shift "$((OPTIND-1))"

	# Check for remaining positional arguments (e.g., input files)
	if [ -n "$1" ]; then
		echo "Positional argument (e.g., input) is: $1"
	fi
	
	set -euo pipefail
	LOCAL_DIR=$(readlink -f $(dirname ${BASH_SOURCE[0]}}))
	cd $LOCAL_DIR

	if  [ "$CLONE_REPOS" = "true" ] ; then
		clone_repos
	fi
	# setup_keys # please run it externally, after you clone the repos

	if [ "$SETUP_KEYS" = "true" ] ; then
		setup_keys
	fi

	if [ "$BUILD_PROJECTS" = "true" ] ; then
		build_external_projects
	fi

	if [ "$PACKAGE_IMAGES" = "true" ] ; then
		package_images
	fi
	
	if [ "$BUILD_YOCTO" = "true" ] ; then
		build_yocto
	fi

	if [ "$RUN_QEMU" = "true" ] ; then
		run_qemu_on_default_build # i.e. not on the Yocto one, for that there are the other scripts
	fi

}


main $@
