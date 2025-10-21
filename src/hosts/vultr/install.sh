#!/bin/bash -eu

is_root() {
	[ "$(id -u)" -eq 0 ]
}

is_cmd_exist() {
	if command -v "$1" >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

main() {
	if ! is_root; then
		echo "Please run this script as root."
		exit 1
	fi

	# Update package manager
	apt-get update
	apt-get upgrade -y

	# Install git
	if ! is_cmd_exist git; then
		echo "Installing git.."
		apt-get install git -y
	fi
}

main
