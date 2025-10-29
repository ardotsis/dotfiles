#!/bin/bash
set -e -u -o pipefail -C

##################################################
#                 Configurations                 #
##################################################
readonly USERNAME="ardotsis"
readonly DOTFILES_REPO="https://github.com/ardotsis/dotfiles.git"

if [[ "$(id -u)" -eq 0 ]]; then
	readonly SUDO=""
else
	readonly SUDO="sudo"
fi

##################################################
#                Common Functions                #
##################################################
print_header() {
	local text="$1"
	local width=50
	local padding="$(((width - ${#text} - 2) / 2))"
	local extra="$(((width - ${#text} - 2) % 2))"

	printf "#%.0s" "$(seq 1 "$width")"
	printf "\n"
	printf "#%*s%s%*s#" "$padding" "" "$text" "$((padding + extra))" ""
	printf "\n"
	printf "#%.0s" "$(seq 1 "$width")"
	printf "\n"
}

show_info() {
	local msg="$1"

	printf "[INFO] %s\n" "$msg"
}

show_error() {
	local msg="$1"

	printf "[ERROR] %s\n" "$msg"
}

is_cmd_exist() {
	local cmd="$1"

	if command -v "$cmd" >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

get_random_str() {
	local length="$1"

	printf "%s" "$(tr -dc "A-Za-z0-9!?%=" </dev/urandom | head -c "$length")"
}

install_package() {
	local pkg="$1"

	if [[ "$OS" = "debian" ]]; then
		$SUDO apt-get install -y --no-install-recommends "$pkg"
	fi
}

remove_package() {
	local pkg="$1"

	if [[ "$OS" = "debian" ]]; then
		$SUDO apt-get remove -y "$pkg"
		$SUDO apt-get purge -y "$pkg"
		$SUDO apt-get autoremove -y
		$SUDO apt-get clean
	fi
}

create_sudo_user() {
	if [[ "$OS" = "debian" ]]; then
		$SUDO useradd -m -s /bin/bash -G sudo "$USERNAME"
		passwd="$(get_random_str 32)"
		echo "$USERNAME:$passwd" | $SUDO chpasswd
	fi
}

##################################################
#                   Installers                   #
##################################################
do_setup_vultr() {
	if is_cmd_exist ufw; then
		print_header "Uninstall UFW"
		$SUDO ufw disable
		remove_package "ufw"
	fi

	if ! is_cmd_exist git; then
		print_header "Install Git"
		install_package "git"
	fi

	print_header "Clone Dotfiles Repository"
	cd "/home/$USERNAME"
	git clone -b main "$DOTFILES_REPO"
}

do_setup_arch_usr() {
	OS="arch"

	echo "arch - Not implemented yet."
}

main() {
	is_setup=false
	host=""

	while (("$#")); do
		case "$1" in
		-h | --host)
			host="$2"
			shift
			;;
		-s | --setup)
			is_setup=true
			;;
		*)
			echo "Unknown parameter: '$1'"
			exit 1
			;;
		esac
		shift
	done

	case "$host" in
	vultr)
		OS="debian"
		;;
	arch)
		OS="arch"
		;;
	*)
		show_error "Unknown host: '$1'"
		;;
	esac

	# if is_setup; then
	# 	f="do_setup_$(host)_usr"
	# else
	# 	f="do_init_$(host)_usr"

	echo "host: $host"
	echo "is_setup: $is_setup"
}

main "$@"
