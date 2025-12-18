# ~/.profile: executed by Bourne-compatible login shells.

if [ -x /data/devhack.sh ] ; then
	/data/devhack.sh
fi

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi
