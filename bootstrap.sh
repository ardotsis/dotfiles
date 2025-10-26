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

get_rand_str() {
	local length="$1"

	printf %s "$(tr -dc "A-Za-z0-9!?%=" </dev/urandom | head -c "$length")"
}

case "$1" in
vultr)
	echo "Creating new user"
	useradd -m -s /bin/bash -G sudo $USERNAME
	passwd=$(get_rand_str 32)
	echo "$USERNAME:$passwd" | sudo chpasswd
	if ! is_cmd_exist git; then
		echo "Install Git"
		sudo apt-get update
		sudo apt-get install -y --no-install-recommends git
	fi
	cd "/home/$USERNAME"
	sudo -u "$USERNAME" bash -c "git clone -b main '$REPO'"
	sudo -u "$USERNAME" bash -c "./dotfiles/hosts/vultr/bin/setup.sh"
	;;
arch)
	echo "btw, i use Arch (WIP)"
	;;
*)
	echo "Unknown hostname: '$1'"
	;;
esac
