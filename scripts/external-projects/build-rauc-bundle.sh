#!/bin/bash


LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
. $LOCAL_DIR/../common.sh || { echo "Please run the script from the right place" ; exit 1 ; }
cd $LOCAL_DIR



create_rauc_bundle_luks_dmverity() {
	echo "[+] Creating the RAUC bundle materials"
	: ${RAUC_KEYS_DIR=~/pscg/customers/build-stuff/rauc/keys/}
	: ${RAUC_KEY=$RAUC_KEYS_DIR/development-1.key.pem}
	: ${RAUC_CERT=$RAUC_KEYS_DIR/development-1.cert.pem}

	mkdir $ARTIFACTS_DIR/rauc
	# hard link to save space
	for f in rootfs.enc.img dmverity-hash.img bootfs.img ; do
		sf=$ARTIFACTS_DIR/$f
		tf=$ARTIFACTS_DIR/rauc/$f
		[ -f $tf ] && unlink $tf
		ln $sf $tf
	done
	cat <<EOF > $ARTIFACTS_DIR/rauc/manifest.raucm
[update]
compatible=PscgSecureOS
version=1.0-build-$(date +%s)
description=Full System Update

[image.rootfs]
filename=rootfs.enc.img

[image.verity_hash]
filename=dmverity-hash.img

[image.boot]
filename=bootfs.img
EOF

	echo "[+] Bundling the RAUC bundle"
	DATE=$(date "+%y%m%d-%H%M")
	rauc bundle --cert="$RAUC_CERT" --key="$RAUC_KEY" $ARTIFACTS_DIR/rauc $ARTIFACTS_DIR/bundle.${DATE}.raucb
	rm -rf $ARTIFACTS_DIR/bundle.raucb
	ln -s $ARTIFACTS_DIR/bundle.${DATE}.raucb $ARTIFACTS_DIR/bundle.raucb
}

create_rauc_bundle_no_luks_no_dmverity() {
	echo "[+] Creating the RAUC bundle materials (no LUKS, no DMVERITY)"
	: ${RAUC_KEYS_DIR=~/pscg/customers/build-stuff/rauc/keys/}
	: ${RAUC_KEY=$RAUC_KEYS_DIR/development-1.key.pem}
	: ${RAUC_CERT=$RAUC_KEYS_DIR/development-1.cert.pem}

	mkdir $ARTIFACTS_DIR/rauc
	# hard link to save space
	for f in rootfs.img  bootfs.img ; do
		sf=$ARTIFACTS_DIR/$f
		tf=$ARTIFACTS_DIR/rauc/$f
		[ -f $tf ] && unlink $tf
		ln $sf $tf
	done
	cat <<EOF > $ARTIFACTS_DIR/rauc/manifest.raucm
[update]
compatible=PscgSecureOS
version=1.0-build-$(date +%s)
description=Full System Update (no LUKS no DMVERITY)

[image.rootfs]
filename=rootfs.img

[image.boot]
filename=bootfs.img
EOF

	echo "[+] Bundling the RAUC bundle"
	DATE=$(date "+%y%m%d-%H%M")
	rauc bundle --cert="$RAUC_CERT" --key="$RAUC_KEY" $ARTIFACTS_DIR/rauc $ARTIFACTS_DIR/bundle.${DATE}.raucb
	rm -rf $ARTIFACTS_DIR/bundle.raucb
	ln -s $ARTIFACTS_DIR/bundle.${DATE}.raucb $ARTIFACTS_DIR/bundle.raucb
}

create_rauc_bundle() {
	if [ "$LUKS" = "false" -a "$DMVERITY" = false ] ; then
		create_rauc_bundle_no_luks_no_dmverity
	elif [ "$LUKS" = "true" -a "$DMVERITY" = true ] ; then
		create_rauc_bundle_luks_dmverity
	else
		echo "Unsupported LUKS=$LUKS DMVERITY=$DMVERITY"
		exit 1
	fi
}

main() {
	if [ ! -d $ROOTFS_FS_FOLDER ] ; then
		echo "Rootfs does not exist"
		exit 1
	fi
	create_rauc_bundle
}
main $@

