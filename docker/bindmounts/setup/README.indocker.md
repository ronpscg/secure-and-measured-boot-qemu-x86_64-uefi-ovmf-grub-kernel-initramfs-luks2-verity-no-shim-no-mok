# Setup scripts inside the Docker, without modifying too many things in the existing scripts
First setup 
```
/setup/build.sh -c -k
```

First build
```
/setup/build.sh -b
```

Repackaging
```
/setup/build.sh -p
```

One could on the very first time do everything together:
```
/setup/build.sh -c -k -b -p
```
The setup external script does not exist on every error and I don't intend to fix it right now, it was meant to be a helper script.


## Currently not working:
1. initramfs - there is a problem bind mounting. one could override it with a volume. 
