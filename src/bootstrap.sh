#!usr/bin/env bash
set -euo pipefail

HOSTS_RAW="https://raw.githubusercontent.com/ardotsis/dotfiles/refs/heads/main/src/hosts/"

case "$1" in
"vultr")
	echo "Vultr installation"
	curl -fsSL "${HOSTS_RAW}vultr/install.sh" | bash
	;;
*)
	echo "Unknown host: '$1'"
	;;
esac
