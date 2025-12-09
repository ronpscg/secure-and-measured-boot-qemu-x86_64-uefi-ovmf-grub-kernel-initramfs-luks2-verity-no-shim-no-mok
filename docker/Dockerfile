FROM ubuntu:25.10

# Enable adding another user
ARG USERNAME=user
ARG USER_UID=1000
ARG USER_GID=1000
ARG HOST_DOCKER_ID

RUN apt-get update
# Linux kernel standard stuff
RUN apt-get install -y build-essential git vim nasm iasl efitools autoconf autoconf-archive autopoint  bison flex libelf-dev libssl-dev  bc 
RUN apt-get install -y sudo debootstrap
# Native initramfs generation (without using Docker inside Docker)
RUN apt-get install -y dracut tpm2-tools
# EDK2/OVMF
RUN apt-get install -y uuid-runtime uuid-dev nasm iasl efitools 
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

# Run the entry point as it is useful and may prevent some known docker issues (loopbacks et. al). Can't use variables, but it's fine because we have the WORKDIR that handles it
ENTRYPOINT  ["./entry.sh"]
# You can replace moving to shell with your other command if you wish. The entry point will take care of exec-ing it
CMD  ["/bin/bash"]
