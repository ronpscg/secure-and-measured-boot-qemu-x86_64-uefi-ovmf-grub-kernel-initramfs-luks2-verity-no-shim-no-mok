#!/bin/bash
# ---------------------------------------------------------------------------
# build-swupdate-bundle.sh  -  SWUpdate bundle builder for PscgSecureOS
#
# Same LUKS / DMVERITY flag logic as build-rauc-bundle.sh.
# Output: $ARTIFACTS_DIR/bundle.<DATE>.swu  (symlinked as bundle.swu)
#
# Produces a bundle with explicit slotA and slotB stanzas.
# Slot selection at install time is handled by swupdate-install.sh on
# the target - not by anything inside the bundle.
#
# Install on target:
#   swupdate-install.sh bundle.swu
#
# SWUpdate bundle = cpio archive with this mandatory ordering:
#   1. sw-description          (MUST be first)
#   2. sw-description.sig      (MUST be second)
#   3. <images and scripts>    (any order - but if you use network streaming you may want to be more careful about it)
#
#   Note: Can use cpio -H crc instead of newc - and have swupdate enjoy
#   the checksumming capabilities, but it doesn't matter as it is better to 
#   verify each image anyhow
# ---------------------------------------------------------------------------

LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
. $LOCAL_DIR/../../common.sh || { echo "Please run the script from the right place" ; exit 1 ; }
cd $LOCAL_DIR

# ---------------------------------------------------------------------------
# Signing - uses same key/cert material as RAUC, just different format.
# RAUC uses its own CMS wrapper; SWUpdate uses raw openssl cms DER output.
# ---------------------------------------------------------------------------
sign_sw_description() {
	local DIR="$1"
	echo "[+] Signing sw-description (CMS/PKCS#7)"
	openssl cms -sign \
		-in      "$DIR/sw-description" \
		-out     "$DIR/sw-description.sig" \
		-signer  "$SWUPDATE_CERT" \
		-inkey   "$SWUPDATE_KEY" \
		-outform DER \
		-nodetach \
		-binary
	[ $? -ne 0 ] && { echo "[-] Signing failed" ; exit 1 ; }
}

# ---------------------------------------------------------------------------
# cpio bundle - sw-description and its sig MUST be first two entries
# ---------------------------------------------------------------------------
build_cpio_bundle() {
	local DIR="$1"
	local OUT="$2"
	echo "[+] Building cpio bundle: $OUT"
	(
	cd "$DIR"
	# Explicit ordering: sw-description first, sig second, rest after
	{ echo "sw-description" ; echo "sw-description.sig" ; \
		ls *.sh 2>/dev/null ; \
		ls *.img 2>/dev/null | grep -v '^sw-description' ; } \
		| cpio -o -H newc --quiet > "$OUT"
	)
	[ $? -ne 0 ] && { echo "[-] cpio failed" ; exit 1 ; }
}

