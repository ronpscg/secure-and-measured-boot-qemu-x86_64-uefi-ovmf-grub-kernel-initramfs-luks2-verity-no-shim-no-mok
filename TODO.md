dracut in docker first time:
./setup-and-build.sh called with build
In Docker
[+] Building natively.
dracut[I]: Executing: /usr/bin/dracut --force --no-hostonly --no-kernel /home/user/pscg/secureboot-qemu-x86_64-efi-grub/components/dockers/initramfs-builder/workdir/fedora/initrd.img
mkdir: cannot create directory '/var/lib/dracut/console-setup-dir': Permission denied
dracut[I]: 62bluetooth: Could not find any command of '/usr/lib/bluetooth/bluetoothd /usr/libexec/bluetooth/bluetoothd'!
dracut[I]: *** Including module: bash ***
dracut[I]: *** Including module: systemd ***
dracut[I]: *** Including module: systemd-ask-password ***
dracut[I]: *** Including module: systemd-battery-check ***
dracut[I]: *** Including module: systemd-cryptsetup ***
dracut[I]: *** Including module: systemd-initrd ***
dracut[I]: *** Including module: systemd-journald ***
dracut[I]: *** Including module: systemd-modules-load ***
dracut[I]: *** Including module: systemd-pcrphase ***
dracut[I]: *** Including module: systemd-sysctl ***
dracut[I]: *** Including module: systemd-tmpfiles ***
dracut[I]: *** Including module: systemd-udevd ***
dracut[I]: *** Including module: systemd-veritysetup ***
dracut[I]: *** Including module: i18n ***
dracut[I]: *** Including module: plymouth ***
dracut[I]: *** Including module: simple-drm ***
dracut[I]: *** Including module: systemd-sysusers ***
dracut[I]: *** Including module: crypt ***
dracut[I]: *** Including module: dm ***
dracut[I]: *** Including module: kernel-modules ***
dracut[I]: *** Including module: kernel-modules-extra ***
dracut[I]: *** Including module: nvdimm ***
dracut[I]: *** Including module: qemu ***
dracut[I]: *** Including module: fido2 ***
dracut[I]: *** Including module: pkcs11 ***
dracut[I]: *** Including module: tpm2-tss ***
dracut[I]: *** Including module: hwdb ***
dracut[I]: *** Including module: lunmask ***
dracut[I]: *** Including module: resume ***
dracut[I]: *** Including module: rootfs-block ***
dracut[I]: *** Including module: terminfo ***
dracut[I]: *** Including module: udev-rules ***
dracut[I]: *** Including module: virtiofs ***
dracut[I]: *** Including module: dracut-systemd ***
dracut[I]: *** Including module: usrmount ***
dracut[I]: *** Including module: base ***
dracut[I]: *** Including module: fs-lib ***
dracut[I]: *** Including module: shell-interpreter ***
dracut[I]: *** Including module: shutdown ***
dracut[I]: *** Including modules done ***
dracut[I]: *** Resolving executable dependencies ***
dracut[I]: *** Resolving executable dependencies done ***
dracut[I]: *** Hardlinking files ***
dracut[I]: *** Hardlinking files done ***
dracut[I]: *** Generating early-microcode cpio image ***
dracut[I]: *** Store current command line parameters ***
dracut[I]: *** Stripping files ***
dracut[I]: *** Stripping files done ***
dracut[I]: *** Creating image file '/home/user/pscg/secureboot-qemu-x86_64-efi-grub/components/dockers/initramfs-builder/workdir/fedora/initrd.img' ***
dracut[I]: Using auto-determined compression method 'zstd'
cpio: etc/gshadow: Cannot open: Permission denied
cpio: etc/shadow: Cannot open: Permission denied
dracut[F]: Creation of /home/user/pscg/secureboot-qemu-x86_64-efi-grub/components/dockers/initramfs-builder/workdir/fedora/initrd.img failed
./setup-and-build.sh failed to build
[+] Copying artifacts...
cp: cannot stat '/home/user/pscg/secureboot-qemu-x86_64-efi-grub/components/dockers/initramfs-builder/workdir/fedora/initrd.img': No such file or directory




Maybe there are other things as well I don't know
