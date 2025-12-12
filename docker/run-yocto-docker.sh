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

: ${MOREMOUNTS=""}
MOREMOUNTS+=" -v $HOME/pscg/customers/build-stuff/:$HOMEDIR/pscg/customers/build-stuff/" 

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

if [ -n "$MOREMOUNTS" ] ; then
	# You should do this for every mount target (either here or inside the running Docker)- if the directory structure does not exist and is automatically created,
	# it will be owned by the superuser, and you won't be able to write into it
	mountdirs_srcs="$HOME/pscg/customers/build-stuff/"
	mountdirs_targets="$BINDMOUNTS/homedir/pscg/customers/build-stuff/"
	for dir in $mountdirs_srcs $mountdirs_targets ; do
		if [ ! -d $dir ] ; then
			echo Creating $dir for the first time
			mkdir -p $dir
		else
			: # Won't change permissions. If the user decided to mix and match things, it's their problem
		fi
	done
fi
mkdir -p $BINDMOUNTS/homedir/yocto
#--------- this is temporary, to avoid adding git keys on a disconnected computer ----------
: ${DO_COPY_KAS_PROJECT_FROM_LOCAL_DIR=false}
if [ "$DO_COPY_KAS_PROJECT_FROM_LOCAL_DIR" = "true" ] ; then
	if [ -d ~/kas-project-src/ -a ! -d $BINDMOUNTS/homedir/yocto/kasdir ] ; then
		cp -av ~/kas-project-src/ $BINDMOUNTS/homedir/yocto/kasdir
	fi
else
	mkdir -p $BINDMOUNTS/homedir/yocto
	echo "/setup/build.sh -c will clone the requested repo into $BINDMOUNTS/homedir/yocto/kasdir"
fi

#------------- end of temporary -------------

#-----------------------------------------
# Running docker
#-----------------------------------------
PRIVILEGED=--privileged # To allow dealing with internal docker mounts and with losetup
docker run -it --rm  $PRIVILEGED -v /var/run/docker.sock:/var/run/docker.sock \
	--group-add $(getent group docker | awk -F: '{print $3}')  \
	--group-add $(getent group kvm | awk -F: '{print $3}') \
	-v ${BINDMOUNTS}/setup:/setup/ -v  ${BINDMOUNTS}/homedir:$HOMEDIR \
	${MOREMOUNTS} \
	-u $USER_NAME -e USER=$USER_NAME -w ${HOMEDIR}  \
	--name "yocto-builder-docker" \
	wip-yocto-docker-secboot-builder:latest "$@"
