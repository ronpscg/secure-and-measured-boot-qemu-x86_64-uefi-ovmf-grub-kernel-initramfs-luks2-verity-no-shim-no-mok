# Setup scripts inside the Docker, without modifying too many things in the existing scripts

## First setup 
```
/setup/build.sh -c -k
```

## Building and running
First build
```
/setup/build.sh -b
```

Repackaging
```
/setup/build.sh -p
```

Running an emulator without Yocto artifacts:
```
/setup/build.sh -q
```

Building Yocto (does not require doing `-b` `-p` prior to that)
```
/setup/build.sh -y
```

Running an emulator with artifacts in a well known structure (expecting *YOCTO_BUILD_DIR* but artifacts generated with `-b` `-p` can be put in a folder with the same structure):
Basically the next line - but only after you properly decided what you want to run. The next line automates this:
```
/setup/build.sh -r
```


You can test the results then, on the first time you run (enrolls the certificates) using:
```
BINDMOUNTS=~/pscg/bindmounts ./run-yocto-docker.sh /setup/build.sh -r
```

On subsequent times, to reuse the configuration an enrollments, you can run the result inside the docker (or by providing -e for providing the environment variables before running docker)
```
GENERATE_TEST_LOCAL_CONFIG=false ENROLL_CRYPTO_MATERIALS_IN_UEFI_VARSTORE=false /setup/build.sh -r
```

In general, go in docker to *~/example-test-secboot-qemu/*

And follow the scripts there (read the git log descriptions which are fairly accurate, and the README.md there for more information).
The scripts there are super simple and easy, and I think they will be incorporated into this repository - I just don't really want to use submodules...

They are also useful for non Yocto Project builds (and `-b` `-p` and later `-q` - You can easily automate what you want if you want - it uses an external environment script, and you may want to enroll


One could on the very first time do everything together:
```
/setup/build.sh -c -k -b -p
```
The setup external script does not exit on every error and I don't intend to fix it right now, it was meant to be a helper script.


To build for Yocto one may run:
```
/setup/build.sh -c -k -y
```

