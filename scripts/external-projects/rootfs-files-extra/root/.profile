# ~/.profile: executed by Bourne-compatible login shells.

if [ -x /data/devhack.sh ] ; then
	/data/devhack.sh
fi

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

if [ -f /opt/scripts/rauc/rauc_functions.sh ] ; then
	. /opt/scripts/rauc/rauc_functions.sh
fi

if [ -d /opt/scripts/swupdate ] ; then
	# Allow adding swupdate - and set an alias
	export PATH=$PATH:/opt/scripts/swupdate/
	alias swui='MORE_FLAGS=-v swupdate-install.sh'	# swupdate -i alias
	alias swus='swupdate-mark-good-bad.sh'		# swupdate status (RAUC like) mark-good/mark-bad alias
fi

date >> /tmp/log
grub-list
