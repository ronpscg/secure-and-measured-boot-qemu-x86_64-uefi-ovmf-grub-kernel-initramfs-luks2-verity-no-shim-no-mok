#!/bin/bash
LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))

set -euo pipefail

# Allow getting the kernel and initramfs from other places (can do that for GRUB as well, but then will need to sign it externally)
: ${KERNEL_ARTIFACT=$REQUIRED_PROJECTS_ARTIFACTS_DIR/bzImage}
: ${INITRAMFS_ARTIFACT=$REQUIRED_PROJECTS_ARTIFACTS_DIR/initrd.img}
: ${GRUB_ARTIFACT=$REQUIRED_PROJECTS_ARTIFACTS_DIR/grubx64.efi}
: ${GRUB_CONFIG_ARTIFACT=$REQUIRED_PROJECTS_ARTIFACTS_DIR/grub.cfg}
: ${TARGET_KERNEL_NAME=bzImage}
: ${TARGET_INITRAMFS_NAME=initrd.img}
: ${KEYS_DIR=$ARTIFACTS_DIR/keys}
# The next two are not relevant here
: ${ROOTFS_IMG_ARTIFACT=$REQUIRED_PROJECTS_ARTIFACTS_DIR/rootfs.img}
: ${ROOTFS_VERITY_HASH_ARTIFACT=$REQUIRED_PROJECTS_ARTIFACTS_DIR/rootfs.verityhash.img}
# 
: ${TARGET_GRUB_NAME=bootx64.efi}
: ${TARGET_GRUB_CONFIG_NAME=grub.cfg}



init_folders() {
	echo "[+] Populating ESP materials folder"  
	# don't worry about the case - fat is case insensitive. sticking to the cases you would likely see on any Linux machine
	mkdir -p $ESP_FS_FOLDER/EFI/Boot

	PUT_BOOT_MATERIALS_IN_ESP_FS=true
	if [ "$PUT_BOOT_MATERIALS_IN_ESP_FS" ] ; then
		echo "Adding kernel and initramfs to the ESP partition. This is used to have less devices, and make it easier to work and debug when you \"run the folder\""
		echo "While you could choose ot put your kernel and initramfs (and device trees, and...) on another partition usually, there is no harm in doing it, especially during development or learning"

		echo "Make sure you point GRUB to the (hd,ESP partition)/boot/... for the files"
	else
		echo "TODO: create the boot folder later in that case, and add a boot partition probably. The project does not support it now, although it's peanuts"
		echo "Make sure you point GRUB to the (hd, boot partition) ... for the files"
	fi
}

copy_kernel_and_initramfs() {
        if [ "$MAKEIMAGE_STEP_DONT_COPY_KERNEL_AND_INITRAMFS" = "true" ] ; then
                return
        fi
	echo "[+] Adding kernel and initramfs to $BOOT_FS_FOLDER"
	mkdir -p $BOOT_FS_FOLDER
	cp ${KERNEL_ARTIFACT} ${BOOT_FS_FOLDER}/${TARGET_KERNEL_NAME}
	cp ${INITRAMFS_ARTIFACT} $BOOT_FS_FOLDER/${TARGET_INITRAMFS_NAME}
}

copy_grub() {
        if [ "$MAKEIMAGE_STEP_DONT_COPY_GRUB" = "true" ] ; then
                return
        fi
	echo "[+] Copying the GRUB image to the artifacts dir and to the target $ESP_FS_FOLDER/EFI/Boot/"
	# Note: in general, if full A/B update is required, there will be more folders naturally, and one can find themselves putting the boot materials, and the GRUB config in another (e.g. ext4) partition. One can extend this functionality to sign GRUB modules, fonts, etc. For now there will be support only for a separate config file, and it will be 
	# copied to the same place the GRUB EFI is copied to (doesn't have to be like this). One could go and have that file load other files from other partitions etc., which could be useful
	# for "playing" if secure boot is not enabled, or if they are signed
	if [ "$GRUB_BUILD_STANDALONE" = "false" -a "$GRUB_COPY_FILES_TO_TARGET" = "true" ] ; then
		echo "Also copying grub.cfg"
		cp $GRUB_CONFIG_ARTIFACT $ARTIFACTS_DIR # just for consistency, and to have everything nicely place in the directory. We don't really need it there
		cp $GRUB_CONFIG_ARTIFACT $ESP_FS_FOLDER/EFI/Boot/grub.cfg
	fi
	cp $GRUB_ARTIFACT $ARTIFACTS_DIR/grubx64.efi
}

update_grub() {
        if [ "$MAKEIMAGE_STEP_DONT_UPDATE_GRUB" = "true" ] ; then
                return
        fi

	echo "[+] Creating the GRUB image to include in your target"
	if [ -f $LUKS_AND_DMVERITY_EXPORTED_ENV_FILE ] ; then
		echo "[+] Sourcing $LUKS_AND_DMVERITY_EXPORTED_ENV_FILE and updating $GRUB_CONFIG accordingly"
		( 
		# in a subshell to not spam the environment although maybe other elements require it as well
		set -a 
		. $LUKS_AND_DMVERITY_EXPORTED_ENV_FILE &&  $LOCAL_DIR/../external-projects/build-grub.sh update_grub_work_config
		set +a
		)       
	fi

	. $LOCAL_DIR/../external-projects/build-grub.sh build_grub_efi
	. $LOCAL_DIR/../external-projects/build-grub.sh copy_artifacts
}


