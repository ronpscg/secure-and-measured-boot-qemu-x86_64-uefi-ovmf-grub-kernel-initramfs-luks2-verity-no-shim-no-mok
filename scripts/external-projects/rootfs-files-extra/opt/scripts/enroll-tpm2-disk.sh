#!/bin/bash
set -euo pipefail

# Print to console (visible during boot)
console() {
	echo "$@" > /dev/console
	echo "$@" >&2
}

console ""
console "TPM2 LUKS auto-provisioning starting"
console ""

CMDLINE=$(cat /proc/cmdline)

# Extract all rd.luks.name=UUID=name entries
mapfile -t LUKS_ENTRIES < <(echo "$CMDLINE" | grep -o 'rd\.luks\.name=[^ ]*' || true)

if [[ ${#LUKS_ENTRIES[@]} -eq 0 ]]; then
	console "No rd.luks.name entries found in kernel command line."
	exit 0
fi

for entry in "${LUKS_ENTRIES[@]}"; do
	# rd.luks.name=<UUID>=<name>
	RAW="${entry#rd.luks.name=}"
	LUKS_UUID="${RAW%%=*}"
	MAPPED_NAME="${RAW#*=}"

	console "Processing LUKS UUID: $LUKS_UUID (mapped name: $MAPPED_NAME)"

	DEVICE_SYMLINK="/dev/disk/by-uuid/$LUKS_UUID"

	if [[ ! -e "$DEVICE_SYMLINK" ]]; then
		console "  ERROR: Device not found: $DEVICE_SYMLINK"
		continue
	fi

	REAL_DEVICE=$(readlink -f "$DEVICE_SYMLINK")
	console "  Resolved device: $REAL_DEVICE"

	console "  Checking for existing TPM2 keyslots..."

	if cryptsetup luksDump $REAL_DEVICE | grep -q tpm2 ; then
		console "TPM device is already enrolled"
	else
		console "Enrolling your TPM2 device for passwordless disk encryption"
		if systemd-cryptenroll --tpm2-device=auto $REAL_DEVICE ; then
			console "Enrolling succeeded"
		else
			console "Enrolling failed"
		fi
	fi
done

exit 0

