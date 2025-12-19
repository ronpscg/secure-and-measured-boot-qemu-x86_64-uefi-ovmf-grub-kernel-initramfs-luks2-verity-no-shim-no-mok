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
			;;

		*)
			# Silently ignore boot, dmverity hash, or other partitions
			echo "$0: Skipping non-rootfs partition: $NAME"
			;;
		esac
done

