#!/bin/bash
set -euo pipefail

setup() (
	sudo apt-get install -y nasm iasl # Quite unnecessary usually, but quite necessary for EDK2

	# EDK2 is ~483M after syncing (as per Nov 25 2025) and before submodule updating and might take a while to sync
	git clone https://github.com/tianocore/edk2 $EDK2_BUILDER_DIR
	cd $EDK2_BUILDER_DIR

	# Submodule updating might take a while too. After that, EDK2 is ~1.5G
	# Since the demonstration and testing were on the master branch, I clone everything, in case something is messed up at some point
	git submodule update --init

	# Check out a well working version as the master branch at the time of writing it had a bug in the firmware setup menu (it did not allow to go into submenus)
	git checkout edk2-stable202511

	set +u  # edksetup.sh has undefined variables so don't let it fail on that
	. edksetup.sh BaseTools
	set -u
	# The building of the BaseTools is relatively fast and doesn't weigh much, so we can do it in the setup phase, to also check that some of our host build dependencies are in tact
	make -C BaseTools -j$(nproc)
)

patch() {

	#
	# NOTE: by default - if you build with secure boot - the Shell.efi will not be included in the firmware code!
	#                    it is possible to modify it in the OvmfPkg/OvmfPkgX64.fdf file , e.g. add something like 
	#                    INF  ShellPkg/Application/Shell/Shell.inf
        #                    in the [FV.DXEFV] section.
	#
	#      You could also add it to your EFI partition on your disk
	#      The build, the way it is, is fine, and does not require modifying any file, so it's better this way, but if you are learning this material, you should care about it.
	
	: # don't do anything, but 
 
}
build() (
	cd $EDK2_BUILDER_DIR
	set +u  # edksetup.sh has undefined variables so don't let it fail on that
	. edksetup.sh BaseTools
	set -u
	. edksetup.sh BaseTools
	# make -C BaseTools -j$(nproc) # see the comment in the setup() function. We can do it again here, it's super fast and if it is already built it's faster, but it is unnecessary to repeat
	# Read the comments in the patch() function - to see what to do to include the EFI shell when secure boot is enabled
	# patch  # doesn't do anything anyway now. But read the comments there!
	
	# build is defined in the edksetup.sh file. it will not take precedence, so use command explicitly to avoid a recursive call to this very function the commend is written in
	command build -DSECURE_BOOT_ENABLE -DSHELL_TYPE=BUILD_SHELL -DTPM2_ENABLE -bRELEASE  -pOvmfPkg/OvmfPkgX64.dsc -aX64  -tGCC -n$(nproc)


	#
	# The build will take a couple of minutes and 
	# After building the size of the directory will be something like 2.2GB
	# out of which  Build/OvmfX64/RELEASE_GCC/  would be ~721M (all as per the sampling date Nov 25 2025)
	#
	# You could build with -bDEBUG instead of -bRELEASE if you want to have debug information
	# then, your output will be in Build/OvmfX64/DEBUG_GCC/ and would be ~771M
	#

	echo "Build done. You can peform initial testing by putting an EFI file in a directory (e.g. testfs) and running something like: 
	qemu-system-x86_64  -enable-kvm -drive if=pflash,format=raw,readonly=on,file=$EDK2_BUILDER_DIR/Build/OvmfX64/RELEASE_GCC/FV/OVMF.fd -drive if=virtio,format=raw,file=fat:rw:testfs"
	echo ""
	echo "For more relevant tests that also test the EFI vars, you should copy from the same folder the OVMF_VARS.fd . It doesn't matter then if you use OVMF_CODE.fd or OVMF.fd (which vombines both) for the testing)"
	
	# TODO: the firmware shows but it's not navigable so maybe something is wrong here.
	#       the other firmware I built worked just fine, so it might be something about more definitions.
	echo "You can, for example:
	cp Build/OvmfX64/RELEASE_GCC/FV/OVMF_VARS.fd test_OVMF_VARS.fd 
	qemu-system-x86_64  -enable-kvm -drive if=pflash,format=raw,unit=0,readonly=on,file=Build/OvmfX64/RELEASE_GCC/FV/OVMF_CODE.fd -drive if=virtio,format=raw,file=fat:rw:testfs -drive if=pflash,format=raw,unit=1,file=test_OVMF_VARS.fd -nographic -enable-kvm -m 4G
	"
)

copy_artifacts() {
	cp $EDK2_BUILDER_DIR/Build/OvmfX64/RELEASE_GCC/FV/OVMF_CODE.fd $EDK2_BUILDER_DIR/Build/OvmfX64/RELEASE_GCC/FV/OVMF_VARS.fd $REQUIRED_PROJECTS_ARTIFACTS_DIR
}


$1
