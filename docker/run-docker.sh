#!/bin/bash
LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
: ${USER_NAME=user}
if [ "$USER_NAME" = "root" ] ; then
	: ${HOMEDIR=/root}
else
	: ${HOMEDIR=/home/$USER_NAME}
fi

: ${BINDMOUNTS=$LOCAL_DIR/bindmounts}
: ${COPYGPGKEYS_ON_NEW_BINDMOUNTS_DIR=false} # if true, and there is a copy from a currently running dir in this repo (could do also outside but won't do so), also copy the keys from it

#-----------------------------------------
# Checks and initial setup help the user set up a directory so the current (git version controlled) working directory won't be bloated with the docker mounts  but don't interfere too much
#-----------------------------------------
if [ ! -d "$BINDMOUNTS" ] ; then
	echo "Helping you to setup the $BINDMOUNTS directory, from the contents of source controlled $LOCAL_DIR"
	mkdir -p $BINDMOUNTS || { echo "Cannot create directory $BINDMOUNTS" ; exit 1 ; }
	set -euo pipefail
	mkdir $BINDMOUNTS/{setup,homedir}
	cp -va $LOCAL_DIR/bindmounts/setup/* $BINDMOUNTS/setup/
	cp $LOCAL_DIR/bindmounts/homedir/entry.sh $BINDMOUNTS/homedir/
	set +euo pipefail
	# Won't copy the rest of the contens of the homedir as it could be huge, if it has gone previous builds
	# But will be nice enough to keep previous customizations, and history, if the user had such
	# don't worry about the warnings of not copying directories, if there are, as it is intentional
	cp -v $LOCAL_DIR/bindmounts/homedir/.* $BINDMOUNTS/homedir/

	if [ "$COPYGPGKEYS_ON_NEW_BINDMOUNTS_DIR" = "true" ] ; then
		if [ -d $LOCAL_DIR/bindmounts/homedir/.gnupg ] ; then
			cp -av $LOCAL_DIR/bindmounts/homedir/.gnupg $BINDMOUNTS/homedir/
		fi
	fi
fi
if [ ! -f "$BINDMOUNTS/homedir/entry.sh" ] ; then
	echo "Please make sure you have set $BINDMOUNTS/homedir correctly. If you are using the folder from inside the repo at $LOCAL_DIR, you may want to reset your repo"
	exit 1
fi


#-----------------------------------------
# Running docker
#-----------------------------------------
PRIVILEGED=--privileged # To allow dealing with internal docker mounts and with losetup
docker run -it --rm  $PRIVILEGED -v /var/run/docker.sock:/var/run/docker.sock \
	--group-add $(getent group docker | awk -F: '{print $3}')  \
	--group-add $(getent group kvm | awk -F: '{print $3}') \
	-v ${BINDMOUNTS}/setup:/setup/ -v  ${BINDMOUNTS}/homedir:$HOMEDIR \
	-u $USER_NAME -e USER=$USER_NAME -w ${HOMEDIR}  \
	wip-docker-secboot-builder:latest "$@"
