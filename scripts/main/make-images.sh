#!/bin/bash
set -euo pipefail
LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
. $LOCAL_DIR/../common.sh || { echo "Please run the script from the right place" ; exit 1 ; }

echo "[+] Populating ESP materials folder"  
# don't worry about the case - fat is case insensitive. sticking to the cases you would likely see on any Linux machine
mkdir -p $ESP_FS_FOLDER/EFI/Boot

echo "[+] Updating standalone GRUB with latest configuration"
export SECURE_BOOT=true # TODO put elsewhere
(  cd $LOCAL_DIR/../external-projects && ./build-grub.sh build_standalone_image && ./build-grub.sh copy_artifacts )
cp $REQUIRED_PROJECTS_ARTIFACTS_DIR/grubx64.efi $ARTIFACTS_DIR/grubx64.efi
if [ "$SECURE_BOOT" = "true" ] ; then 
	echo "[+] Adding signed GRUB to the ESP materials"
	# sbsign is from the sbsigntool . Install it if needed
	sbsign --key $ARTIFACTS_DIR/keys/db.key --cert $ARTIFACTS_DIR/keys/db.crt \
		--output $ARTIFACTS_DIR/grubx64.efi.signed $ARTIFACTS_DIR/grubx64.efi
	cp $ARTIFACTS_DIR/grubx64.efi.signed $ESP_FS_FOLDER/EFI/Boot/bootx64.efi # This is the unsigned version

	echo "[+] Signing everything GRUB loads directly with its PGP keys, and the kernel also with the EFI keys"
	gpg --yes --local-user $GRUB_PGP_EMAIL --detach-sign $BOOT_FS_FOLDER/bzImage

	# Since GRUB uses the firmware to verify, this is required
	sbsign --key $ARTIFACTS_DIR/keys/db.key --cert $ARTIFACTS_DIR/keys/db.crt \
		--output $BOOT_FS_FOLDER/bzImage.signed $BOOT_FS_FOLDER/bzImage

	# This is needed in case you would still like to verify the signature, and to avoid the "No one wants verification" error when there is no shim
	# (I don't know if it can be pypassed without a GRUB patch)
	gpg --yes --local-user $GRUB_PGP_EMAIL --detach-sign $BOOT_FS_FOLDER/bzImage.signed


	### initrd - fine to verify with GPG only (won't load without signing if secure boot and check_signature are on
	gpg --yes --local-user $GRUB_PGP_EMAIL --detach-sign $BOOT_FS_FOLDER/initrd.img

else
	echo "[+] Adding unsigned GRUB to the ESP materials"
	cp $ARTIFACTS_DIR/grubx64.efi $ESP_FS_FOLDER/EFI/Boot/bootx64.efi # This is the unsigned version
fi

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
cp $REQUIRED_PROJECTS_ARTIFACTS_DIR/bzImage $BOOT_FS_FOLDER
cp $REQUIRED_PROJECTS_ARTIFACTS_DIR/initrd.img $BOOT_FS_FOLDER

cp $REQUIRED_PROJECTS_ARTIFACTS_DIR/OVMF_CODE.fd $ARTIFACTS_DIR

if [ ! -e $REQUIRED_PROJECTS_ARTIFACTS_DIR/OVMF_VARS.fd  ] ; then
	# Don't copy over if it exits - or you will have to setup the firmware again
	cp $REQUIRED_PROJECTS_ARTIFACTS_DIR/OVMF_VARS.fd $ARTIFACTS_DIR
fi
#cp $REQUIRED_PROJECTS_ARTIFACTS_DIR/

echo OK

echo "For the Rootfs please run make-images-rootfs.sh . Then, note the UUIDs , update the GRUB config, and rerun this script"
