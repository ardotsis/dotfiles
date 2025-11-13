#!/bin/bash
set -e -u -o pipefail -C

##################################################
#                 Configurations                 #
##################################################
readonly USERNAME="ardotsis"
readonly HOME_DIR="/home/$USERNAME"
readonly DOTFILES_DIR="$HOME_DIR/.dotfiles"
readonly DOTFILES_SRC_DIR="$DOTFILES_DIR/dotfiles"
readonly COMMON_DIR="$DOTFILES_SRC_DIR/common"
readonly DOTFILES_REPO="https://github.com/ardotsis/dotfiles.git"
readonly DOTFILES_LOCAL_REPO="/dotfiles"
readonly DOTFILES_INSTALLER_URL="https://raw.githubusercontent.com/ardotsis/dotfiles/refs/heads/main/install.sh"

# Parse script parameters
while (("$#")); do
	case "$1" in
	"-h" | "--host")
		readonly HOST="$2"
		shift
		;;
	"-s" | "--setup")
		readonly IS_SETUP="true"
		;;
	"-d" | "--debug")
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
	readonly IS_SETUP="false"
fi

if [[ -z "${DEBUG+x}" ]]; then
	readonly DEBUG="false"
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

readonly HOST_DIR="$DOTFILES_SRC_DIR/hosts/$HOST"
readonly HOST_PREFIX="${HOST^^}_"

# Set sudo mode
if [[ $(id -u) -eq 0 ]]; then
	readonly SUDO=""
else
	if [[ "$OS" == "debian" ]]; then
		readonly SUDO="sudo"
	fi
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
	local timestamp

	timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

	if [[ "$DEBUG" == "true" ]]; then
		printf "[%s] [%s] [%s] %s\n" "$timestamp" "$level" "${FUNCNAME[2]}" "$msg" >&2
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

	_log "DEBUG_VAR" "$msg"
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

	# Use printf to flush buffer forcefully
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

get_home_type() {
	local path="$1"

	if [[ "$path" == "$COMMON_DIR"* ]]; then
		printf "COMMON"
	elif [[ "$path" == "$HOST_DIR"* ]]; then
		printf "HOST"
	elif [[ "$path" == "$HOME_DIR"* ]]; then
		printf "HOME"
	else
		log_error "Unknown home type for path: $path"
		exit 1
	fi
}

convert_home_path() {
	local original_path="$1"
	local to="$2"

	local from
	from=$(get_home_type "$original_path")
	local from_var="${from}_DIR"
	local to_var="${to^^}_DIR"

	# Bash parameter substitution (without sed)
	printf "%s" "${original_path/#${!from_var}/${!to_var}}"
}

do_link() {
	# Do NOT use double quotes with -d options to preserve null character
	local a_home_dir="$1"
	local is_host_exclusive_dir="${2-false}"

	# Generate each home directories
	local a_host_dir a_common_dir
	a_host_dir="$(convert_home_path "$a_home_dir" "host")"
	a_common_dir="$(convert_home_path "$a_home_dir" "common")"
	log_vars "a_home_dir" "a_host_dir" "a_common_dir"

	get_pure_items() {
		local dir_path="$1"

		local home_type
		home_type=$(get_home_type "$dir_path")
		local dir_var="${home_type}_DIR"

		find "$dir_path" -mindepth 1 -maxdepth 1 -print0 | while IFS="" read -r -d $'\0' item; do
			printf "%s\0" "${item#"${!dir_var}"/}"
		done
	}

	local a_host_items=()
	mapfile -d $'\0' a_host_items < <(get_pure_items "$a_host_dir")

	local a_common_items=()
	if [[ "$is_host_exclusive_dir" == "false" ]]; then
		mapfile -d $'\0' a_common_items < <(get_pure_items "$a_common_dir")

		# Remove host prefixed items from common items
		for h_i in "${!a_host_items[@]}"; do
			local path="${a_host_items[$h_i]}"
			local dirname_="${path%/*}"
			local basename_="${path##*/}"
			if [[ "$basename_" == "$HOST_PREFIX"* ]]; then
				for c_i in "${!a_common_items[@]}"; do
					if [[ "${a_common_items[$c_i]}" == "${dirname_}/${basename_#"${HOST_PREFIX}"}" ]]; then
						log_debug "Remove host prefixed item from common items: '${a_common_items[$c_i]}'"
						unset "a_common_items[$c_i]"
						break
					fi
				done
			fi
		done
	fi
	log_vars "a_host_items[@]" "a_common_items[@]"

	set() {
		# TODO: How name reference works in bash?
		local -n arr_ref="$1"
		local mode="$2"

		mapfile -d $'\0' "${!arr_ref}" < <(comm "$mode" -z \
			<(printf "%s\0" "${a_host_items[@]}" | sort -z) \
			<(printf "%s\0" "${a_common_items[@]}" | sort -z))
	}

	# shellcheck disable=SC2034
	local union_items=() host_items=() common_items=()
	set "union_items" "-12"
	set "host_items" "-23"
	set "common_items" "-13"
	log_vars "union_items[@]" "common_items[@]" "host_items[@]"

	# Host prefixed items always in $host_items
	for item_type in "union" "host" "common"; do
		local -n items="${item_type}_items"
		for item in "${items[@]}"; do
			local as_home_item="${a_home_dir}/${item}"
			# shellcheck disable=SC2034
			local as_common_item="${a_common_dir}/${item}"
			# shellcheck disable=SC2034
			local as_host_item="${a_host_dir}/${item}"

			if [[ "$item_type" == "union" ]]; then
				local actual_var="as_host_item"
			else
				local actual_var="as_${item_type}_item"
			fi

			local actual="${!actual_var}"
			log_vars "item_type" "item" "as_home_item" "actual"
			if [[ -f "$actual" ]]; then
				log_info "Link ${item_type^^} file: $actual -> $as_home_item"
				ln -sf "$actual" "$as_home_item"
			elif [[ -d "$actual" ]]; then
				log_info "Create directory: '$as_home_item'"
				mkdir -p "$as_home_item"

				if [[ "$item_type" == "host" ]]; then
					do_link "$as_home_item" "true"
				else
					do_link "$as_home_item"
				fi
				ls -la "$as_home_item"
			fi
		done
	done

	tree
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
		cp -r "$DOTFILES_LOCAL_REPO" "$DOTFILES_DIR"
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

	do_link "$HOME_DIR"
}

do_setup_arch() {
	log_error "do_setup_arch - Not implemented yet."
}

main() {
	log_info "Start installation..."

	log_vars \
		"USERNAME" "DOTFILES_DIR" "DOTFILES_SRC_DIR" \
		"COMMON_DIR" "HOST_DIR" "HOST_PREFIX" \
		"HOST" "IS_SETUP" "DEBUG" "SUDO" "OS"

	if [[ "$IS_SETUP" == "true" ]]; then
		"do_setup_${HOST}"
	else
		local passwd
		passwd=$(get_random_str 32)
		add_ardotsis_chan "$passwd"
		echo "Password for ar.sis: $passwd"

		script_path=$(get_script_path)
		log_vars "script_path"
		cmd=(
			"$script_path"
			"--host"
			"$HOST"
			"--setup"
			"$([[ "$DEBUG" == "true" ]] && printf "%s" "--debug")"
		)

		print_header "Run Script as $USERNAME"
		sudo -u "$USERNAME" -- "${cmd[@]}"
	fi
}

main
