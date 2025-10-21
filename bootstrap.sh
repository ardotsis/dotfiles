#!/bin/bash -eu

case "$1" in
arch | vultr)
	curl -fsSL "https://raw.githubusercontent.com/ardotsis/dotfiles/refs/heads/main/src/hosts/$1/install.sh" | bash
	;;
*)
	echo "Unknown hostname: '$1'"
	;;
esac
