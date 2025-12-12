# dockers

There are separate docker images to enable setting up a Yocto Project less workflow without introducing dependencies.
Then, if Yocto Project is needed, only the differences are introduced, which is nice.

Yes, I could do multistage. No I won't do this, at least not for now.
## First setup 
```
./build-docker.sh
./build-yocto-docker.sh
```

## Running (you can use the same command regardless of docker or not)
```
BINDMOUNTS=~/pscg/bindmounts ./run-yocto-docker.sh
```
Then, follow the instructions on the screen, or do what you know you need to do. :-)


### Building and packaging non-yocto builds:
```
BINDMOUNTS=~/pscg/bindmounts ./run-yocto-docker.sh /setup/build.sh -k -c -b -p
```

You can then run the result with 
```
/setup/build.sh -q
```

But be mindful of the kernel command line if you are running inside docker - you would not want `console=tty0` to be the last console, as systemd would use it for input and output and the system might seem to be stuck while it is waiting for your password for TPM enrollment - while it is not actually stuck.

### Building and packaging Yocto Project builds:
```
BINDMOUNTS=~/pscg/bindmounts ./run-yocto-docker.sh /setup/build.sh -k -c -y
```

You can test the results then, on the first time you run (enrolls the certificates) using:
```
BINDMOUNTS=~/pscg/bindmounts ./run-yocto-docker.sh /setup/build.sh -r
```

On subsequent times, to reuse the configuration an enrollments, you can run the result inside the docker (or by providing -e for providing the environment variables before running docker)
```
GENERATE_TEST_LOCAL_CONFIG=false ENROLL_CRYPTO_MATERIALS_IN_UEFI_VARSTORE=false /setup/build.sh -r
```

In general, go in docker to 
~/example-test-secboot-qemu/

And follow the scripts there (read the git log descriptions which are fairly accurate, and the README.md there for more information).
The scripts there are super simple and easy, and I think they will be incorporated into this repository - I just don't really want to use submodules...

