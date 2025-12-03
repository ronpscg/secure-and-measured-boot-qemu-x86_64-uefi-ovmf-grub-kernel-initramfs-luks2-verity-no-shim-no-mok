#!/bin/sh
# This script is meant to be done on a debootstrapped system, but could be done (depending on what is run...) also as a post install step in Yocto or whatever, 
# if it's just systemd files (as it is in the first version)
# The assuption is that this is being copied to the target, run in chroot, and then deleted
# If it's just enabling systemd services, it could be done from the host with links without chroot

echo "chroot: executing customization scripts"
systemctl enable tpm2-provision-luks.service

echo "chroot: done work"
