# Testing procedures for RAUC

The idea:
- Mark the update by updating the update-motd.d/11-... information so it's easy to track updates when testing
- [Remove the repacked images to avoid prompts]
- Package the image - also including the new rauc file in the data partition **BUT CAREFUL**
- 

So testing can be done as follows (no need to specify ROOTFS_SIZE_MIB, or the other parameters anymore)
```
~/secboot-ovmf-x86_64/scripts/external-projects/setup-or-build.sh rootfs add_more_customizations
rm ~/pscg/secureboot-qemu-x86_64-efi-grub/artifacts/*.img
ROOTFS_SIZE_MIB=1000 DONT_RECREATE_ROOTFS=false DONT_RECREATE_DATAFS=false DONT_RECREATE_BOOTFS=false CREATE_DUAL_BOOT_AND_ROOTFS_PARTITIONS=true PUT_BOOT_MATERIALS_IN_ESP_FS=false /setup/build.sh -p -q
```

# Current status and Notes
- Note that this is the **plain** format of RAUC. One could do **verity**/**crypt** (for the bundle itself!). Maybe in a later iteration

- This all works well, automatically decrypt things after installation, and one would need to add some mark-good etc. notes (and also understand why after installation it says it's good and after reboot no - but maybe it's by their design.

- NOTE: I think everything works UNLESS THE TWO SLOTS ARE IDENTICAL / same UUID - and in this case we would likely need to use specific devices and not partlabel or UUID's - and that is actually systemd's "fault"

