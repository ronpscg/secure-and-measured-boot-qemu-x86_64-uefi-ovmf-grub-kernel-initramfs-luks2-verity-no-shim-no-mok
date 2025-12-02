#!/bin/bash
set -euo pipefail
LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
. $LOCAL_DIR/../common.sh || { echo "Please run the script from the right place" ; exit 1 ; }

# Allow getting the kernel and initramfs from other places (can do that for GRUB as well, but then will need to sign it externally)
: ${KERNEL_ARTIFACT=$REQUIRED_PROJECTS_ARTIFACTS_DIR/bzImage}
: ${INITRAMFS_ARTIFACT=$REQUIRED_PROJECTS_ARTIFACTS_DIR/initrd.img}
: ${TARGET_KERNEL_NAME=bzImage}
: ${TARGET_INITRAMFS_NAME=initrd.img}

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


echo "[+] Adding kernel and initramfs to $BOOT_FS_FOLDER"
mkdir -p $BOOT_FS_FOLDER
cp ${KERNEL_ARTIFACT} ${BOOT_FS_FOLDER}/${TARGET_KERNEL_NAME}
cp ${INITRAMFS_ARTIFACT} $BOOT_FS_FOLDER/${TARGET_INITRAMFS_NAME}


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

# Note: in general, if full A/B update is required, there will be more folders naturally, and one can find themselves putting the boot materials, and the GRUB config in another (e.g. ext4) partition. One can extend this functionality to sign GRUB modules, fonts, etc. For now there will be support only for a separate config file, and it will be 
# copied to the same place the GRUB EFI is copied to (doesn't have to be like this). One could go and have that file load other files from other partitions etc., which could be useful
# for "playing" if secure boot is not enabled, or if they are signed
if [ "$GRUB_BUILD_STANDALONE" = "false" -a "$GRUB_COPY_FILES_TO_TARGET" = "true" ] ; then
	echo "Also copying grub.cfg"
	cp $GRUB_CONFIG $ESP_FS_FOLDER/EFI/Boot/grub.cfg
fi
cp $REQUIRED_PROJECTS_ARTIFACTS_DIR/grubx64.efi $ARTIFACTS_DIR/grubx64.efi

if [ "$SECURE_BOOT" = "true" ] ; then 
	echo "[+] Adding signed GRUB to the ESP materials"
	# sbsign is from the sbsigntool . Install it if needed
	sbsign --key $ARTIFACTS_DIR/keys/db.key --cert $ARTIFACTS_DIR/keys/db.crt \
		--output $ARTIFACTS_DIR/grubx64.efi.signed $ARTIFACTS_DIR/grubx64.efi
	cp $ARTIFACTS_DIR/grubx64.efi.signed $ESP_FS_FOLDER/EFI/Boot/bootx64.efi # This is the unsigned version

	echo "[+] Signing everything GRUB loads directly with its PGP keys, and the kernel also with the EFI keys"
	gpg --yes --local-user $GRUB_PGP_EMAIL --detach-sign $BOOT_FS_FOLDER/${TARGET_KERNEL_NAME}

	# Since GRUB uses the firmware to verify, this is required
	sbsign --key $ARTIFACTS_DIR/keys/db.key --cert $ARTIFACTS_DIR/keys/db.crt \
		--output $BOOT_FS_FOLDER/${TARGET_KERNEL_NAME}.signed $BOOT_FS_FOLDER/${TARGET_KERNEL_NAME}

	# This is needed in case you would still like to verify the signature, and to avoid the "No one wants verification" error when there is no shim
	# (I don't know if it can be pypassed without a GRUB patch)
	gpg --yes --local-user $GRUB_PGP_EMAIL --detach-sign $BOOT_FS_FOLDER/${TARGET_KERNEL_NAME}.signed


	### initrd - fine to verify with GPG only (won't load without signing if secure boot and check_signature are on
	gpg --yes --local-user $GRUB_PGP_EMAIL --detach-sign $BOOT_FS_FOLDER/${TARGET_INITRAMFS_NAME}

	if [ "$GRUB_BUILD_STANDALONE" = "false" -a "$GRUB_COPY_FILES_TO_TARGET" = "true" ] ; then
		echo "Also signing grub.cfg"
		gpg --yes --local-user $GRUB_PGP_EMAIL --detach-sign  $ESP_FS_FOLDER/EFI/Boot/grub.cfg
	fi
else
	echo "[+] Adding unsigned GRUB to the ESP materials"
	cp $ARTIFACTS_DIR/grubx64.efi $ESP_FS_FOLDER/EFI/Boot/bootx64.efi # This is the unsigned version
fi

echo "[+] Updating OVFM_CODE.fd"
cp $REQUIRED_PROJECTS_ARTIFACTS_DIR/OVMF_CODE.fd $ARTIFACTS_DIR

if [ ! -e $ARTIFACTS_DIR/OVMF_VARS.fd  ] ; then
	# Don't copy over if it exits - or you will have to setup the firmware again
	echo "[+] Creating OVMF_VARS.fd for the first time"
	cp $REQUIRED_PROJECTS_ARTIFACTS_DIR/OVMF_VARS.fd $ARTIFACTS_DIR
fi

echo -e "\x1b[32mDONE\x1b[0m"
echo ""
echo "For the Rootfs please run make-images-rootfs.sh . Then, note the UUIDs , update the GRUB config, and rerun this script"
