#!/bin/sh
# ---------------------------------------------------------------------------
# swupdate-mark-good-bad.sh  -  SWUpdate A/B mark-good or mark-bad wrapper for PscgSecureOS
#
# Usage:
#   <script-name> mark-good - marks the currently booted partition as good and updates the bootloader environment variables
#   <script-name> mark-bad - marks the currently booted partition as bad and updates the bootloader environment variables
# ---------------------------------------------------------------------------

GRUBENV=/efi/EFI/Boot/grubenv
BUNDLE="$1"



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

case $1 in
	mark-good|good|ok)
		grub-editenv "$GRUBENV" set ${ACTIVE_SLOT}_OK=1
		grub-editenv "$GRUBENV" set ${ACTIVE_SLOT}_TRY=0
		;;
	mark-bad|bad|fail)
		grub-editenv "$GRUBENV" set ${ACTIVE_SLOT}_OK=0
		;;
	*)
		echo "Invalid value $1"
		exit 1
		;;
esac

exit 0
