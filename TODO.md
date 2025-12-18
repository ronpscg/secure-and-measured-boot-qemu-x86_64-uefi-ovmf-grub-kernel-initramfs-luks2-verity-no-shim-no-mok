- Probably separating some things from common.sh
- Moving all the mkfs.ext4 dependent files (rootfs, bootfs) to use the common function in the newly introduced datafs creation function (done) and moving the files to make main less dense (will not do now)
- GRUB key creation - there is full automation (no need for user interaction) in the docker/... folder.  **In general, basically merge setup completely probably, and get it out of the bindmounts/modify how things are.**
- Maybe exporting etc.
- It would be nicer to cleanup and have folders inside GRUB
- Update README.md and maybe STEPS.md (which is the more accurate README but they have not been updated, I think since the docker readmes, and I don't think I plan to update them either"


I will not do a dedicated installer and recovery, at least not now. But it's very easily doable.


# A/B
Systemd can boot either way and so can the initramfs when there are two partitions with the same UUID

# KERNEL

## BASE DOCKER IMAGE
add to docker libncurses-dev  - for make menuconfig

# RAUC
service won't start with the commented out line
[slot.rootfs.0]
#device=/dev/disk/by-partlabel/ROOTFS_A
device=/dev/dm-1
type=raw


## FOR RAUC: SQUASHFS in kernel

 SQUASHFS n -> y
+SQUASHFS_4K_DEVBLK_SIZE n
+SQUASHFS_CHOICE_DECOMP_BY_MOUNT n
+SQUASHFS_COMPILE_DECOMP_MULTI n
+SQUASHFS_COMPILE_DECOMP_MULTI_PERCPU n
+SQUASHFS_COMPILE_DECOMP_SINGLE y
+SQUASHFS_COMP_CACHE_FULL n
+SQUASHFS_DECOMP_SINGLE y
+SQUASHFS_EMBEDDED n
+SQUASHFS_FILE_CACHE y
+SQUASHFS_FILE_DIRECT n
+SQUASHFS_FRAGMENT_CACHE_SIZE 3
+SQUASHFS_LZ4 n
+SQUASHFS_LZO n
+SQUASHFS_XATTR n
+SQUASHFS_XZ n
+SQUASHFS_ZLIB y
+SQUASHFS_ZSTD n
