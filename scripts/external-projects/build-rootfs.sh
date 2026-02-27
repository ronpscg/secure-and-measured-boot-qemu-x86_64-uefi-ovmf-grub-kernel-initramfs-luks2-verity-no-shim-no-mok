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

	sudo chroot $ROOTFS_DEBOOTSTRAP_DIR bash -c "apt-get install -y ssh isc-dhcp-client"
	sudo chroot $ROOTFS_DEBOOTSTRAP_DIR bash -c "apt-get install -y squashfs-tools"
	sudo chroot $ROOTFS_DEBOOTSTRAP_DIR bash -c "apt-get install -y rauc rauc-service grub-common"

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

	# make some room for some mounts
	# one could also take care of the GRUB env
	# One could also do everything on runtime under /mnt - after making the latter tmpfs on runtime (it is created empty, and it is fine)
	sudo mkdir -p $ROOTFS_DEBOOTSTRAP_DIR/data
	sudo mkdir -p $ROOTFS_DEBOOTSTRAP_DIR/efi

	sudo cp -a $LOCAL_DIR/rootfs-files-extra/* $ROOTFS_DEBOOTSTRAP_DIR
	if [ "$RAUC" = "true" ] ; then
		if ! sudo cp -a $RAUC_CA_CERT $ROOTFS_DEBOOTSTRAP_DIR/etc/rauc/keyring.pem ; then
			echo "Failed to populate your RAUC keyring with $RAUC_CA_CERT. Did you prooperly create the key materials?"
			exit 1
		fi
	fi

	sudo chroot $ROOTFS_DEBOOTSTRAP_DIR /postinstall.sh


	echo "DONE. Careful though: If you boot this rootfs as RO without taking care of writable places - you will be able to work - but login will likely be slow. This is expected, and per design"
}

#
# This is made to have a very easily visible indication of when this was last run.
#
update_version_information() {
	sudo bash -c "cat > $ROOTFS_DEBOOTSTRAP_DIR/etc/update-motd.d/11-build-date" << EOF
#!/bin/sh
echo "\e[35mLast updated this rootfs: $(date)\e[0m"
EOF
	sudo chmod +x $ROOTFS_DEBOOTSTRAP_DIR/etc/update-motd.d/11-build-date
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
			update_version_information
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
	update_version_information
}

main $@
