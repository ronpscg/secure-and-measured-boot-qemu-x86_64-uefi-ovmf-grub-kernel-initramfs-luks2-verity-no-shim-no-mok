#!/bin/bash
set -euo pipefail
LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
. $LOCAL_DIR/../common.sh || { echo "Please run the script from the right place" ; exit 1 ; }

echo "[+] Populating ESP materials folder"  
# don't worry about the case - fat is case insensitive. sticking to the cases you would likely see on any Linux machine
mkdir -p $ESP_FS_FOLDER/EFI/Boot

echo "[+] Updating standalone GRUB with latest configuration"
(  cd $LOCAL_DIR/../external-projects && ./build-grub.sh build_standalone_image && ./build-grub.sh copy_artifacts )


echo "[+] Adding unsigned GRUB to the ESP materials"
cp $REQUIRED_PROJECTS_ARTIFACTS_DIR/grubx64.efi $ESP_FS_FOLDER/EFI/Boot/bootx64.efi

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

cp $REQUIRED_PROJECTS_ARTIFACTS_DIR/{OVMF_CODE,OVMF_VARS}.fd $ARTIFACTS_DIR
#cp $REQUIRED_PROJECTS_ARTIFACTS_DIR/

echo OK

echo "For the Rootfs please run make-images-rootfs.sh . Then, note the UUIDs , update the GRUB config, and rerun this script"