# ---------------------------------------------------------------------------
# Common bundle assembly after variant-specific setup
# ---------------------------------------------------------------------------
assemble_bundle() {
	local BUNDLE_DIR="$1"
	local HOOKS_DIR="$LOCAL_DIR/hooks"

	cp "$HOOKS_DIR/post-install-hook.sh" "$BUNDLE_DIR/"
	chmod +x "$BUNDLE_DIR"/*.sh

	sign_sw_description "$BUNDLE_DIR"

	DATE=$(date "+%y%m%d-%H%M")
	BUNDLE_OUT="$ARTIFACTS_DIR/bundle.${DATE}.swu"
	build_cpio_bundle "$BUNDLE_DIR" "$BUNDLE_OUT"

	rm -f  "$ARTIFACTS_DIR/bundle.swu"
	ln -sf "$BUNDLE_OUT" "$ARTIFACTS_DIR/bundle.swu"
	echo "[+] Bundle ready: $BUNDLE_OUT"
	echo "[+] Install on target with: swupdate-install.sh $BUNDLE_OUT"
}

# ---------------------------------------------------------------------------
# Variant: LUKS2 + dm-verity
# ---------------------------------------------------------------------------
create_swupdate_bundle_luks_dmverity() {
	echo "[+] Variant: LUKS + DMVERITY"
	: ${SWUPDATE_KEYS_DIR=~/pscg/customers/build-stuff/rauc/keys/}
	: ${SWUPDATE_KEY=$SWUPDATE_KEYS_DIR/development-1.key.pem}
	: ${SWUPDATE_CERT=$SWUPDATE_KEYS_DIR/development-1.cert.pem}

	local BUNDLE_DIR="$ARTIFACTS_DIR/swupdate"
	local HOOKS_DIR="$LOCAL_DIR/hooks"
	rm -rf "$BUNDLE_DIR" && mkdir -p "$BUNDLE_DIR"

	for f in rootfs.enc.img dmverity-hash.img bootfs.img ; do
		ln "$ARTIFACTS_DIR/$f" "$BUNDLE_DIR/$f"
	done

	ROOTFS_SHA256=$(sha256sum   "$BUNDLE_DIR/rootfs.enc.img"       | awk '{print $1}')
	VERITY_SHA256=$(sha256sum   "$BUNDLE_DIR/dmverity-hash.img"    | awk '{print $1}')
	BOOTFS_SHA256=$(sha256sum   "$BUNDLE_DIR/bootfs.img"           | awk '{print $1}')
	POSTHOOK_SHA256=$(sha256sum "$HOOKS_DIR/post-install-hook.sh"  | awk '{print $1}')

	cat <<EOF > "$BUNDLE_DIR/sw-description"
software:
{
	version = "1.0-build-$(date +%s)";
	hardware-compatibility: ["1.0"];
	stable:
	{
		slotA:
		{
			images: (
				{ filename = "rootfs.enc.img";    type = "raw"; device = "/dev/disk/by-partlabel/ROOTFS_A";        sha256 = "$ROOTFS_SHA256"; },
				{ filename = "dmverity-hash.img"; type = "raw"; device = "/dev/disk/by-partlabel/DMVERITY_HASH_A"; sha256 = "$VERITY_SHA256"; },
				{ filename = "bootfs.img";        type = "raw"; device = "/dev/disk/by-partlabel/BOOT_A";          sha256 = "$BOOTFS_SHA256"; }
			);
			scripts: (
				{ filename = "post-install-hook.sh"; type = "postinstall"; sha256 = "$POSTHOOK_SHA256"; }
			);
		};
		slotB:
		{
			images: (
				{ filename = "rootfs.enc.img";    type = "raw"; device = "/dev/disk/by-partlabel/ROOTFS_B";        sha256 = "$ROOTFS_SHA256"; },
				{ filename = "dmverity-hash.img"; type = "raw"; device = "/dev/disk/by-partlabel/DMVERITY_HASH_B"; sha256 = "$VERITY_SHA256"; },
				{ filename = "bootfs.img";        type = "raw"; device = "/dev/disk/by-partlabel/BOOT_B";          sha256 = "$BOOTFS_SHA256"; }
			);
			scripts: (
				{ filename = "post-install-hook.sh"; type = "postinstall"; sha256 = "$POSTHOOK_SHA256"; }
			);
		};
	};
}
EOF
	assemble_bundle "$BUNDLE_DIR"
}

# ---------------------------------------------------------------------------
# Variant: no LUKS, no dm-verity
# Slot selection is done by swupdate-install.sh on the target before invoking
# swupdate with -e "stable,slotA" or -e "stable,slotB". The sw-description
# has explicit stanzas per slot with hardcoded partition devices - no symlinks,
# no preinstall script, no ordering issues.
#
# Training note:
# When installed-directly=true, preinstall hooks will not necessarily be called
# prior to streaming (even if not from the network!) the updated images into their target device.
# In our particular case, the pre-install script is used to setup some links, in a way that swupdate itself will not need to work
# too hard or know too much, and so we will run the script either as a udev hook or as a systemd one. We could alternatively provide multiple stanzas per slot
# ---------------------------------------------------------------------------
create_swupdate_bundle_no_luks_no_dmverity() {
	echo "[+] Variant: plain (no LUKS, no DMVERITY)"
	: ${SWUPDATE_KEYS_DIR=~/pscg/customers/build-stuff/rauc/keys/}
	: ${SWUPDATE_KEY=$SWUPDATE_KEYS_DIR/development-1.key.pem}
	: ${SWUPDATE_CERT=$SWUPDATE_KEYS_DIR/development-1.cert.pem}

	local BUNDLE_DIR="$ARTIFACTS_DIR/swupdate"
	local HOOKS_DIR="$LOCAL_DIR/hooks"

	rm -rf "$BUNDLE_DIR" && mkdir -p "$BUNDLE_DIR"

	for f in rootfs.img bootfs.img ; do
		ln "$ARTIFACTS_DIR/$f" "$BUNDLE_DIR/$f"
	done

	ROOTFS_SHA256=$(sha256sum   "$BUNDLE_DIR/rootfs.img"           | awk '{print $1}')
	BOOTFS_SHA256=$(sha256sum   "$BUNDLE_DIR/bootfs.img"           | awk '{print $1}')
	POSTHOOK_SHA256=$(sha256sum "$HOOKS_DIR/post-install-hook.sh"  | awk '{print $1}')

	cat <<EOF > "$BUNDLE_DIR/sw-description"
software:
{
	version = "1.0-build-$(date +%s)";
	hardware-compatibility: ["1.0"];
	stable:
	{
		slotA:
		{
			images: (
				{ filename = "rootfs.img"; type = "raw"; device = "/dev/disk/by-partlabel/ROOTFS_A"; sha256 = "$ROOTFS_SHA256"; },
				{ filename = "bootfs.img"; type = "raw"; device = "/dev/disk/by-partlabel/BOOT_A";   sha256 = "$BOOTFS_SHA256"; }
			);
			scripts: (
				{ filename = "post-install-hook.sh"; type = "postinstall"; sha256 = "$POSTHOOK_SHA256"; }
			);
		};
		slotB:
		{
			images: (
				{ filename = "rootfs.img"; type = "raw"; device = "/dev/disk/by-partlabel/ROOTFS_B"; sha256 = "$ROOTFS_SHA256"; },
				{ filename = "bootfs.img"; type = "raw"; device = "/dev/disk/by-partlabel/BOOT_B";   sha256 = "$BOOTFS_SHA256"; }
			);
			scripts: (
				{ filename = "post-install-hook.sh"; type = "postinstall"; sha256 = "$POSTHOOK_SHA256"; }
			);
		};
	};
}
EOF
	assemble_bundle "$BUNDLE_DIR"
}

# ---------------------------------------------------------------------------
# Dispatcher - same flag logic as build-rauc-bundle.sh
# ---------------------------------------------------------------------------
main() {
	[ ! -d "$ROOTFS_FS_FOLDER" ] && { echo "Rootfs does not exist" ; exit 1 ; }

	if   [ "$LUKS" = "false" ] && [ "$DMVERITY" = "false" ] ; then
		create_swupdate_bundle_no_luks_no_dmverity
	elif [ "$LUKS" = "true"  ] && [ "$DMVERITY" = "true"  ] ; then
		create_swupdate_bundle_luks_dmverity
	else
		echo "Unsupported: LUKS=$LUKS DMVERITY=$DMVERITY" ; exit 1
	fi
}

main "$@"
