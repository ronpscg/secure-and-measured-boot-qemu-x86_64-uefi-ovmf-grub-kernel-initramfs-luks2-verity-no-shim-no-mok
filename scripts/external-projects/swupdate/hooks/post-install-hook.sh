#!/bin/sh
# ---------------------------------------------------------------------------
# post-install-hook.sh  -  SWUpdate postinstall hook for PscgSecureOS
#
# Called by SWUpdate as a postinstall handler after all images are written.
# SWUpdate does not pass $1 for postinstall type - it just executes the script.
#
# The target slot and active slot are read from /run/swupdate-slot-info
# written by swupdate-install.sh before invoking swupdate.
# Format: TARGET_SLOT ACTIVE_SLOT
#
# Mirrors the RAUC post-install-hook.sh exactly:
#   1. Optional TPM auto-enrolment
#   2. Sets X_OK=0 X_TRY=<retry_policy> for the target slot in grubenv
#   3. Sets BOOT_ORDER so GRUB tries the new slot on next boot
# ---------------------------------------------------------------------------

GRUBENV=/efi/EFI/Boot/grubenv
TRANSPORT_PASS="pass"

# ---------------------------------------------------------------------------
# Read target and active slots written by swupdate-install.sh
# ---------------------------------------------------------------------------
SLOT_INFO_FILE=/run/swupdate-slot-info
if [ ! -f "$SLOT_INFO_FILE" ]; then
	echo "$0: ERROR - $SLOT_INFO_FILE not found. Was swupdate-install.sh used?"
	exit 1
fi
TARGET_SLOT=$(awk '{print $1}' "$SLOT_INFO_FILE")
ACTIVE_SLOT=$(awk '{print $2}' "$SLOT_INFO_FILE")

case "$TARGET_SLOT" in
	A|B) ;;
	*)
		echo "$0: ERROR - invalid target slot: '$TARGET_SLOT'"
		exit 1
		;;
esac
case "$ACTIVE_SLOT" in
	A|B) ;;
	*)
		echo "$0: ERROR - invalid active slot: '$ACTIVE_SLOT'"
		exit 1
		;;
esac

TARGET_DEV_ROOTFS=/dev/disk/by-partlabel/ROOTFS_${TARGET_SLOT}
echo "$0: postinstall - target slot: $TARGET_SLOT  active slot: $ACTIVE_SLOT  device: $TARGET_DEV_ROOTFS"

# ---------------------------------------------------------------------------
# TPM auto-enrolment (identical logic to RAUC hook)
# ---------------------------------------------------------------------------
do_tpm_auto_enrollment() {
	if ! grep -q tpm.autoenrollment /proc/cmdline ; then
		return 0
	fi
	echo "$0: Enrolling TPM for slot $TARGET_SLOT ($TARGET_DEV_ROOTFS)..."
	PASS_FILE=$(mktemp)
	echo -n "$TRANSPORT_PASS" > "$PASS_FILE"
	systemd-cryptenroll "$TARGET_DEV_ROOTFS" \
		--tpm2-device=auto \
		--tpm2-pcrs=7 \
		--unlock-key-file="$PASS_FILE"
		# Uncomment --wipe-slot=0 to remove passphrase slot after enrolment.
	RESULT=$?
	rm -f "$PASS_FILE"
	if [ $RESULT -ne 0 ]; then
		echo "$0: ERROR - TPM enrolment failed for slot $TARGET_SLOT (exit $RESULT)"
		exit 1
	fi
	echo "$0: TPM enrolment success."
}

# ---------------------------------------------------------------------------
# Update grubenv - mirrors RAUC hook exactly:
#   Do NOT mark OK yet - mark-good happens at runtime after verified boot.
#   Set X_OK=0 and X_TRY=<retry_policy> so GRUB tries the new slot.
#   Set BOOT_ORDER so the new slot is attempted first on next boot.
# ---------------------------------------------------------------------------
update_grubenv() {
	RETRY_POLICY=$(grub-editenv "$GRUBENV" list 2>/dev/null \
		| grep '^RAUC_RETRY_COUNT=' | cut -d= -f2)
	[ -z "$RETRY_POLICY" ] && RETRY_POLICY=3

	grub-editenv "$GRUBENV" set ${TARGET_SLOT}_OK=0
	grub-editenv "$GRUBENV" set ${TARGET_SLOT}_TRY=$RETRY_POLICY
	grub-editenv "$GRUBENV" set ORDER="$TARGET_SLOT $ACTIVE_SLOT"
	sync "$GRUBENV"	# syncs the caches in the partitions of GRUBENV, not (just) the file itself

	echo "$0: grubenv updated: ${TARGET_SLOT}_OK=0  ${TARGET_SLOT}_TRY=$RETRY_POLICY  order=$TARGET_SLOT $ACTIVE_SLOT"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
do_tpm_auto_enrollment
update_grubenv

# Clean up temporary files
rm -f "$SLOT_INFO_FILE"

echo "$0: postinstall complete."
exit 0
