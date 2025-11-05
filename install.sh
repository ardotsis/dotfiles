#!/bin/bash
set -e -u -o pipefail -C

##################################################
#                 Configurations                 #
##################################################
DEBUG="false"
OS=""
HOST=""
readonly USERNAME="ardotsis"
readonly DOTFILES_DIR="/home/$USERNAME/.dotfiles"
readonly DOTFILES_REPO="https://github.com/ardotsis/dotfiles.git"
readonly LOCAL_DOTFILES_REPO="/dotfiles"
readonly INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/ardotsis/dotfiles/refs/heads/main/install.sh"

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

_log() {
	local level="$1"
	local msg="$2"

	if [[ "$DEBUG" == "true" ]]; then
		printf "[%s] %s\n" "$level" "$msg"
	fi
}

_debug() {
	local msg="$1"
	_log "DEBUG" "$msg"
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

	_log "DEBUG_VARS" "$msg"
}

_info() {
	local msg="$1"
	_log "INFO" "$msg"
}

_warn() {
	local msg="$1"
	_log "WARN" "$msg"
}

_err() {
	local msg="$1"
	_log "ERROR" "$msg"
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

	if [[ "$OS" == "debian" ]]; then
		$SUDO apt-get install -y --no-install-recommends "$pkg"
	fi
}

remove_package() {
	local pkg="$1"

	if [[ "$OS" == "debian" ]]; then
		$SUDO apt-get remove -y "$pkg"
		$SUDO apt-get purge -y "$pkg"
		$SUDO apt-get autoremove -y
		$SUDO apt-get clean
	fi
}

link_file() {
	local actual="$1"
	local dest="$2"

	ln -s "$actual" "$dest"
}

fetch_config_path() {
	local common_dir="$DOTFILES_DIR/dotfiles"

	while IFS= read -r -d "" item; do
		# Host configuration
		if [[ $item == *.$HOST ]]; then
			_debug_vars "item"
			if [[ -f $item ]]; then
				echo "file"
			elif [[ -d $item ]]; then
				echo "dir"
			fi
		else
			echo ""
		fi
	done < <(find "$common_dir" -print0)
}

add_ardotsis_chan() {
	local passwd="$1"

	print_header "Add ar.sis chan"
	if [[ "$OS" == "debian" ]]; then
		$SUDO useradd -m -s "/bin/bash" -G "sudo" "$USERNAME"
		printf "%s:%s" "$USERNAME" "$passwd" | $SUDO chpasswd
		printf "%s ALL=(ALL) NOPASSWD: ALL\n" $USERNAME >/etc/sudoers.d/$USERNAME
	fi
}

clone_dotfiles_repo() {
	local from="$1"

	_info "Clone dotfiles repository from $from..."
	if [[ $from == "git" ]]; then
		git clone -b main "$DOTFILES_REPO" $DOTFILES_DIR
	elif [[ $from == "local" ]]; then
		cp -r "$LOCAL_DOTFILES_REPO" "$DOTFILES_DIR"
		chown -R "$USERNAME:$USERNAME" "$DOTFILES_DIR"
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
	if [[ "$DEBUG" == "true" ]]; then
		clone_dotfiles_repo "local"
	else
		clone_dotfiles_repo "git"
	fi
	# print_header "Install Neovim"
	# install_package "neovim"

	fetch_config_path
}

do_setup_arch() {
	_err "do_setup_arch - Not implemented yet."
}

main() {
	_debug "Start main func"
	_debug_vars "SUDO"

	# Download install script and run locally
	# if [[ -f "$0" ]]; then
	# 	script_path="/var/tmp/install.sh"
	# 	_info "Downloading install script..."
	# 	curl -fsSL "$INSTALL_SCRIPT_URL" -o $script_path
	# 	chmod +x $script_path
	# 	$script_path "$@"
	# 	exit 0
	# fi

	# Parse arguments
	local is_setup=false

	while (("$#")); do
		case "$1" in
		-h | --host)
			HOST="$2"
			shift
			;;
		-s | --setup)
			is_setup="true"
			;;
		-d | --debug)
			DEBUG="true"
			;;
		*)
			_err "Unknown parameter: '$1'"
			exit 1
			;;
		esac
		shift
	done

	if [[ -z $HOST ]]; then
		_err "Please specify the host name using '--host (-h)' parameter."
		exit 1
	fi

	_debug_vars "HOST" "is_setup" "DEBUG"

	# Validate host
	case "$HOST" in
	vultr)
		OS="debian"
		;;
	arch)
		OS="arch"
		;;
	*)
		_err "Unknown host: '$HOST'"
		exit 1
		;;
	esac

	if [[ "$is_setup" == "true" ]]; then
		"do_setup_${HOST}"
	else
		local passwd
		passwd=$(get_random_str 32)
		add_ardotsis_chan "$passwd"
		_info "Password for ar.sis: $passwd"

		script_path=$(get_script_path)
		_debug_vars "script_path"
		# TODO: download the script
		local cmd=("$script_path" "--host" "$HOST" "--setup")
		if [[ "$DEBUG" == "true" ]]; then
			cmd+=("--debug")
		fi
		print_header "Run Script as $USERNAME"
		sudo -u "$USERNAME" -- "${cmd[@]}"
	fi
}

main "$@"
