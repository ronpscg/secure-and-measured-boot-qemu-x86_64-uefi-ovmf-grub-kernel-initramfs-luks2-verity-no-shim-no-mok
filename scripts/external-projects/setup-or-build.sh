#!/bin/bash

. ./common.sh || { echo "Please run the script from the right place" ; exit 1 ; }

# Run setup to just get the code and then use it offline (with the exception of the ramdisk builder which builds fast and there is no point to hold back on it)
# TODO: if I add a rootfs generator here (better use in PscgBuildOS, but perhaps I'll add a debootstrap step or something) - it will also be in the setup step, as no configurations
#       are required really for the demonstration of this project
setup() {
	./build-kernel.sh setup
	./build-edk2-ovmf.sh setup
}

build() {
	./build-kernel.sh build
	./build-edk2-ovmf.sh build
}

copy_artifacts() {
	./build-kernel.sh copy_artifacts
	./build-edk2-ovmf.sh copy_artifacts
}


case $1 in
	setup|build|copy_artifacts)
		$1
		;;
	*) 
		echo "usage: $0 <setup|build>"
		;;
esac
