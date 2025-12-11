#!/bin/bash
# dev script to wrap some stuff

LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
SCRIPTS_DIR=$(readlink -f $LOCAL_DIR/..)
export COMMON_CONFIG_FILE
: ${COMMON_CONFIG_FILE:=$LOCAL_DIR/bitbake.env}
# TODO check later. /setup/ sets COMMON_CONFIG_FILE to another file. For this flow, we want the bitbake.env
COMMON_CONFIG_FILE=$LOCAL_DIR/bitbake.env

# Could run bitbake -e and get some environment variables, but I won't do that
: ${YOCTO_KAS_DIR=$HOME/yocto/kasdir}
: ${YOCTO_KAS_YAML=$YOCTO_KAS_DIR/kas-vektor-wip.yaml}
: ${YOCTO_BUILD_DIR=$YOCTO_KAS_DIR/build}
: ${MACHINE=intel-corei7-64}
: ${IMAGE_BASENAME=vektor-os-signed}

TOPDIR=${YOCTO_BUILD_DIR}
DEPLOY_DIR=${TOPDIR}/tmp/deploy
DEPLOY_DIR_IMAGE=${DEPLOY_DIR}/images/${MACHINE}
SECURE_ARTIFACTS_BASE_SYMLINK="${DEPLOY_DIR_IMAGE}/secure-boot-work"
SECURE_ARTIFACTS_BASE_REALPATH=$(readlink -f $SECURE_ARTIFACTS_BASE_SYMLINK)

set -euo pipefail
build_with_kas() {
	cd $YOCTO_KAS_DIR
	if kas build $YOCTO_KAS_YAML ; then
		echo -e "\e[32mkas build succeeded\e[0m"
	else
		echo -e "\e[31mkas build failed. Failed to build the Yocto Project\e[0m"
		exit 1
	fi
}

repackage_and_sign_images() {
	cd $LOCAL_DIR
	export YOCTO_BUILD_DIR MACHINE IMAGE_BASENAME 
	if ./yocto-copy-artifacts.sh ; then
		echo -e "\e[32Repackaging succeeded\e[0m"
	else
		echo -e "\e[31mFailed to repackage and sign the image\e[0m"
		exit 1
	fi
}

check_docker() {
	test -e /.dockerenv
}

main() {
	if ! check_docker ; then
		echo "Sorry, this is meant to be run inside Docker only. It can be adjusted very easily, but it makes it easier to use some well known paths as defaults this way."
		exit 1
	else
		echo "Building in docker - will attempt to utilize mirrors from your bind mount dir. You can ignore the BB_HASHSERVE warning you will likely see during the build"
		YOCTO_KAS_YAML=$YOCTO_KAS_YAML:$YOCTO_KAS_DIR/kas/kas-in-docker.yaml
	fi

	build_with_kas
	repackage_and_sign_images

	echo -e "\e[42mDone. your image and other useful artifacts are available at $SECURE_ARTIFACTS_BASE_SYMLINK/artifacts\e[0m"
}

main $@
