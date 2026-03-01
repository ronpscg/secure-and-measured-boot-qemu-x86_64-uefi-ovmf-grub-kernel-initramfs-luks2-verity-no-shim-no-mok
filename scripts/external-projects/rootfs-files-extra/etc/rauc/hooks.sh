#!/bin/sh

TRANSPORT_PASS="pass"

echo "$0: Starting. Raw Indices: $RAUC_TARGET_SLOTS"

for ID in $RAUC_TARGET_SLOTS; do

	# Resolve immutable Name and Device path from Environment
	eval NAME=\$RAUC_SLOT_NAME_$ID
	eval DEV=\$RAUC_SLOT_DEVICE_$ID

	case "$NAME" in
		"rootfs.0"|"rootfs.1")
			echo -e "$0: Target confirmed: \e[35m$NAME ($DEV)\e[0m. Enrolling TPM..."	
			PASS_FILE=$(mktemp)
			echo -n "$TRANSPORT_PASS" > "$PASS_FILE"
			systemd-cryptenroll "$DEV" \
				--tpm2-device=auto \
				--tpm2-pcrs=7 \
				--unlock-key-file="$PASS_FILE" \
			#
			#  uncomment the next line and delete this line and the line after the next line if you want to completely get rid of the password and understand the risks
			#	--wipe-slot=0
			RESULT=$?
			rm -f "$PASS_FILE"

			if [ $RESULT -ne 0 ]; then
				echo "[RAUC-HOOK] Error: TPM enrollment failed for $NAME (Exit Code: $RESULT)."
				exit 1
			fi
			echo -e "\e[32m$0 Success.\e[0m"

			# Ensure the slot we just installed to is NOT marked OK yet
			# Without it, the success value of the post install hook would set it as OK automatically, and while one may decide it is fine before booting,
			# one should usually prefer to "mark-good" only after verifying some things in runtime after rebooting

			# Retrieve retry policy from grubenv, default to 3 if missing/corrupt
			RETRY_POLICY=$(grub-editenv /efi/EFI/Boot/grubenv list | grep RAUC_RETRY_COUNT | cut -d= -f2)
			if [ -z "$RETRY_POLICY" ]; then RETRY_POLICY=3; fi

			if [ "$NAME" = "rootfs.0" ]; then
				grub-editenv /efi/EFI/Boot/grubenv set A_OK=0
				grub-editenv /efi/EFI/Boot/grubenv set A_TRY=$RETRY_POLICY
			else
				grub-editenv /efi/EFI/Boot/grubenv set B_OK=0
				grub-editenv /efi/EFI/Boot/grubenv set B_TRY=$RETRY_POLICY
			fi
			;;

		*)
			# Silently ignore boot, dmverity hash, or other partitions
			echo "$0: Skipping non-rootfs partition: $NAME"
			;;
	esac

done
