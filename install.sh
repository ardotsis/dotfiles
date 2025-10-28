#!/bin/bash
set -e -u -o pipefail -C

readonly HOST="$1"
readonly USERNAME="ardotsis"
readonly REPO="https://github.com/ardotsis/dotfiles.git"

if [[ $(id -u) -eq 0 ]]; then
	echo "Run as root mode."
	readonly SUDO=""
else
	echo "Run as non-root mode."
	readonly SUDO="sudo"
fi

print_header() {
	local text="$1"
	local width=50
	local padding=$(((width - ${#text} - 2) / 2))
	local extra=$(((width - ${#text} - 2) % 2))

	printf "#%.0s" $(seq 1 "$width")
	echo
	printf "#%*s%s%*s#" "$padding" "" "$text" "$((padding + extra))" ""
	echo
	printf "#%.0s" $(seq 1 "$width")
	echo
}

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

inst_pkg() {
	local pkg="$1"

	if [[ $OS = "debian" ]]; then
		$SUDO apt-get install -y --no-install-recommends "$pkg"
	fi
}

rm_pkg() {
	local pkg="$1"

	if [[ $OS = "debian" ]]; then
		$SUDO apt-get remove -y "$pkg"
		$SUDO apt-get purge -y "$pkg"
		$SUDO apt-get autoremove -y
		$SUDO apt-get clean
	fi
}

setup_sshd() {
	echo "a"
}

do_vultr_flow() {
	OS="debian"

	print_header "Create User"
	$SUDO useradd -m -s /bin/bash -G sudo $USERNAME
	passwd=$(get_rand_str 32)
	echo "$USERNAME:$passwd" | $SUDO chpasswd

	if is_cmd_exist ufw; then
		print_header "Uninstall UFW"
		$SUDO ufw disable
		rm_pkg "ufw"
	fi

	if ! is_cmd_exist git; then
		print_header "Install Git"
		inst_pkg "git"
	fi

	print_header "Clone dotfiles repository"
	cd "/home/$USERNAME"
	sudo -u "$USERNAME" bash -c "git clone -b main '$REPO'"
}

do_arch_flow() {
	OS="arch"

	echo "arch - Not implemented yet."
}

main() {
	case "$HOST" in
	"vultr")
		do_vultr_flow
		;;
	"arch")
		do_arch_flow
		;;
	*)
		echo "Unknown hostname: '$HOST'"
		;;
	esac
}

main
