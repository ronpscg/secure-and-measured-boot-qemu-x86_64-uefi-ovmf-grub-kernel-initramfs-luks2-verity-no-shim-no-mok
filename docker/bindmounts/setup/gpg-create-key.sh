#!/bin/bash

: ${GRUB_PGP_EMAIL="grubexample@thepscg.com"}
: ${COMMON_CONFIG_FILE="/tmp/local.config"}  # This is expected to be set from outside
GRUB_GPG_KEY_ID=""  # If a key was already provided, and it is correct, it will be filled with the same value, so don't worry about this setting. Otherwise - there is no key and the script would fail

CONFIG_FILE=$COMMON_CONFIG_FILE # the name should probably be changed from COMMON_CONFIG_FILE to LOCAL_CONFIG_FILE but I can't change the other scripts now


# Check for an existing secret key and extract its long ID (16 characters)
GRUB_GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format=long "$GRUB_PGP_EMAIL" 2>/dev/null | grep '^sec' | awk -F'/' '{print $2}' | awk '{print $1}')

if [ -z "$GRUB_GPG_KEY_ID" ]; then
    # No key found, proceed with generation
    cat > batch-gen-key <<EOF
%no-protection
Key-Type: RSA
Key-Length: 3072
Subkey-Type: RSA
Subkey-Length: 3072
Name-Real: PSCG Example
Name-Comment: Automated Key for Script
Name-Email: $GRUB_PGP_EMAIL
Expire-Date: 0
%commit
EOF

set -euo pipefail
    # Generate the key
    gpg --batch --full-generate-key batch-gen-key 2>/dev/null

    # Extract the ID from the newly generated key
    GRUB_GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format=long "$GRUB_PGP_EMAIL" 2>/dev/null | grep '^sec' | awk -F'/' '{print $2}' | awk '{print $1}')

    rm batch-gen-key
else
    # Key already exists
    echo "Key for $GRUB_PGP_EMAIL already exists. Using existing ID $GRUB_PGP_KEY_ID."
    echo "If you want to clear up this key use the gpg tools. For example, if you would like to clean all keys, you can run 
    gpg --delete-secret-keys \"*\"
    gpg --delete-keys \"*\"
    "

fi

set -euo pipefail # in case the else block is taken

# Populate the configuration file. Not overriding the file in purpose, in case it exists. It is assumed that this script is run only on first setup though, so it should not exist probably
echo "# Keys autopopulated by $0 on $(date)" >> $CONFIG_FILE
echo "GRUB_PGP_EMAIL=$GRUB_PGP_EMAIL" >> $CONFIG_FILE
echo "GRUB_GPG_KEY_ID=$GRUB_GPG_KEY_ID" >> $CONFIG_FILE

echo "Done populating $COMMON_CONFIG_FILE"
