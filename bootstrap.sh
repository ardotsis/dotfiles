#!usr/bin/env bash
set -euo pipefail

RAW_HOSTS_REPO="https://raw.githubusercontent.com/ardotsis/dotfiles/refs/heads/main/src/hosts/"

case "$1" in
"vultr")
	echo "Vultr installation"
	curl -fsSL "${RAW_HOSTS_REPO}vultr/install.sh" | bash
	;;
*)
	echo "Unknown host: '$1'"
	;;
esac
