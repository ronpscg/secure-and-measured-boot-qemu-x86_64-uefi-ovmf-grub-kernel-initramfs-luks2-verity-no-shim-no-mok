### Overview
This is a development oriented workflow. For starting from scratch, one can just do everything in an order I wlil specify, but I did not automate all the UUID's etc.
The changes are trivial for anyone who wants to modify, but it's an example project, and my priorities lie elsewhere, so it can wait.

It is recommended that you start with generating the keys.
The reason is that the first time when we build GRUB we already build a standalone version even without a config, and that we may want to include some more signatures in the kernel database (or any other ones).
So having the keys before building is useful.
Without SHIM GRUB will require you to sign (with its keys) the kernel and initramfs.


Then - the rootfs  (in our project - yes - if you want to add kernel modules you may want to do several passes, but that's for the PscgDebOS, or for Yocto Project et. al, not for this example)

Then - make-images.sh because it builds quickly for very quick changes

Then - make the combined image - make a disk with GPT partitions

### What to run where (I'll make a docker for that later, this way I will also present more clearly the host depednencies (other than qemu-system-x86_64)

To build the system, you would like to follow the contents of the next section, in the order they are listed.


#### Key setup -  do these steps once
First, make sure you understand the contents of `scripts/main/setup-grub-PKI.sh`. You need to have GPG (or PGP) keys, and make sure you can use them. Then you will need to make some changes `common.sh`, in particular, 
you will need to modify `GRUB_GPG_KEY`. You may also choose to modify `GRUB_PGP_EMAIL` there, but there is no reason in this example to change it.
Before running the script, it is recommended to test your key generation. You would want to maybe do something like creating an empty file and making sure you can sign it, (e.g `$  gpg --yes --local-user grubexample@thepscg.com --detach-sign <yourtestfilename>`). In this example,  `GRUB_PGP_EMAIL=grubexample@thepscg.com`. If that works, you can run the script, which will export the public key to the *$ARTIFACTS_DIR* directory.

```
( 
cd scripts/main
./setup-grub-PKI.sh 
)
```

To generate the needed UEFI Firmware keys, and store them in the *$BOOT_UEFI_KEYS_FOLDER* folder you may run
```
(
cd scripts/main
./setup-secure-boot-PKI.sh
)
```
The resulted keys in *$BOOT_UEFI_KEYS_FOLDER* will be what you would enroll to your Firmware setup menu (or to whatever automation you would like to apply for setting them up)


#### Building all components from source code - most likely you would like to do this only once
**You would also want to do these once - if you find the need to change some things it is assumed you know what you are doing and don't need instructions**:
```
scripts/external-projects/setup-or-build.sh all
```


#### Building your images
**You would want to run this in this order, for creating the images**
```
(
cd scripts/main
make-images-rootfs.sh
make-images.sh
make-combined-gpt-disk-image.sh
)
```

### Testing your images with QEMU
You can look at and run at the `scripts/qemu/` directory
```
test-tmp.sh 
```

In terms it runs the almost identical (I'll change it later maybe with some parameter)  `tpm-run-qemu.sh` or  `tpm-run-qemu-disk.sh` (one attaches several drives to QEMU, one uses the combined disk image)


### Enrolling keys and achieving automatic unlocking on first boot in QEMU 
For secure boot - you can't be wrong about it too much, go to firmware setup and enroll the keys. I'll cover it later perhaps.
For the TPM stuff: First - the *tpm-state* directory is important. If you use a new one - you, naturally, lose the keys as you lose its steps.

On your first boot you will have a prompt like
```
Please enter passphrase for disk ROOTFS (dmcryptdevice-luks): (press TAB for no echo) 
```
Enter your password (it was done in the image building scripts, where luks is concerened, see *scripts/main/make-images-rootfs.sh*) to unlock the device.
Then, login and enter your credentials. If things look slow to you - it is because the rootfs is readonly and systemd wants to write things for the login related daemons. This can be modified in teh rootfs preparation (and then you can repack the rootfs, and don't forget to follow the instructions in the output, as you would need to modify your GRUB config).


Now, when you are on the root filesystem you can do:
```
LUKS_UUID=<the UUID of your LUKS partition>
systemd-cryptenroll --tpm-device=auto /dev/disk/by-uuid/${LUKS_UUID}
```

This will achieve the requested enrollment for your next boots, and will enroll *PCR #7* which is the secure boot state et. al.
You can consult the `systemd-cryptenroll` documentation, and the TCG (Trusted Computing Group) standards to decide what are the PCR's you would like to measure and seal in the TPM for your measured boot scenarios.
