#!usr/bin/env bash
set -euo pipefail

HOSTS_RAW="https://raw.githubusercontent.com/ardotsis/dotfiles/refs/heads/main/src/hosts/"

# Check user privilege
if [ "$(id -u)" -ne 0 ]; then
	echo "Please run this script as root." >&2
	exit 1
fi

case "$1" in
"vultr")
	echo "Vultr installation"
	curl -fsSL "${HOSTS_RAW}vultr/install.sh" | bash
	;;
*)
	echo "Unknown host: '$1'"
	;;
esac
