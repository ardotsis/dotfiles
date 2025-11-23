#!/bin/bash
set -e -u -o pipefail -C

##################################################
#                 Configurations                 #
##################################################
readonly INSTALL_USER="ardotsis"

# Paths
readonly HOME_DIR="/home/$INSTALL_USER"
readonly DOTFILES_DIR="$HOME_DIR/.dotfiles"
readonly DOTFILES_SRC_DIR="$DOTFILES_DIR/dotfiles"
readonly COMMON_DIR="$DOTFILES_SRC_DIR/common"
readonly PACKAGES_FILE="$DOTFILES_SRC_DIR/packages.txt"
readonly SECRET_FILE="${HOME_DIR}/DOTFILES_SECRETS"
readonly INSTALLER_TMP_FILE="/var/tmp/install_dotfiles.sh"

# URIs
readonly DOTFILES_REPO="https://github.com/ardotsis/dotfiles.git"
readonly DOTFILES_LOCAL_REPO="/dotfiles"
readonly DOTFILES_SCRIPT_URL="https://raw.githubusercontent.com/ardotsis/dotfiles/refs/heads/main/install.sh"

# Parse script parameters
while (("$#")); do
	case "$1" in
	"-h" | "--host")
		readonly HOST="$2"
		shift
		;;
	"-i" | "--initialized")
		readonly INITIALIZED="true"
		;;
	"-t" | "--test")
		readonly TEST="true"
		;;
	*)
		printf "Unknown parameter: '%s'" "$1\n"
		exit 1
		;;
	esac
	shift
done

if [[ -z "${HOST+x}" ]]; then
	printf "Please specify the host name using '--host (-h)' parameter.\n"
	exit 1
fi

if [[ -z "${INITIALIZED+x}" ]]; then
	readonly INITIALIZED="false"
fi

if [[ -z "${TEST+x}" ]]; then
	readonly TEST="false"
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
if [[ "$(id -u)" == "0" ]]; then
	readonly SUDO=""
else
	if [[ "$OS" == "debian" ]]; then
		readonly SUDO="sudo"
	fi
fi

declare -A COLOR=(
	["reset"]="\033[0m"

	["black"]="\033[0;30m"
	["red"]="\033[0;31m"
	["green"]="\033[0;32m"
	["yellow"]="\033[0;33m"
	["blue"]="\033[0;34m"
	["purple"]="\033[0;35m"
	["cyan"]="\033[0;36m"
	["white"]="\033[0;37m"
)

declare -A LOG_COLOR=(
	["debug"]="${COLOR["white"]}"
	["info"]="${COLOR["green"]}"
	["warn"]="${COLOR["yellow"]}"
	["error"]="${COLOR["red"]}"
	["var"]="${COLOR["purple"]}"
	["value"]="${COLOR["cyan"]}"
)

##################################################
#                Common Functions                #
##################################################
_log() {
	local level="$1"
	local msg="$2"

	local caller="GLOBAL"
	for funcname in "${FUNCNAME[@]}"; do
		[[ "$funcname" == "_log" ]] && continue
		[[ "$funcname" == "log_"* ]] && continue
		caller="$funcname"
		break
	done

	local timestamp
	timestamp="$(date "+%Y-%m-%d %H:%M:%S")"
	printf "[%s] [%b%s%b] [%s] %b\n" "$timestamp" "${LOG_COLOR["${level}"]}" "${level^^}" "${COLOR["reset"]}" "$caller" "$msg" >&2
}
log_debug() { _log "debug" "$1"; }
log_info() { _log "info" "$1"; }
log_warn() { _log "warn" "$1"; }
log_error() { _log "error" "$1"; }
log_vars() {
	local var_names=("$@")

	local msg=""
	for var_name in "${var_names[@]}"; do
		fmt="${LOG_COLOR["var"]}\$$var_name${COLOR["reset"]}='${LOG_COLOR["value"]}${!var_name}${COLOR["reset"]}'"
		if [[ -z "$msg" ]]; then
			msg="$fmt"
		else
			msg="$msg $fmt"
		fi
	done

	_log "debug" "$msg"
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
	from="$(get_home_type "$original_path")"
	local from_var="${from}_DIR"
	local to_var="${to^^}_DIR"

	# Bash parameter substitution (without sed)
	printf "%s" "${original_path/#${!from_var}/${!to_var}}"
}

