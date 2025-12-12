#!/bin/bash

: ${CLONE_REPOS=false}
: ${SETUP_KEYS=false}
: ${BUILD_PROJECTS=false}
: ${PACKAGE_IMAGES=false}  # might make it default to true though
: ${BUILD_YOCTO=false} # would not be a part of this script anyway probably
: ${RUN_QEMU=false}
: ${ENROLL_AND_RUN_YOCTO_ARTIFACTS=false}

: ${BUILDER_SRC_DIR=$HOME/secboot-ovmf-x86_64}
: ${SCRIPTS_DIR=$BUILDER_SRC_DIR/scripts}
: ${COMMON_CONFIG_FILE=$BUILDER_SRC_DIR/local.config}
export COMMON_CONFIG_FILE

: ${EXAMPLE_TEST_SCRIPTS_DIR=$HOME/example-test-secboot/} # TODO probably consolidate with scripts dir later

: ${KAS_DIR=~/yocto/kasdir}

: ${COMMIT_SECBOOT_OVMF_X86_64=docker}
: ${COMMIT_EXAMPLE_TEST_SECBOOT=master}
: ${COMMIT_KAS_YOCTO_SECBOOT=master}
: ${COMMIT_POKY=scarthgap} # not used anywhere yet, as it's all scarthgap in the kas files at the moment but wouldn't hurt to prepare for other releases

clone_repos() {
	set +e	# Allow to fail in case the folder exists
	git clone https://github.com/ronpscg/secure-and-measured-boot-qemu-x86_64-uefi-ovmf-grub-kernel-initramfs-luks2-verity-no-shim-no-mok.git -b $COMMIT_SECBOOT_OVMF_X86_64 ~/secboot-ovmf-x86_64
	git clone https://github.com/ronpscg/kas-yocto-secure-and-measuerd-boot-examples.git -b $COMMIT_KAS_YOCTO_SECBOOT ${KAS_DIR}
	# There is no real need in this repo - but it can be easier to test like this externally build folders that follow our Yocto Project image conventions, so it is cloned as well
	git clone https://github.com/ronpscg/example-test-secboot-qemu.git -b $COMMIT_EXAMPLE_TEST_SECBOOT ${EXAMPLE_TEST_SCRIPTS_DIR}
	set -e

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

run_qemu_on_yocto_build() {
	# Read carefully and make sure you want things overridden. If your MACHINE and YOCTO_BUILD_DIR are set correctly, you probably do.
	: ${GENERATE_TEST_LOCAL_CONFIG=true}
	: ${ENROLL_CRYPTO_MATERIALS_IN_UEFI_VARSTORE=true}
	: ${MACHINE=intel-corei7-64}
        : ${YOCTO_BUILD_DIR=~/yocto/kasdir/build}
	: ${FIRMWARE_ENROLLED_KEYS_DIR=~/pscg/secureboot-qemu-x86_64-efi-grub/artifacts/ESP.fs.folder/keys/}

	cd $EXAMPLE_TEST_SCRIPTS_DIR ||  { echo "Test dir $EXAMPLE_TEST_SCRIPTS_DIR is not cloned" ; exit 1 ; }

	if [ "$GENERATE_TEST_LOCAL_CONFIG" = "true" ] ; then
		echo "Generating default materials. You may want to change it with your own materials!"
		echo -e "set -a
		: \${MACHINE=$MACHINE}
		: \${YOCTO_BUILD_DIR=$YOCTO_BUILD_DIR}
		: \${IMAGE_BASENAME=core-image-minimal}
		: \${FIRMWARE_ENROLLED_KEYS_DIR=$FIRMWARE_ENROLLED_KEYS_DIR}
		set +a
		" > local.config
		sed -i 's/^[[:blank:]]*//' local.config
	fi

	if [ "$ENROLL_CRYPTO_MATERIALS_IN_UEFI_VARSTORE" = "true" ] ; then
		echo "Enrolling your cryptographic materials and running QEMU without graphics to not exhaust your docker setup/storage with graphic pacakges"
		./enroll-ovmf-vars.sh OVMF-local/OVMF_VARS.fd  OVMF-local/OVMF_VARS.fd
	fi

	echo "Running QEMU." 
	if [ -f /.dockerenv ] ; then 
		echo -e "\eIf you are in docker - make sure your last console in your kernel cmdline is \e[33mconsole=ttyS0\e[0m as we will run it in a -nographic mode"
	fi
	./test.sh
}


usage() {
	echo -e "$0 [-c|-k|-b|-p|-q|-y|-r]\n  -c: clone repos\n  -k setup keys\n  -b: build external projects\n  -p: package images\n  -q: run QEMU\n  -y: Build and Package Yocto Project\n  -r: enroll certificates and run Yocto Project artifacts prepared with $0 -y"
	exit $1
}

main() {
	while getopts "kcbhpqyr" opt ; do
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
			r)
				ENROLL_AND_RUN_YOCTO_ARTIFACTS=true;
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

	if [ "$ENROLL_AND_RUN_YOCTO_ARTIFACTS" = "true" ] ; then
		run_qemu_on_yocto_build
	fi


}


main $@
