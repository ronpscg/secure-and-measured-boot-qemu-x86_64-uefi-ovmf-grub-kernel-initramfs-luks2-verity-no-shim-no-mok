#!/bin/bash
#
# This is meany to be an entry point that gives some hints to the user on what to do next, or just runs /bash otherwise
# TODO: to allow the setting of the loopback devices if they are missing, this should probably be made ENTRYPOINT. It is currently CMD



# This is a workaround to avoid the dreaded "losetup: device node /dev/loop39 (7:39) is lost. You may use mknod(1) to recover it." message inside a container.
# There is no bug in it, it may happen if you are unlucky, or if you use a distro that loves grabbing those loopback devices.
# The number of devices is arbitrary, but who knows what goes in your host
# 64 would probably be a good limit, but all those app containers, snap et. al, could go behind proportion.
#
docker_loopdev_preventive_workaround() {
	MAJOR=7
	NUMMINORS=128


	[ "$NUMMINORS" -gt "96" ] && echo "Adjusting loopback devices just in case. The lower NUMINORS is the faster it goes. But don't set it too low (and definitely not below 64)"
	for i in $(seq 0 $NUMMINORS); do
		DEV_NODE="/dev/loop$i"
		# Check if the block device file exists
		if [ ! -b "$DEV_NODE" ]; then
			#echo "Creating missing loop device node: $DEV_NODE" # commented out as it may be too chatty
			mknod "$DEV_NODE" b $MAJOR $i || echo "Failed to created /dev/loop$i although it was missing"
			chmod 660 "$DEV_NODE"
		fi
	done
}
export -f docker_loopdev_preventive_workaround

set_bash_environment_from_skeleton() {
	for f in .bash_logout  .bashrc  .profile ; do
		if [ ! -f "$HOME/$f" ] ; then
			cp /etc/skel/$f $HOME
		fi
	done
}


do_basic_adjustments() {
	set_bash_environment_from_skeleton
	sudo bash -c "$(declare -f docker_loopdev_preventive_workaround); docker_loopdev_preventive_workaround"
}


recommend_usage() {
	if [ "$(ls | wc -l)" = "1" ] ; then
		echo -e "Your environment is not properly setup yet. Please run \e[33m/setup/build.sh -c -k\e[0m"
		echo "You can also run  /setup/build.sh/ -c -k -b -p to do the entire sequence. We let you choose what to do"
	else
		echo -e "Enjoy your shell. You are welcome to run \e[33m/setup/build.sh\e[0m with your favorite parameters, or run it with -h to learn or relearn its usage"
	fi
}

#============================================================
# Real work starts here
#=============================================================
main() {
	do_basic_adjustments
	if [ "$#" = "1" -a "$1" = "/bin/bash" ] ; then
		recommend_usage
		"$@"
	else
		echo "Running $@"
		exec "$@"
	fi
}

main "$@"
