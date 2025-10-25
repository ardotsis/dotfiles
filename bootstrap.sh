#!/bin/bash -eu
# What bootstrap script does.
# 	1. Install Git, if it doesn't exist.
# 	2. Create a new user (ardotsis) to install dotfiles repository.

USERNAME="ardotsis"
REPO="https://github.com/ardotsis/dotfiles.git"

is_cmd_exist() {
	local cmd="$1"

	if command -v "$cmd" >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

case "$1" in
vultr)
	echo "Creating new user"
	sudo useradd -m -s /bin/bash -G sudo $USERNAME
	if ! is_cmd_exist git; then
		echo "Install Git"
		sudo apt-get update
		sudo apt-get install -y --no-install-recommends git
	fi
	su -c $USERNAME
	cd "/home/$USERNAME"
	git clone -b main $REPO
	;;
arch)
	echo "btw, i use Arch (WIP)"
	;;
*)
	echo "Unknown hostname: '$1'"
	;;
esac
