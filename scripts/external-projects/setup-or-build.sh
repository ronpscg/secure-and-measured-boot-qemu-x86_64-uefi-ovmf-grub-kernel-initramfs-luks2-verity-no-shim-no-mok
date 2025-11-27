#!/bin/bash
LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
. $LOCAL_DIR/../common.sh || { echo "Please run the script from the right place" ; exit 1 ; }
cd $LOCAL_DIR

# Run setup to just get the code and then use it offline (with the exception of the ramdisk builder which builds fast and there is no point to hold back on it)
# TODO: if I add a rootfs generator here (better use in PscgBuildOS, but perhaps I'll add a debootstrap step or something) - it will also be in the setup step, as no configurations
#       are required really for the demonstration of this project
setup() {
	./build-edk2-ovmf.sh setup
	./build-grub.sh setup
	./build-kernel.sh setup
	./build-initramfs.sh setup
	./build-rootfs.sh	# Already copies the artifacts - this does  setup + build + copy_artifacts together
}

build() {
	./build-edk2-ovmf.sh build
	./build-grub.sh build # alternatively, you can split the steps. If you know for sure you just want to update a config file and grub-core is built
	                      # Then, you could just run    ./build-grub.sh build_standalone_image  
	./build-kernel.sh build
	# ./build-initramfs build # basically already done by setup for now. maybe I'll add specific builds
}

copy_artifacts() {
	./build-edk2-ovmf.sh copy_artifacts
	./build-grub.sh copy_artifacts
	./build-kernel.sh copy_artifacts
	./build-initramfs.sh copy_artifacts
}

usage() {
	echo "usage: $0 <setup|build|copy_artifacts|all>"
	echo "usage: $0 [edk2|OVMF|grub|kernel|initramfs|ramdisk|initrd|rootfs	<setup|build|copy_artifacts|all>"
	echo "Please see script for details. e.g. rootfs is only relevant for setup. initramfs is not relevant for build. There might be changes from this usage"
}

all_projects() {
	case $1 in
		setup|build|copy_artifacts)
			$1
			;;
		all)
			echo "[+] Setting up the external projects..."
			setup
			echo "[+] Building the external projects..."
			build
			echo "[+] Copying artifacts..."
			copy_artifacts
			;;

		*) 
			usage
			exit 1
			;;
	esac
}

one_project() {
	local project
	case $1 in
		edk2|OVMF|ovmf|edk2-ovmf)
			project=edk2-ovmf
			;;
		grub|grub2|GRUB|GRUB2)
			project=grub
			;;
		kernel)
			project=kernel
			;;
		initramfs|ramdisk|initrd)
			project=initramfs
			;;
		rootfs)
			project=rootfs
			;;
		*)
			usage
			exit 1
			;;
	esac

	shift

	echo "[+] Running build-${project}.sh with $@"
	eval ./build-${project}.sh $@
}

main() {
	if [ "$#" -le "1" ] ; then
		all_projects $@
	else 
		one_project $@
	fi
}

main $@
