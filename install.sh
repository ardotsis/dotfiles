#!/bin/bash
set -e -u -o pipefail -C

##################################################
#                 Configurations                 #
##################################################
# Paths
readonly USERNAME="ardotsis"
readonly DOTFILES_DIR="/home/$USERNAME/.dotfiles"
readonly DOTFILES_SRC_DIR="$DOTFILES_DIR/dotfiles"
readonly COMMON_HOME_DIR="$DOTFILES_SRC_DIR/common"
readonly DEBUG_DOTFILES_DATA="/dotfiles"
readonly DOTFILES_REPO="https://github.com/ardotsis/dotfiles.git"
readonly INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/ardotsis/dotfiles/refs/heads/main/install.sh"

# Parse script parameters
while (("$#")); do
	case "$1" in
	-h | --host)
		readonly HOST="$2"
		shift
		;;
	-s | --setup)
		readonly IS_SETUP="true"
		;;
	-d | --debug)
		readonly DEBUG="true"
		;;
	*)
		printf "Unknown parameter: '%s'" "$1"
		exit 1
		;;
	esac
	shift
done

if [[ -z "${HOST+x}" ]]; then
	printf "Please specify the host name using '--host (-h)' parameter."
	exit 1
fi

if [[ -z "${IS_SETUP+x}" ]]; then
	readonly IS_SETUP=false
fi

if [[ -z "${DEBUG+x}" ]]; then
	readonly DEBUG=false
fi

if [[ $(id -u) -eq 0 ]]; then
	readonly SUDO=""
else
	readonly SUDO="sudo"
fi

# Validate host
case "$HOST" in
vultr)
	readonly OS="debian"
	;;
arch)
	readonly OS="arch"
	;;
*)
	printf "Unknown host: '%s'" "$HOST"
	exit 1
	;;
esac

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

log_debug() {
	local msg="$1"
	_log "DEBUG" "$msg"
}

log_vars() {
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

log_info() {
	local msg="$1"
	_log "INFO" "$msg"
}

log_warn() {
	local msg="$1"
	_log "WARN" "$msg"
}

log_error() {
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

read0() {
	local assign_var="$1"

	IFS="" read -r -d "" "$assign_var"
}

find_depth_1() {
	local dir_path="$1"

	find "$dir_path" -maxdepth 1 -print0
}

fetch_config_path() {
	# local common_dir="$DOTFILES_DIR/dotfiles/common"
	# local host_dir="$DOTFILES_DIR/dotfiles/host/$HOST"
	local item
	local basename

	# scan common directory and save paths
	# include host's exceptions

	# has_host() {
	# 	local $item="$1"
	# 	local basename=${item##*/}

	# 	if [[ -f "$host_dir/$basename"  ]]
	# }

	while read0 "item"; do
		basename=${item##*/}
		log_vars "basename"

		if [[ -f $item ]]; then

			echo "file"
		elif [[ -d $item ]]; then
			echo "dir"
		fi

		# if [[ $item == *."$HOST" ]]; then
		# 	echo "host item: $item"
		# else
		# 	echo "common item: $item"
		# fi
	done < <(find_depth_1 "$COMMON_HOME_DIR")
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

	log_info "Clone dotfiles repository from $from..."
	if [[ $from == "git" ]]; then
		git clone -b main "$DOTFILES_REPO" $DOTFILES_DIR
	elif [[ $from == "local" ]]; then
		cp -r "$DEBUG_DOTFILES_DATA" "$DOTFILES_DIR"
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
	log_error "do_setup_arch - Not implemented yet."
}

main() {
	log_debug "Start main func"
	log_vars "SUDO"

	# Download install.sh and run locally
	# if [[ -f "$0" ]]; then
	# 	script_path="/var/tmp/install.sh"
	# 	log_info "Downloading install script..."
	# 	curl -fsSL "$INSTALL_SCRIPT_URL" -o $script_path
	# 	chmod +x $script_path
	# 	$script_path "$@"
	# 	exit 0
	# fi

	if [[ -z $HOST ]]; then
		log_error "Please specify the host name using '--host (-h)' parameter."
		exit 1
	fi

	log_vars "HOST" "IS_SETUP" "DEBUG"

	if [[ "$IS_SETUP" == "true" ]]; then
		"do_setup_${HOST}"
	else
		local passwd
		passwd=$(get_random_str 32)
		add_ardotsis_chan "$passwd"
		log_info "Password for ar.sis: $passwd"

		script_path=$(get_script_path)
		log_vars "script_path"
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