#
# GRUB has its own way to use signatures, if the SHIM is not involved.
# Sign the elements with the respective GRUB keys
# On the sign_efi_loaded_elements() function, you will also see that the executables GRUB loads (Linux kernel) are signed with the EFI key
# We deliberately separated the functions, so the name of this function might be a bit misleading. We hope this comment clarifies it.
#
sign_grub_loaded_elements() {
        if [ "$MAKEIMAGE_STEP_DONT_SIGN_GRUB_LOADED_ELEMENTS" = "true" ] ; then
                return
        fi

	if [ "$SECURE_BOOT" = "true" ] ; then 
		echo "[+] Signing everything GRUB loads directly with its PGP keys"
		gpg --yes --local-user $GRUB_PGP_EMAIL --detach-sign $BOOT_FS_FOLDER/${TARGET_KERNEL_NAME}


		# This is needed in case you would still like to verify the signature, and to avoid the "No one wants verification" error when there is no shim
		# (I don't know if it can be pypassed without a GRUB patch)
		gpg --yes --local-user $GRUB_PGP_EMAIL --detach-sign $BOOT_FS_FOLDER/${TARGET_KERNEL_NAME}.signed


		### initrd - fine to verify with GPG only (won't load without signing if secure boot and check_signature are on
		gpg --yes --local-user $GRUB_PGP_EMAIL --detach-sign $BOOT_FS_FOLDER/${TARGET_INITRAMFS_NAME}

		if [ "$GRUB_BUILD_STANDALONE" = "false" -a "$GRUB_COPY_FILES_TO_TARGET" = "true" ] ; then
			# if other things (modules, fonts, whatever) are added - you may want to sign them as well
			echo "Also signing grub.cfg"
			gpg --yes --local-user $GRUB_PGP_EMAIL --detach-sign  $ESP_FS_FOLDER/EFI/Boot/grub.cfg
		fi
	fi
}


sign_efi_loaded_elements() {
        if [ "$MAKEIMAGE_STEP_DONT_SIGN_EFI_LOADED_ELEMENTS" = "true" ] ; then
                return
        fi

	if [ "$SECURE_BOOT" = "true" ] ; then 
		echo "[+] Adding signed GRUB to the ESP materials"
		# sbsign is from the sbsigntool . Install it if needed
		sbsign --key $KEYS_DIR/db.key --cert $KEYS_DIR/db.crt \
			--output $ARTIFACTS_DIR/grubx64.efi.signed $ARTIFACTS_DIR/grubx64.efi
		cp $ARTIFACTS_DIR/grubx64.efi.signed $ESP_FS_FOLDER/EFI/Boot/bootx64.efi 

		echo "[+] Signing the Linux kernel with the EFI key, since GRUB also uses the firmware to verify (the executable, which is only the Linux kernel) if secure boot is loaded"
		# Since GRUB uses the firmware to verify, this is required
		sbsign --key $KEYS_DIR/db.key --cert $KEYS_DIR/db.crt \
			--output $BOOT_FS_FOLDER/${TARGET_KERNEL_NAME}.signed $BOOT_FS_FOLDER/${TARGET_KERNEL_NAME}
	else
		echo "[+] Adding unsigned GRUB to the ESP materials"
		cp $ARTIFACTS_DIR/grubx64.efi $ESP_FS_FOLDER/EFI/Boot/bootx64.efi # This is the unsigned version
	fi
}

sign_boot_elements() {
	sign_efi_loaded_elements
	sign_grub_loaded_elements
}

copy_ovmf() {
	if [ "$MAKEIMAGE_STEP_DONT_COPY_OVMF" = "true" ] ; then
		return
	fi
	echo "[+] Updating OVFM_CODE.fd"
	cp $REQUIRED_PROJECTS_ARTIFACTS_DIR/OVMF_CODE.fd $ARTIFACTS_DIR

	if [ ! -e $ARTIFACTS_DIR/OVMF_VARS.fd  ] ; then
		# Don't copy over if it exits - or you will have to setup the firmware again
		echo "[+] Creating OVMF_VARS.fd for the first time"
		cp $REQUIRED_PROJECTS_ARTIFACTS_DIR/OVMF_VARS.fd $ARTIFACTS_DIR
	fi
}



main() {
	init_folders			# Set the work folders where the ESP will be populated and the EFI apps will reside, and where the Linux materials will reside
	copy_ovmf			# Copy over the already built OVMF code, and the OVMF vars if need be (if it is the first time. You would usally want to keep the vars state)
	copy_kernel_and_initramfs	# Copy over the already built kernel and initramfs

	update_grub			# This is a separate step because unless you want to install a non-standalone GRUB, you must build it after you know the config
	copy_grub			# Separating copying from updating, to allow copying a config file where it is separate and rebuilding GRUB is not necessary
	
	sign_boot_elements		# This signs everything that needs to be signed
	echo -e "\x1b[32mDONE\x1b[0m"
	echo ""
	echo "For the Rootfs please run make-images-rootfs.sh . Then, note the UUIDs , update the GRUB config, and rerun this script"
}

main $@
