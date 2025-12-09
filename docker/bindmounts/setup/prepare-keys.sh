#!/bin/bash
#
# Setup script, some things here could be moved into the common scripts/main/ but I could not change things
#

echo -e "\e[43m$0 - You need to do it once. For now some manual steps (in gpg key creation) \x1b[0m"

: ${SRC_DIR=~/secboot-ovmf-x86_64}

if [ ! -d $SRC_DIR/scripts/main ] ; then
	echo "Please clone the repo first"
	exit 1
fi


export SRC_DIR
./gpg-create-key.sh
echo "Setting up GPG keys - if you don't have some - create them manually!"
$SRC_DIR/scripts/main/setup-grub-PKI.sh 
if [ "$(gpg --list-keys | wc -l)" = "0" ] ; then
	echo "Please see $SRC_DIR/scripts/main/setup-grup-PKI.sh for more information, apply the steps there, and re-run this  script ($0) again"
	echo "Although the gpg-create-key.sh was supposed to do it for you"
	exit 1
fi


echo "Autogenerating keys..."
$SRC_DIR/scripts/main/setup-secure-boot-PKI.sh




