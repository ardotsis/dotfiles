#!usr/bin/env bash
set -euo pipefail

HOSTS_REPO="https://raw.githubusercontent.com/ardotsis/dotfiles/refs/heads/main/src/hosts/"
AVAILABLE_HOSTS=("arch", "vultr")

curl -fsSL "${RAW_HOSTS_REPO}arch/install.sh" | bash
