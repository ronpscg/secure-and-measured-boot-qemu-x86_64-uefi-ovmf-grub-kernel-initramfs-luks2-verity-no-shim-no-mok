#!/bin/bash

. ../common.sh || { echo "Please run the script from the right place" ; exit 1 ; }

set -euo pipefail

mkdir -p $ARTIFACTS_DIR/keys
cd $ARTIFACTS_DIR/keys

echo "[+] Generating keys"

# Generate PK
openssl req -new -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -subj "/O=The PSCG/CN=UEFI Platform Key/" \
    -keyout PK.key -out PK.crt

# Generate KEK
openssl req -new -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -subj "/O=The PSCG/CN=UEFI KEK/" \
    -keyout KEK.key -out KEK.crt

# Generate db
openssl req -new -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -subj "/O=The PSCG/CN=UEFI DB Key/" \
    -keyout db.key -out db.crt

echo "[+] Converting output to DER to kep EDK2 happy"
# Convert to DER
openssl x509 -in PK.crt -outform DER -out PK.cer
openssl x509 -in KEK.crt -outform DER -out KEK.cer
openssl x509 -in db.crt -outform DER -out db.cer


# The tools below require the efitools package

echo "[+] Creating EFI signature lists"
cert-to-efi-sig-list -g "$(uuidgen)" PK.crt PK.esl
cert-to-efi-sig-list -g "$(uuidgen)" KEK.crt KEK.esl
cert-to-efi-sig-list -g "$(uuidgen)" db.crt db.esl

echo "[+] Signing the keys"
sign-efi-sig-list -k PK.key -c PK.crt PK PK.esl PK.auth
sign-efi-sig-list -k PK.key -c PK.crt KEK KEK.esl KEK.auth
sign-efi-sig-list -k KEK.key -c KEK.crt db db.esl db.auth

cd ..


echo "[+] Copying keys onto the ESP partition at $ESP_FS_FOLDER/keys/"
echo "You may definitely want to put them somewhere else and perhaps I will do that at another time. one could also delete the keys after enrolling..."
mkdir -p $ESP_FS_FOLDER/keys
# Copy keys to fs for enrollment
cp keys/*.auth $ESP_FS_FOLDER/keys
# EDK2 may complain on EDR's and not accept auth - it will do the ESL by itself, if y ou provide the .cer files from the previous step. Let it have them:
cp keys/*.cer $ESP_FS_FOLDER/keys