link() {
	local a_home_dir="${1-$HOME_DIR}"
	local dir_type="${2:-}"
	local prefix_base="${3:-}"

	log_vars "a_home_dir" "dir_type" "prefix_base"

	local as_host_dir as_common_dir
	as_host_dir="$(convert_home_path "$a_home_dir" "host")"
	as_common_dir="$(convert_home_path "$a_home_dir" "common")"
	log_vars "a_home_dir" "as_host_dir" "as_common_dir"

	map_dir_items() {
		local dir_path="$1"
		local -n arr_ref="$2"

		# Do NOT use double quotes with -d options to preserve null character
		mapfile -d $'\0' "${!arr_ref}" < \
			<(find "$dir_path" -mindepth 1 -maxdepth 1 -printf "%f\0")
	}

	local pre_host_items=() pre_common_items=()
	if [[ -n "$dir_type" ]]; then
		local as_dir_var="as_${dir_type}_dir"
		map_dir_items "${!as_dir_var}" "pre_${dir_type}_items"
	else
		map_dir_items "$as_host_dir" "pre_host_items"
		map_dir_items "$as_common_dir" "pre_common_items"

		# Remove host prefixed items from common items
		for h_i in "${!pre_host_items[@]}"; do
			local path="${pre_host_items[$h_i]}"
			local basename_="${path##*/}"
			if [[ "$basename_" == "$HOST_PREFIX"* ]]; then
				for c_i in "${!pre_common_items[@]}"; do
					if [[ "${pre_common_items[$c_i]}" == "${basename_#"${HOST_PREFIX}"}" ]]; then
						log_info "Detect host prefer item: '${pre_common_items[$c_i]}'"
						unset "pre_common_items[$c_i]"
						break
					fi
				done
			fi
		done
	fi

	log_vars "pre_host_items[@]" "pre_common_items[@]"

	set_pre_items() {
		local -n arr_ref="$1"
		local mode="$2"

		mapfile -d $'\0' "${!arr_ref}" < <(comm "$mode" -z \
			<(printf "%s\0" "${pre_host_items[@]}" | sort -z) \
			<(printf "%s\0" "${pre_common_items[@]}" | sort -z))
	}

	# shellcheck disable=SC2034
	local union_items=() host_items=() common_items=()
	set_pre_items "union_items" "-12"
	set_pre_items "host_items" "-23"
	set_pre_items "common_items" "-13"
	log_vars "union_items[@]" "host_items[@]" "common_items[@]"

	for item_type in "union" "host" "common"; do
		local -n items="${item_type}_items"
		for item in "${items[@]}"; do
			[[ -z "$item" ]] && continue # TODO: Remove ("") empty element from arr b4 for
			local as_home_item="${a_home_dir}/${item}"
			# shellcheck disable=SC2034
			local as_common_item="${as_common_dir}/${item}"
			# shellcheck disable=SC2034
			local as_host_item="${as_host_dir}/${item}"

			if [[ "$item_type" == "union" ]]; then
				local as_var="as_host_item"
			else
				local as_var="as_${item_type}_item"
			fi
			local actual_item="${!as_var}"

			log_vars "item_type" "item" "as_var" "actual_item"
			# DIRECTORY
			if [[ -d "$actual_item" ]]; then
				log_info "Create directory: '$as_home_item'"
				if [[ "$item_type" == "host" && "$item" == "$HOST_PREFIX"* ]]; then
					renamed_as_home_item="${a_home_dir}/${item#"${HOST_PREFIX}"}"
					mkdir -p "$renamed_as_home_item"
					link "$as_home_item" "$item_type" "$as_home_item"
				else
					mkdir -p "$as_home_item"
					if [[ "$item_type" == "union" ]]; then
						link "$as_home_item"
					else
						# Exclusive home directory
						link "$as_home_item" "$item_type"
					fi
				fi
			# FILE
			elif [[ -f "$actual_item" ]]; then
				if [[ "$item_type" == "host" && -n "$prefix_base" ]]; then
					log_debug "Rename home link"
					# todo cache
					local basename_="${prefix_base##*/}"
					local original_dir="${basename_#"${HOST_PREFIX}"}"
					local as_home_item="${a_home_dir%/*}/${original_dir}"
				fi
				log_info "Link ${item_type^^} file: $actual_item -> $as_home_item"
				ln -sf "$actual_item" "$as_home_item"
			fi
		done
	done
}

add_user() {
	local passwd="$1"

	if [[ "$OS" == "debian" ]]; then
		$SUDO useradd -m -s "/bin/bash" -G "sudo" "$INSTALL_USER"
		printf "%s:%s" "$INSTALL_USER" "$passwd" | $SUDO chpasswd
		printf "%s ALL=(ALL) NOPASSWD: ALL\n" "$INSTALL_USER" >"/etc/sudoers.d/$INSTALL_USER"
	fi
}

