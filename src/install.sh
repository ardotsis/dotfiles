#!usr/bin/env bash
set -euo pipefail
REPO_URL="https://github.com/ardotsis/dotfiles.git"

if [$1 = "vultr"]; then
    echo "Vultr installation"
else
    echo "Something else"
fi
