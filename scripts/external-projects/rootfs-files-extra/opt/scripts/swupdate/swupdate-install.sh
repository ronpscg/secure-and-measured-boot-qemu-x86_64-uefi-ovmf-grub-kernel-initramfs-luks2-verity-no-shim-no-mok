#!/bin/sh
# ---------------------------------------------------------------------------
# swupdate-install.sh  -  SWUpdate A/B wrapper for PscgSecureOS
#
# This script lives permanently on the target and replaces RAUC's built-in
# automatic slot selection.
#
# Usage:
#   swupdate-install.sh <bundle.swu>
#
# What it does:
#   1. Reads grubenv to determine the active slot
#   2. Selects the inactive slot as the install target
#   3. Writes both slots to /run/swupdate-slot-info for post-install-hook.sh
#   4. Calls swupdate with -e "stable,slotA" or -e "stable,slotB"
# ---------------------------------------------------------------------------

GRUBENV=/efi/EFI/Boot/grubenv
BUNDLE="$1"

if [ -z "$BUNDLE" ] || [ ! -f "$BUNDLE" ]; then
	echo "Usage: $0 <bundle.swu>"
	exit 1
fi

# ---------------------------------------------------------------------------
# Determine active slot - three-level fallback
# ---------------------------------------------------------------------------

# Primary: kernel cmdline explicit marker
# (requires pscg.slot=A or pscg.slot=B in grub.cfg kernel args)
ACTIVE_SLOT=""
if grep -qo 'pscg\.slot=A' /proc/cmdline 2>/dev/null ; then
	ACTIVE_SLOT="A"
elif grep -qo 'pscg\.slot=B' /proc/cmdline 2>/dev/null ; then
	ACTIVE_SLOT="B"
fi

# Fallback: support RAUC parameters (simpler as RAUC was implemented before in this project)
if [ -z "$ACTIVE_SLOT" ]; then
	if grep -qo 'rauc\.slot=A' /proc/cmdline 2>/dev/null ; then
		ACTIVE_SLOT="A"
	elif grep -qo 'rauc\.slot=B' /proc/cmdline 2>/dev/null ; then
		ACTIVE_SLOT="B"
	fi
fi

# Fallback: BOOT_ORDER first entry in grubenv
if [ -z "$ACTIVE_SLOT" ]; then
	BOOT_ORDER=$(grub-editenv "$GRUBENV" list 2>/dev/null \
		| grep '^ORDER=' | cut -d= -f2)
	ACTIVE_SLOT=$(echo "$BOOT_ORDER" | cut -d, -f1 | tr -d ' ')
fi

# Last resort: A_OK / B_OK
if [ -z "$ACTIVE_SLOT" ]; then
	A_OK=$(grub-editenv "$GRUBENV" list 2>/dev/null | grep '^A_OK=' | cut -d= -f2)
	B_OK=$(grub-editenv "$GRUBENV" list 2>/dev/null | grep '^B_OK=' | cut -d= -f2)
	if [ "$A_OK" = "1" ] && [ "$B_OK" != "1" ]; then
		ACTIVE_SLOT="A"
	elif [ "$B_OK" = "1" ] && [ "$A_OK" != "1" ]; then
		ACTIVE_SLOT="B"
	else
		echo "$0: ERROR - cannot determine active slot from grubenv. Aborting."
		exit 1
	fi
fi

# Target = the inactive slot
case "$ACTIVE_SLOT" in
	A) TARGET_SLOT="B" ;;
	B) TARGET_SLOT="A" ;;
	*)
		echo "$0: ERROR - unrecognised active slot: '$ACTIVE_SLOT'"
		exit 1
		;;
esac

echo "$0: Active slot: $ACTIVE_SLOT  -->  Installing to slot: $TARGET_SLOT"

# ---------------------------------------------------------------------------
# Write both slots for post-install-hook.sh
# Format: TARGET_SLOT ACTIVE_SLOT
# ---------------------------------------------------------------------------
echo "$TARGET_SLOT $ACTIVE_SLOT" > /run/swupdate-slot-info

# ---------------------------------------------------------------------------
# Invoke SWUpdate
# ---------------------------------------------------------------------------
swupdate -i "$BUNDLE" \
	-f /etc/swupdate/swupdate.cfg \
	-k /etc/swupdate/keyring.pem \
	-e "stable,slot${TARGET_SLOT}" \
	${MORE_FLAGS}	# Can set MORE_FLAGS=-v for verbosity for example prior to running this script

RESULT=$?
if [ $RESULT -ne 0 ]; then
	echo "$0: ERROR - swupdate failed (exit $RESULT)"
	rm -f /run/swupdate-slot-info
	exit 1
fi

echo "$0: Update complete. Reboot to boot from slot $TARGET_SLOT."
exit 0
