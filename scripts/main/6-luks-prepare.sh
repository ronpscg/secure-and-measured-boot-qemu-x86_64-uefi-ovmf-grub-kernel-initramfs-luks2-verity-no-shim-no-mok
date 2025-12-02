#!/bin/bash
# Creates a LUKS2 encrypted file using a hardcoded password (dangerous, but fine for our purpose of initial provisioning. We could alternatively setup with a keyfile and shred it)

: ${ROOTFS_IMG="./rootfs.img"}             # Path to your existing, unencrypted rootfs image
: ${ROOTFS_ENC_IMG="./rootfs.enc.img"}     # Path for the final, encrypted LUKS container
: ${LUKS_MAPPER_NAME="dmcryptdevice-luks"} # Mapped name under /dev/mapper/ . The "decrypted" device is to be accessed through there.
: ${SOURCE_SIZE_MIB=4096}                  # Size of your unencrypted rootfs.img in MiB. We could use du -b or something like that, but I just wanted to demonstrate

# The buffer should be enough for the header, and in this case, there is no reason to resize the filesystem
# in that case, it is just fine to use the cleartext root filesystem as it is
# otherwise, if it is touched via fsck or resize2fs, the verity has would change.
HEADER_SAFETY_BUFFER_MIB=36                # Buffer size (32 MiB for header + safety)

: ${LUKS_PASSWORD="pass"}                        # This is bad practice of course - but it makes it easier to provision TPM devices on the first time (key can be removed or altered later)
: ${DONT_CLOSE_LUKS_MAPPER_DEVICE=false}         # Set this to true to keep device open, e.g. if you want to use this with another script after setup
: ${LUKS_DONT_RESIZE_TARGET_FS=false}            # Set this to true to avoid resizing the device
: ${LUKS_DONT_FSCK_TARGET_FS=false}              # Set this to true to avoid fsck


if [ ! -f "$ROOTFS_IMG" ]; then
    echo "Error: Source file $ROOTFS_IMG not found. Exiting."
    exit 1
fi

if ! command -v cryptsetup &> /dev/null; then
    echo "Error: cryptsetup is not installed. Please install the required package."
    exit 1
fi

# Could calculate the file size itself
TARGET_SIZE_MIB=$((SOURCE_SIZE_MIB + HEADER_SAFETY_BUFFER_MIB))
PAYLOAD_SIZE_MIB=$SOURCE_SIZE_MIB 


create_luks_container() {
	echo "Source Data Size: ${SOURCE_SIZE_MIB} MiB"
	echo "Container Size:   ${TARGET_SIZE_MIB} MiB"

	echo "[+] Creating target container file: ${ROOTFS_ENC_IMG}..."
	fallocate -l "${TARGET_SIZE_MIB}M" "$ROOTFS_ENC_IMG" 

	if [ $? -ne 0 ] ; then
		echo "Warning: fallocate failed, falling back to dd."
		dd if=/dev/zero of="$ROOTFS_ENC_IMG" bs=1M count="$TARGET_SIZE_MIB" status=progress || { echo "Failed to allocate with dd" ; exit 1 ; }
	fi
}

create_luks_header() {
	echo "[+] Formatting LUKS2 container using STDIN password..."
	echo "$LUKS_PASSWORD" | cryptsetup luksFormat \
    		--type luks2 \
    		--batch-mode \
    		"$ROOTFS_ENC_IMG"

	# Note: commented out alignment because it made data too small for payload - I guess it doesn't really matter 
	#    --align-payload=$((HEADER_SAFETY_BUFFER_MIB * 1024 * 1024)) \
	#
	if [ $? -ne 0 ]; then
	    echo "Error: LUKS format failed. Check size, permissions and password input."
	    exit 1
	fi
}

copy_source_fs_to_luks_container() {
	echo "[+] Opening LUKS container with STDIN password..."
	echo -n "$LUKS_PASSWORD" | sudo cryptsetup open --type luks2 "$ROOTFS_ENC_IMG" "$LUKS_MAPPER_NAME" --key-file=- || exit 1
	TARGET_DEV="/dev/mapper/$LUKS_MAPPER_NAME"

	echo "[+] Copying data from ${ROOTFS_IMG} to ${TARGET_DEV} using dd..."
	sudo dd if="$ROOTFS_IMG" of="$TARGET_DEV" bs=1M status=progress || { echo "Failed to copy device" ; exit 1 ; }
}

resize_target_rootfs_and_cleanup() {
	echo "[+] Finalizing and closing volume..."
	# Force check the filesystem inside LUKS
	if [ ! "$LUKS_DONT_FSCK_TARGET_FS" = "true" ] ; then
		sudo e2fsck -f $TARGET_DEV || echo "Failed to fsck. You may have problems"
	fi
	# Grow the ext4 filesystem to fill the container space
	if [ ! "$LUKS_DONT_RESIZE_TARGET_FS" = "true" ] ; then
		sudo resize2fs $TARGET_DEV || echo "Failed to resizefs. You may have problems"
	fi

	# Close the LUKS volume
	if [ ! "$DONT_CLOSE_LUKS_MAPPER_DEVICE" = "true" ] ; then
		sudo cryptsetup close "$LUKS_MAPPER_NAME" || echo "Failed to close the device"
	else
		echo "Leaving device open. Please don't forget to sudo cryptsetup close $LUKS_MAPPER_NAME when you're done"
	fi

	echo -e "\x1b[32mSUCCESS: Your encrypted image is at ${ROOTFS_ENC_IMG}\x1b[0m"
	echo "Warning: The password is hardcoded in this script. Delete it promptly."

}

main() {
	create_luks_container
	create_luks_header
	copy_source_fs_to_luks_container
	resize_target_rootfs_and_cleanup
}

main $@

