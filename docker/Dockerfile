# Important note: Python/Bitbake/who knows what arre most likely BROKEN on 25.10
# Tested successfully on ubuntu:24.04, ubuntu,25.04

# If anyone needs BASE after the FROM parts - they will need to redeclare BASE. In this Dockerfile there is no need for that
ARG BASE=ubuntu:22.04
FROM ${BASE} AS base-builder

ENV DEBIAN_FRONTEND=noninteractive

# Enable adding another user
ARG USERNAME=user
ARG USER_UID=1000
ARG USER_GID=1000
ARG HOST_DOCKER_ID

RUN apt-get update

# Linux kernel standard stuff (nasm/iasl are not needed for the kernel. efitools - depends, usually you don't need them either. EDK2/OVMF requires all of them)
# libncurses is for make menuconfig
RUN apt-get install -y build-essential nasm iasl efitools bison flex libelf-dev libssl-dev  bc libncurses-dev
# General things that are useful
RUN apt-get install -y git vim bash-completion  tmux
# Debootstrap and rootfs tools (if you want to avoid superuser for debootstrapping you can use fakeroot or pseudo)
RUN apt-get install -y sudo debootstrap
# Native initramfs generation (without using Docker inside Docker)
RUN apt-get install -y dracut tpm2-tools
# EDK2/OVMF
RUN apt-get install -y uuid-runtime uuid-dev nasm iasl efitools 

# EDK2/OVMF - conditionally install virt-firmware according to OS release, as Ubuntu provides the package only beginning with version 24.04, and building some Yocto versions requires 22.04, and it's a small change.
RUN if [ $(lsb_release -rs) = 22.04 ] ; then sudo apt-get install -y python3-pip && pip3 install virt-firmware ; else apt-get install -y  python3-virt-firmware ; fi
# Keep GRUB bootstrap and make (gawk) happy
RUN apt-get install -y gettext libtool pkg-config autoconf autoconf-archive autopoint gawk
# This step is for seamless integration with the current scripts, and running it within docker in docker. Do be careful of the chmod of the artifacts, all might need to be considered
# Could change the building of the initramfs to be in the same docker instead (but it was mostly tested with Fedora)
RUN apt-get install -y docker.io
# Running OVMF with TPM
RUN apt-get install -y swtpm qemu-system-x86
# Rootfs encrpytion
RUN sudo apt-get install -y tpm2-tools cryptsetup
# Image packaging (kpartx to avoid having udev inside Docker)
RUN apt-get install -y parted dosfstools kpartx 

# Remove default ubuntu user/group if they exist
RUN if getent passwd ubuntu >/dev/null; then \
	echo "Removing existing ubuntu user"; \
	userdel -r ubuntu || true; \
	fi && \
	if getent group ubuntu >/dev/null; then \
	echo "Removing existing ubuntu group"; \
	groupdel ubuntu || true; \
	fi

# Create group and user mapped to the host UID/GID
RUN groupadd --gid ${USER_GID} ${USERNAME} && \
	useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME}

# Add user to sudoers with NOPASSWD
RUN echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99_${USERNAME} && \
	chmod 440 /etc/sudoers.d/99_${USERNAME}

# Add the user to the docker group (to allow communicating with the host daemon, which is terrible for security, but who cares ;-)
RUN usermod -aG docker ${USERNAME}
RUN usermod -aG kvm ${USERNAME}

# Switch to the user by default
USER ${USERNAME}
WORKDIR /home/${USERNAME}

#------------------------------------------------------------------------
# Start the second stage for Yocto, inheriting from "base-builder"
#------------------------------------------------------------------------
FROM base-builder AS yocto

# Running with sudo instead of modifying the user back and forth. It's fine
RUN sudo apt-get install -y kas
RUN sudo apt-get install -y locales chrpath diffstat lz4 && sudo locale-gen "en_US.UTF-8"

# Make kas shell a bit better looking
RUN sudo bash -c "rm /bin/sh && ln -s /bin/bash /bin/sh"

# Run the entry point as it is useful and may prevent some known docker issues (loopbacks et. al). Can't use variables, but it's fine because we have the WORKDIR that handles it
ENTRYPOINT  ["./entry.sh"]
# You can replace moving to shell with your other command if you wish. The entry point will take care of exec-ing it
CMD  ["/bin/bash"]