##################################################
#                   Installers                   #
##################################################
do_setup_vultr() {
	# Clone dotfiles repository
	if ! is_cmd_exist git; then
		log_info "Installing Git..."
		install_package "git"
	fi

	if [[ "$TEST" == "true" ]]; then
		cp -r "$DOTFILES_LOCAL_REPO" "$DOTFILES_DIR"
		chown -R "$INSTALL_USER:$INSTALL_USER" "$DOTFILES_DIR"
	else
		git clone -b main "$DOTFILES_REPO" $DOTFILES_DIR
	fi

	log_info "Start linking..."
	link

	log_info "Start package installation..."
	while read -r pkg; do
		if ! is_cmd_exist "$pkg"; then
			log_info "Installing $pkg..."
			install_package "$pkg"
		fi
	done <"$PACKAGES_FILE"

	# Configure sshd
	if is_cmd_exist ufw; then
		log_info "Removing UFW..."
		$SUDO ufw disable
		remove_package "ufw"
	fi

	log_info "Configuring sshd..."
	local template_dir="$HOST_DIR/.template"
	local openssh_dir="/etc/ssh"
	[[ -e "${openssh_dir}/sshd_config" ]] && $SUDO rm "${openssh_dir}/sshd_config"
	$SUDO cp "${template_dir}/openssh-server/sshd_config" "${openssh_dir}/sshd_config"
	local port_num="$((1024 + RANDOM % (65535 - 1024 + 1)))"
	sudo sed -i "s/^Port [0-9]\+/Port $port_num/" "${openssh_dir}/sshd_config"
	printf "SSH port: %s\n" "$port_num" >>"$SECRET_FILE"
	local ssh_dir="${HOME_DIR}/.ssh"
	[[ ! -e "$ssh_dir" ]] && mkdir "$ssh_dir"
	chmod 700 "$ssh_dir"

	if [[ "$TEST" == "false" ]]; then
		log_info "Restarting sshd..."
		$SUDO systemctl restart sshd
	fi
}

do_setup_arch() {
	log_warn "dotfiles for arch - Not implemented yet.\nExiting..."
}

get_script_run_cmd() {
	local script_path="$1"
	local initialized="$2"
	local -n arr_ref="$3"

	arr_ref=(
		"$script_path"
		"--host"
		"$HOST"
	)
	[[ "$initialized" == "true" ]] && arr_ref+=("--initialized") || true
	[[ "$TEST" == "true" ]] && arr_ref+=("--test") || true
}

main() {
	log_info "Start installation script as ${COLOR["yellow"]}$(whoami)${COLOR["reset"]}..."

	log_vars \
		"INSTALL_USER" "DOTFILES_DIR" "DOTFILES_SRC_DIR" \
		"COMMON_DIR" "HOST_DIR" "HOST_PREFIX" \
		"HOST" "INITIALIZED" "TEST" "SUDO" "OS"

	if [[ "$INITIALIZED" == "true" ]]; then
		log_debug "Change current directory to $HOME_DIR"
		cd "$HOME_DIR"
		"do_setup_${HOST}"
	else
		if [[ -n "$SUDO" ]]; then
			sudo -v
		fi

		log_info "Create ${COLOR["yellow"]}${INSTALL_USER}${COLOR["reset"]}"
		local passwd
		passwd="$(get_random_str 64)"
		add_user "$passwd"

		log_info "Create secret file on $SECRET_FILE"
		printf "# This is secret file. Do NOT share with others.\n# Delete the file, once you complete the process.\n" >"$SECRET_FILE"
		printf "Password for %s: %s\n" "$INSTALL_USER" "$passwd" >>"$SECRET_FILE"
		chown "$INSTALL_USER" "$SECRET_FILE"
		chmod 600 "$SECRET_FILE"

		local run_cmd
		get_script_run_cmd "$(get_script_path)" "true" "run_cmd"
		log_vars "run_cmd[@]"

		log_info "Done user creation"
		sudo -u "$INSTALL_USER" -- "${run_cmd[@]}"
	fi
}

if [[ -z "${BASH_SOURCE[0]+x}" && "$INITIALIZED" == "false" ]]; then
	# Download script
	if [[ "$TEST" == "true" ]]; then
		log_info "Copying script from ${COLOR["yellow"]}local${COLOR["reset"]} repository..."
		cp "$DOTFILES_LOCAL_REPO/install.sh" "$INSTALLER_TMP_FILE"
	else
		log_info "Downloading script from ${COLOR["yellow"]}Git${COLOR["reset"]} repository..."
		curl -fsSL "$DOTFILES_SCRIPT_URL" -o "$INSTALLER_TMP_FILE"
	fi
	chmod +x "$INSTALLER_TMP_FILE"

	get_script_run_cmd "$INSTALLER_TMP_FILE" "false" "run_cmd"
	printf "Restarting...\n\n"
	"${run_cmd[@]}"
else
	main
fi
