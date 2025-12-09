#!/bin/bash
: ${USER_NAME=user}
if [ "$USER_NAME" = "root" ] ; then
	: ${HOMEDIR=/root}
else
	: ${HOMEDIR=/home/$USER_NAME}
fi

PRIVILEGED=--privileged # To allow dealing with internal docker mounts and with losetup
docker run -it --rm  $PRIVILEGED -v /var/run/docker.sock:/var/run/docker.sock --group-add $(getent group docker | awk -F: '{print $3}')  --group-add $(getent group kvm | awk -F: '{print $3}') -v ${PWD}/bindmounts/setup:/setup/ -v  ${PWD}/bindmounts/homedir:$HOMEDIR -u $USER_NAME -e USER=$USER_NAME -w ${HOMEDIR}  wip-docker-secboot-builder:latest "$@"
