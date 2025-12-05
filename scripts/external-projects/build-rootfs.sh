#!/bin/bash


LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))

debootstrap() {
	if [ -d $ROOTFS_DEBOOTSTRAP_DIR ] ; then
		echo "Assuming the rootfs is already setup"
		exit 0
	fi
	echo "[+] Debootstrapping Trixie"
	sudo debootstrap --variant=minbase trixie $ROOTFS_DEBOOTSTRAP_DIR  
	echo "Done debootstrapping $ROOTFS_DEBOOTSTRAP_DIR"
}


add_more_packages() {
	echo "[+] Adding more packages"
	sudo chroot $ROOTFS_DEBOOTSTRAP_DIR bash -c "apt-get install -y fdisk parted e2fsprogs iproute2 iputils-ping vim tpm2-tools fwupd efitools"
	sudo chroot $ROOTFS_DEBOOTSTRAP_DIR bash -c "apt-get install -y cryptsetup"  # Useful for detection of currently enrolled keys

	sudo chroot $ROOTFS_DEBOOTSTRAP_DIR bash -c "apt-get clean"
	# Could also remove $ROOTFS_DEBOOTSTRAP_DIR/var/lib/apt/lists/* won't do it here (It's ~55MB for what is installed in the previous line)
}

make_read_only_friendly() {
	: # Won't do anything here for now
}

add_more_customizations() {
	echo "[+] Applying some configurations"
	sudo chroot $ROOTFS_DEBOOTSTRAP_DIR bash -c "echo -e 'root\nroot\n' | passwd root"
	sudo chroot $ROOTFS_DEBOOTSTRAP_DIR bash -c "passwd -d root"  # Allow an extra level of laziness, but do not autologin (it is intentional)
	sudo chroot $ROOTFS_DEBOOTSTRAP_DIR bash -c "echo PscgSecureOS > /etc/hostname"

	sudo cp -a $LOCAL_DIR/rootfs-files-extra/* $ROOTFS_DEBOOTSTRAP_DIR
	sudo chroot $ROOTFS_DEBOOTSTRAP_DIR /postinstall.sh


	echo "DONE. Careful though: If you boot this rootfs as RO without taking care of writable places - you will be able to work - but login will likely be slow. This is expected, and per design"
}


main() {
	# The argument is meant only for directly invoking this file, after sourcing common.sh. It is not intended for the automatic use of most users with setup-or-build.sh
	case $1 in
		rebuild)
			echo "[+] Recreating your rootfs from scratch. Removing your previous artifacts"
			sudo rm -rf $ROOTFS_DEBOOTSTRAP_DIR
			;;
		debootstrap|add_more_packages|add_more_customizations)
			set -euo pipefail
			cmd=$1
			shift
			$cmd $@
			exit
			;;
		*)
			echo "$0: $@"
			;;
	esac

	set -euo pipefail
	debootstrap
	add_more_packages
	add_more_customizations
}

main $@
