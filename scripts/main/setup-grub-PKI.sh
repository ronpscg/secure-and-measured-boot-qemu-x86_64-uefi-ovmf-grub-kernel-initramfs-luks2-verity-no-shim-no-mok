#!/bin/bash

LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
. $LOCAL_DIR/../common.sh || { echo "Please run the script from the right place" ; exit 1 ; }

echo "Please use your own GPG keys, or create RSA/DSA ones. This script will require you to do some manual steps as creating your key, and exporting it"
echo "If you have a key, replace your key ID with it"

: ${KEYID=$GRUB_GPG_KEY_ID} # replace with your key ID in common.sh

# gpg --full-generate-key # see example output below  - this is where I took the number from, you must use your own
#
gpg --export -o $GRUB_PGP_PUBLIC_KEY $KEYID





exit 0

$ gpg --full-generate-key
gpg (GnuPG) 2.4.4; Copyright (C) 2024 g10 Code GmbH
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Please select what kind of key you want:
   (1) RSA and RSA
   (2) DSA and Elgamal
   (3) DSA (sign only)
   (4) RSA (sign only)
   (9) ECC (sign and encrypt) *default*
  (10) ECC (sign only)
  (14) Existing key from card
Your selection? 1
RSA keys may be between 1024 and 4096 bits long.
What keysize do you want? (3072)
Requested keysize is 3072 bits
Please specify how long the key should be valid.
         0 = key does not expire
      <n>  = key expires in n days
      <n>w = key expires in n weeks
      <n>m = key expires in n months
      <n>y = key expires in n years
Key is valid for? (0)
Key does not expire at all
Is this correct? (y/N) y

GnuPG needs to construct a user ID to identify your key.

Real name: PSCG Example
Email address: grubexample@thepscg.com
Comment:
You selected this USER-ID:
    "PSCG Example <grubexample@thepscg.com>"

Change (N)ame, (C)omment, (E)mail or (O)kay/(Q)uit? o
We need to generate a lot of random bytes. It is a good idea to perform
some other action (type on the keyboard, move the mouse, utilize the
disks) during the prime generation; this gives the random number
generator a better chance to gain enough entropy.
We need to generate a lot of random bytes. It is a good idea to perform
some other action (type on the keyboard, move the mouse, utilize the
disks) during the prime generation; this gives the random number
generator a better chance to gain enough entropy.
gpg: revocation certificate stored as '/home/ron/.gnupg/openpgp-revocs.d/8A79B38F2589CE82C6BE80CB2C3D2B57F2161903.rev'
public and secret key created and signed.

pub   rsa3072 2025-11-27 [SC]
      8A79B38F2589CE82C6BE80CB2C3D2B57F2161903
uid                      PSCG Example <grubexample@thepscg.com>
sub   rsa3072 2025-11-27 [E]




