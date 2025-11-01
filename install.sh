#!/bin/bash
set -e -u -o pipefail -C

##################################################
#                 Configurations                 #
##################################################
readonly USERNAME="ardotsis"
readonly DOTFILES_REPO="https://github.com/ardotsis/dotfiles.git"

if [[ $(id -u) -eq 0 ]]; then
	readonly SUDO=""
else
	readonly SUDO="sudo"
fi

##################################################
#                Common Functions                #
##################################################
print_header() {
	local text="$1"
	local width=35
	local padding="$(((width - ${#text} - 2) / 2))"
	local extra="$(((width - ${#text} - 2) % 2))"

	printf "#%.0s" $(seq 1 "$width")
	printf "\n"
	printf "#%*s%s%*s#" "$padding" "" "$text" "$((padding + extra))" ""
	printf "\n"
	printf "#%.0s" $(seq 1 "$width")
	printf "\n"
}

_print_msg() {
	local level="$1"
	local msg="$2"
	printf "%s\n" "[$level] $msg"
}

_debug() {
	local msg="$1"
	_print_msg "DEBUG" "$msg"
}

_debug_vars() {
	local var_names=("$@")
	local msg=""

	for var_name in "${var_names[@]}"; do
		fmt="\$$var_name='${!var_name}'"
		if [[ -z $msg ]]; then
			msg="$fmt"
		else
			msg="$msg $fmt"
		fi
	done

	_print_msg "DEBUG_VARS" "$msg"
}

_info() {
	local msg="$1"
	_print_msg "INFO" "$msg"
}

_warn() {
	local msg="$1"
	_print_msg "WARN" "$msg"
}

_err() {
	local msg="$1"
	_print_msg "ERROR" "$msg"
}

get_script_path() {
	printf "%s" "$(readlink -f "$0")"
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

add_ardotsis_chan() {
	local passwd="$1"

	print_header "Add ar.sis chan"
	if [[ "$OS" = "debian" ]]; then
		$SUDO useradd -m -s "/bin/bash" -G "sudo" "$USERNAME"
		printf "%s" "$USERNAME:$passwd" | $SUDO chpasswd
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

do_setup_arch() {
	_err "do_setup_arch - Not implemented yet."
}

main() {
	_debug "Start main func"
	_debug_vars "SUDO"

	# Parse arguments
	local host
	local is_setup=false

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
			_err "Unknown parameter: '$1'"
			exit 1
			;;
		esac
		shift
	done

	_debug_vars "host" "is_setup"

	# Validate host
	case "$host" in
	vultr)
		OS="debian"
		;;
	arch)
		OS="arch"
		;;
	*)
		_err "Unknown host: '$host'"
		exit 1
		;;
	esac

	if $is_setup; then
		"do_setup_${host}"
	else
		local passwd
		passwd=$(get_random_str 32)
		add_ardotsis_chan "$passwd"
		_info "Password for ar.sis: $passwd"

		script_path=$(get_script_path)
		_info "Allow $USERNAME to run script as root"
		printf "%s\n" "$USERNAME ALL=(root) NOPASSWD: $script_path" >/etc/sudoers.d/${USERNAME}_dotfiles

		_debug_vars "script_path"
		local cmd=("$script_path" "-h" "$host" "-s")
		print_header "Run Script as $USERNAME"
		sudo -u "$USERNAME" -- "${cmd[@]}"
	fi
}

main "$@"
