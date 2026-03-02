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

date >> /tmp/log
grub-list
