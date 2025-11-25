Everything in this repo was written using vi. Nothing using AI.
# secure-and-measured-boot-qemu-x86_64-uefi-tpm2-ovmf-grub-kernel-initramfs-dmcrypt-dmverity-rootfs-no-shim-no-mok

The project name explains what it does. In this case - more is more.
(hmm. By the time I wrote this someone changed the man pages of `less` from *"less is more"* to *"less - opposite of more"*. How could they? [imagine tons of angry emojies])

This documentation file, at least for now, is meant to be very minimal.
The scripts explain everything, and if more things or manual steps I needed I will add them, after I have the time to test separately.

There is more work to that that is not to be published probably (either confidential, or I don't have time). 

**NOTE:** Everything is built from scratch or source code, without using a built system.
It was all built and tested on *Ubuntu Plucky (25.04)*, and can be useful for educational purposes.


**NOTE:** If you build the right set of kernel configuration, and possibly (depends where) a microcode in the initramfs (might not be needed at all), you should be able to boot it on any intel computer that can work with UEFI.

**TODO:** For now the builds are to work with QEMU with a different partition. I will also package things in a harddrive image, and then I'll see.

**NOTE:** This is not the level of code you could expect me to deliver, but come on, look what your favorite AI does, then let's talk. It is published as it is useful. Enjoy.

I might give some design considerations explanations later, but not at this point.

## Code organization
None. Eh!
I will organize it later maybe, I just want to push it to share with the almighty FC and CM  (as obvious as it may sound that it is - no, it isn't Football Club and Configuration Management respectfully, eh!)

What has been run and tested repeatedly
- Tons of things from command line, that I will try to put in some scripts later
- dracut from Docker (the other initramfs's are not used, *copybin.sh* was made for them, but dracut just handles systemd in initramfs **so much better** than the Canonical tools, sorry
- All the scripts that start with a number.

## Steps overview:
- Build *QEMU* (I used the distro one because it's simple. In some of *The PSCG* training courses we build QEMU from source because we need all kind of things, or because the courses address QEMU/KVM themselves)
- Build *EDK2* and *OVMF* with secure boot and TPM support (I think there is a pacakge in Ubuntu to have the OVMF secure boot firmware but I did not check it)
- Build a standalone *GRUB2* without the Shim loader (It is absolutely necessary). The standalone has an advantage - you can sign only it, and forget about the rest of the GRUB modules/config etc.
- Build Linux kernel (tested on v6.17-rc2) - .config file is provided
- Get a rootfs of your choice, preferrably supporting systemd, and having some of the TPM related packages. I took a *Debian Trixie* rootfs I built with *PscgBuildOS* (for the rootfs it's debootstrap and some more things. You could debootstrap and do whatever yourself, or put any other rootfs of your choice)
- Get an initramfs to build (Ubuntu update-initramfs et. al are easy to use but not easy with producing the right results for everything verity related. *dracut* is notorious for requiring `--hostonly` even when you absolutely don't want to work on the host.). Since *dracut* is from RedHat, I just built it on a *Fedora Core* docker, and made it happy with whatever it has and that's it. 
- Sign whatever you can/need to (see scripts)
- Enroll certificates in UEFI storage, etc. (you can do it from the Firmware setup menu, and you can do it from the database)

## Why not use SHIM
Basically, most GRUB based flow use SHIM, as it makes things easily installable on "every PC" (Yes, that includes also your laptops, whether they are x86 or arm based). However, the common aggreement is that if Microsoft is compromised, a device that uses SHIM will be compromised as well (although SHIM does not necessary have to be signed by Microsoft, but trust me there is no point in arguing). Not using SHIM, allows a developer to completely decide the chain of trust, with the exception of the hardware manufacturer itself. Therefore, it is an important and useful construct.

## Why not use UKI (Unified Kernel Image)
It's easier to debug initramfs until you are sure what exactly you want to put on it.
Also, this particular project is done as part of much more complex project. I am publishing it as it could be useful for my students, as well as for my colleagues in the project (we do *Yocto Project* there this way or another, but actually this is solid, and useful, and any Linux distro rootfs can be just as production grade.

Using UKI is just fine, I might add it later

# Disclaimers:
May add more documentation, may not.
I usually don't publish such things to not spoil my students efforts to learn (to not help them, or more precisely TO REALLY HELP THEM by making them work hard)
