#!/bin/bash
# Note: we get an encrypted image file here # TODO: do this prior to the first boot, and then run directly on the cleartext image
# 

: ${ROOTFS_DECRYPTED_IMG=rootfs.img}
: ${ROOTFS_DECRYPTED_IMG=debian/trixie.img}
: ${DMVERITY_ROOTFS_HASH_IMG=dmverity-hash.img}
# IMPORTANT: This is an example. See the comment past veritysetup format in setup_offline_dm_verity_image
: ${DMVERITY_ROOTFS_ROOT_HASH=838326790061b20c0dfb0a877577de30ce16f020b375e725c45fbddb832bb89d}
: ${DMVERITY_HEADER_TEXT_FILE=dmverity-header.txt}

# I know that I am working with ~2-5GB devices in this example, so 1%-2% of their sizes should be enough for the size
: ${DMVERITY_ROOTFS_HASH_IMG_SIZE=100M}


# decide whether to take the header from an environment variable, or parse a file
set_input_hash() {	
	if [ -e "$DMVERITY_HEADER_TEXT_FILE" ] ; then
		local hash=""
		hash=$(grep "Root hash:" $DMVERITY_HEADER_TEXT_FILE  | tr -d '[:space:]' | cut -d':' -f2) 
		if [ "$hash" = "" ] ; then 
			echo "Your $DMVERITY_HEADER_TEXT_FILE is wrong"
			exit 1
		fi
		echo "using hash: $hash from $DMVERITY_HEADER_TEXT_FILE" 
		DMVERITY_ROOTFS_ROOT_HASH=$hash
	else
		echo "using hash: $hash from an environment variable"
	fi	
}

setup_offline_dm_verity_image() {
	SUDO_FOR_LOOPBACK_DEVICE=sudo # verity setup doesn't need sudo, but if we use it on another /dev/mapper device, it is necessary. Can write cleaner logic, won't do it now
	truncate -s $DMVERITY_ROOTFS_HASH_IMG_SIZE $DMVERITY_ROOTFS_HASH_IMG # or dd doesn't matter
	set -o pipefail
	$SUDO_FOR_LOOPBACK_DEVICE veritysetup format $ROOTFS_DECRYPTED_IMG $DMVERITY_ROOTFS_HASH_IMG | tee $DMVERITY_HEADER_TEXT_FILE || { echo -e "\x1b[31mveritysetup format failed [$?]" ; return $? ; }

	# you should note the output somewhere, and in particular store the result Root Hash in DMVERITY_ROOTFS_ROOT_HASH
}


# This is your test for verifying
verify_offline_image() {
	ROOTFS_LOOP=$(sudo losetup -f --show $ROOTFS_DECRYPTED_IMG)
	HASH_LOOP=$(sudo losetup -f --show  $DMVERITY_ROOTFS_HASH_IMG)
	# I don't know why it wouldn't work without a block-device, maybe in the future it will - so losetup-ing it. Otherwise it may complain on corruption on a valid case

	if sudo veritysetup verify $ROOTFS_LOOP $HASH_LOOP $DMVERITY_ROOTFS_ROOT_HASH ; then
		echo -e "\x1b[32mVerification succeeded\x1b[0m"
	else
	       	echo -e "\x1b[33mVerification failed\x1b[0m"
	fi
	# you should see no output if it worked well /  "Verification of root hash failed." otherwise (at least at the time of writing)
	sudo losetup -d $ROOTFS_LOOP
	sudo losetup -d $HASH_LOOP

	# you could do other cleanups, e.g. with 
	# losetup  | grep $PWD | cut -f 1 -d ' '  | xargs sudo losetup -d
	# or something like that
}

# This is your test for opening the device (and getting a handle at a /dev/mapper (which would be a link to ../dm-<number>)
# You can then mount it, and test what happens if you try to modify its contents
open_and_mount_test_device() {
	mkdir stam
	if ! sudo veritysetup open $ROOTFS_DECRYPTED_IMG dmveritydevice $DMVERITY_ROOTFS_HASH_IMG  $DMVERITY_ROOTFS_ROOT_HASH ; then
		echo -e "\x1b[33mFailed to verify $ROOTFS_DECRYPTED_IMG"
		return 1
	else
		echo -e "\x1b[32mSuccessfully opened $(ls -l /dev/mapper/dmveritydevice)\x1b[0m"
	fi
	
	if ! sudo mount  /dev/mapper/dmveritydevice stam/ ; then
		echo -e "\x1b[33mFailed to mount dmveritydevice\x1b[0m"
	else
		echo -e "\x1b[32mSuccessfully mounted $(mount | grep dmveritydevice)\x1b[0m"
		ls  stam
	fi

	# You should use mount -o ro - this exmaple is expected to show you something like:
	#  WARNING: source write-protected, mounted read-only.

	# Trying to remount a mounted dm-verity device should result in something like this:
	# cannot remount /dev/mapper/dmveritydevice read-write, is write-protected.
	# dmesg(1) may have more information after failed mount system call.


	sudo umount stam || echo "Failed to unmount"
	sudo veritysetup close dmveritydevice || echo "Failed to close device"
}


main() {
	case "$1" in
		setup)
			setup_offline_dm_verity_image
			;;
		verify)
			set_input_hash
			verify_offline_image
			;;
		open)
			set_input_hash
			open_and_mount_test_device
			;;
		*)
			echo -e "$0: <setup|verify|open>\n. You would typically want to do either setup (and note the root hash) or verify. open is another testing and usage demonstration"
			exit 1
			;;
	esac

}

main $@
