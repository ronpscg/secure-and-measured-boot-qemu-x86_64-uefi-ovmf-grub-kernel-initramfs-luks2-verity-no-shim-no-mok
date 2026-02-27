#!/bin/bash
LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
. $LOCAL_DIR/../../common.sh || { echo "Please run the script from the right place" ; exit 1 ; }

set -euo pipefail

create_grub_env() {
	local tool
	: ${GRUB_EDITENV_TOOL=$GRUB_BUILDER_DIR/grub-editenv}
	GRUB_ENV_FILE=$ESP_FS_FOLDER/EFI/Boot/grubenv

	if [ ! -x "$GRUB_EDITENV_TOOL" ] ; then
		if ! tool=$(command -v grub-editenv) ; then
			echo -e "\e[33mYou do not have grub-editenv installed, or build under $GRUB_EDITENV_TOOL"
		fi
	else 
		tool=$GRUB_EDITENV_TOOL
	fi
	
	$tool $GRUB_ENV_FILE create
	$tool $GRUB_ENV_FILE set RAUC_SLOT=A
	$tool $GRUB_ENV_FILE set RAUC_BOOT_TRY=3
}

main() {
	create_grub_env
}

main $@
