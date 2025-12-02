#!/bin/bash
set -e -u -o pipefail -C

declare -a _ARGS=("$@")
declare -ar _PARAM_0=("HOST" "--host" "-h" "value" "")
declare -ar _PARAM_1=("_USERNAME" "--username" "-u" "value" "ardotsis")
declare -ar _PARAM_2=("INITIALIZED" "--initialized" "-i" "flag" "false")
declare -ar _PARAM_3=("TEST" "--test" "-t" "flag" "false")

_param_i=0
while :; do
	_param_var="_PARAM_${_param_i}"
	[[ -z "${!_param_var+x}" ]] && break

	declare -n _a_param="$_param_var"
	_global_var="${_a_param[0]}"
	_long_name="${_a_param[1]}"
	_short_name="${_a_param[2]}"
	_param_type="${_a_param[3]}"
	_default_value="${_a_param[4]}"

	_arg_index=0
	while ((_arg_index < ${#_ARGS[@]})); do
		_some_arg="${_ARGS[$_arg_index]}"
		if [[ "$_some_arg" == "$_long_name" || "$_some_arg" == "$_short_name" ]]; then
			if [[ "$_param_type" == "value" ]]; then
				_value_index=$(("$_arg_index" + 1))
				_value="${_ARGS[$_value_index]}" # todo: if unbound
				printf "Set value: %s -> %s\n" "$_global_var" "$_value"
				readonly "$_global_var"="$_value"
				_ARGS=("${_ARGS[@]:0:$_arg_index}" "${_ARGS[@]:$_arg_index+2}")
			elif [[ "$_param_type" == "flag" ]]; then
				readonly "$_global_var"="true"
			fi
			break
		fi
		_arg_index=$(("$_arg_index" + 1))
	done

	if [[ -z "${!_global_var+x}" ]]; then
		if [[ -n "$_default_value" ]]; then
			printf "Set default value: %s -> %s\n" "$_global_var" "$_default_value"
			readonly "$_global_var"="$_default_value"
		else
			printf "Please provide a value for '%s' (%s) parameter.\n" "$_long_name" "$_short_name"
			exit 1
		fi
	fi

	_param_i=$(("$_param_i" + 1))
done

# shellcheck disable=SC2153
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

# Set sudo mode
if [[ "$(id -u)" == "0" ]]; then
	readonly SUDO=""
else
	if [[ "$OS" == "debian" ]]; then
		readonly SUDO="sudo"
	fi
fi

readonly INSTALL_USER="$_USERNAME" # For readability
readonly HOST_PREFIX="${HOST^^}_"

declare -A SYSTEM_PATH
SYSTEM_PATH["home"]="/home/$INSTALL_USER"
SYSTEM_PATH["tmp"]="/var/tmp"
SYSTEM_PATH["dotfiles_repo"]="${SYSTEM_PATH["home"]}/.dotfiles"
SYSTEM_PATH["dotfiles_dev_a_param"]="${SYSTEM_PATH["tmp"]}/.dotfiles"
SYSTEM_PATH["dotfiles_secret"]="${SYSTEM_PATH["home"]}/dotfiles_secret"
SYSTEM_PATH["dotfiles_tmp_param_installer"]="${SYSTEM_PATH["tmp"]}/install_dotfiles.sh"
declare -r SYSTEM_PATH

declare -A DOTFILES_PATH
DOTFILES_PATH["root"]="${SYSTEM_PATH["home"]}/.dotfiles"
DOTFILES_PATH["src"]="${DOTFILES_PATH["root"]}/dotfiles"
DOTFILES_PATH["common"]="${DOTFILES_PATH["src"]}/common"
DOTFILES_PATH["host"]="${DOTFILES_PATH["src"]}/hosts/$HOST"
DOTFILES_PATH["packages"]="${DOTFILES_PATH["src"]}/packages.txt"
declare -r DOTFILES_PATH

declare -A URL
URL["dotfiles_repo"]="https://github.com/ardotsis/dotfiles.git"
URL["dotfiles_param_installer"]="https://raw.githubusercontent.com/ardotsis/dotfiles/refs/heads/main/install.sh"
declare -r URL

declare -Ar COLOR=(
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

declare -Ar LOG_COLOR=(
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
log_param_info() { _log "info" "$1"; }
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

add_user() {
	local username="$1"
	local passwd="$2"

	if [[ "$OS" == "debian" ]]; then
		$SUDO useradd -m -s "/bin/bash" -G "sudo" "$username"
		printf "%s:%s" "$username" "$passwd" | $SUDO chpasswd
		printf "%s ALL=(ALL) NOPASSWD: ALL\n" "$username" >"/etc/sudoers.d/$username"
	fi
}

##################################################
#                   Installers                   #
##################################################
convert_home_path() {
	local original_path="$1"
	local to="$2"

	# shellcheck disable=SC2034
	local home="${SYSTEM_PATH["home"]}"
	local common="${DOTFILES_PATH["common"]}"
	local host="${DOTFILES_PATH["host"]}"

	local from
	for home_type in "home" "common" "host"; do
		if [[ "$original_path" == "${!home_type}"* ]]; then
			from="$home_type"
		fi
	done

	# Convert home position
	printf "%s" "${original_path/#${!from}/${!to}}"
}

link() {
	local a_home_dir="${1-${SYSTEM_PATH["home"]}}"
	local dir_type="${2:-}"
	local prefix_base="${3:-}"

	log_vars "a_home_dir" "dir_type" "prefix_base"

	local as_host_dir as_common_dir
	as_host_dir="$(convert_home_path "$a_home_dir" "host")"
	as_common_dir="$(convert_home_path "$a_home_dir" "common")"
	log_vars "a_home_dir" "as_host_dir" "as_common_dir"

	map_dir_param_items() {
		local dir_path="$1"
		local -n arr_ref="$2"

		# Do NOT use double quotes with -d options to preserve null character
		mapfile -d $'\0' "${!arr_ref}" < \
			<(find "$dir_path" -mindepth 1 -maxdepth 1 -printf "%f\0")
	}

	local pre_host_param_items=() pre_common_param_items=()
	if [[ -n "$dir_type" ]]; then
		local as_dir_var="as_${dir_type}_dir"
		map_dir_param_items "${!as_dir_var}" "pre_${dir_type}_param_items"
	else
		map_dir_param_items "$as_host_dir" "pre_host_param_items"
		map_dir_param_items "$as_common_dir" "pre_common_param_items"

		# Remove host prefixed items from common items
		for h_param_i in "${!pre_host_param_items[@]}"; do
			local path="${pre_host_param_items[$h_param_i]}"
			local basename_="${path##*/}"
			if [[ "$basename_" == "$HOST_PREFIX"* ]]; then
				for c_param_i in "${!pre_common_param_items[@]}"; do
					if [[ "${pre_common_param_items[$c_param_i]}" == "${basename_#"${HOST_PREFIX}"}" ]]; then
						log_param_info "Detect host prefer item: '${pre_common_param_items[$c_param_i]}'"
						unset "pre_common_param_items[$c_param_i]"
						break
					fi
				done
			fi
		done
	fi

	log_vars "pre_host_param_items[@]" "pre_common_param_items[@]"

	set_pre_param_items() {
		local -n arr_ref="$1"
		local mode="$2"

		mapfile -d $'\0' "${!arr_ref}" < <(comm "$mode" -z \
			<(printf "%s\0" "${pre_host_param_items[@]}" | sort -z) \
			<(printf "%s\0" "${pre_common_param_items[@]}" | sort -z))
	}

	# shellcheck disable=SC2034
	local union_param_items=() host_param_items=() common_param_items=()
	set_pre_param_items "union_param_items" "-12"
	set_pre_param_items "host_param_items" "-23"
	set_pre_param_items "common_param_items" "-13"
	log_vars "union_param_items[@]" "host_param_items[@]" "common_param_items[@]"

	for item_type in "union" "host" "common"; do
		local -n items="${item_type}_param_items"
		for item in "${items[@]}"; do
			[[ -z "$item" ]] && continue # TODO: Remove ("") empty element from arr before for loop
			local as_home_param_item="${a_home_dir}/${item}"
			# shellcheck disable=SC2034
			local as_common_param_item="${as_common_dir}/${item}"
			# shellcheck disable=SC2034
			local as_host_param_item="${as_host_dir}/${item}"

			if [[ "$item_type" == "union" ]]; then
				local as_var="as_host_param_item"
			else
				local as_var="as_${item_type}_param_item"
			fi
			local actual_param_item="${!as_var}"

			log_vars "item_type" "item" "as_var" "actual_param_item"
			# DIRECTORY
			if [[ -d "$actual_param_item" ]]; then
				log_param_info "Create directory: '$as_home_param_item'"
				if [[ "$item_type" == "host" && "$item" == "$HOST_PREFIX"* ]]; then
					renamed_as_home_param_item="${a_home_dir}/${item#"${HOST_PREFIX}"}"
					mkdir -p "$renamed_as_home_param_item"
					link "$as_home_param_item" "$item_type" "$as_home_param_item"
				else
					mkdir -p "$as_home_param_item"
					if [[ "$item_type" == "union" ]]; then
						link "$as_home_param_item"
					else
						# Exclusive home directory
						link "$as_home_param_item" "$item_type"
					fi
				fi
			# FILE
			elif [[ -f "$actual_param_item" ]]; then
				if [[ "$item_type" == "host" && -n "$prefix_base" ]]; then
					log_debug "Rename home link"
					# todo cache
					local basename_="${prefix_base##*/}"
					local original_dir="${basename_#"${HOST_PREFIX}"}"
					local as_home_param_item="${a_home_dir%/*}/${original_dir}"
				fi
				log_param_info "Link ${item_type^^} file: $actual_param_item -> $as_home_param_item"
				ln -sf "$actual_param_item" "$as_home_param_item"
			fi
		done
	done
}

do_setup_vultr() {
	# Clone dotfiles repository
	if ! is_cmd_exist git; then
		log_param_info "Installing Git..."
		install_package "git"
	fi

	if [[ "$TEST" == "true" ]]; then
		cp -r "${SYSTEM_PATH["dotfiles_dev_a_param"]}" "${SYSTEM_PATH["dotfiles_repo"]}"
		chown -R "$INSTALL_USER:$INSTALL_USER" "${SYSTEM_PATH["dotfiles_repo"]}"
	else
		git clone -b main "${URL["dotfiles_repo"]}" "${SYSTEM_PATH["dotfiles_repo"]}"
	fi

	log_param_info "Start linking..."
	link

	log_param_info "Start package installation..."
	while read -r pkg; do
		if ! is_cmd_exist "$pkg"; then
			log_param_info "Installing $pkg..."
			install_package "$pkg"
		fi
	done <"${DOTFILES_PATH["packages"]}"

	# Configure sshd
	if is_cmd_exist ufw; then
		log_param_info "Removing UFW..."
		$SUDO ufw disable
		remove_package "ufw"
	fi

	log_param_info "Configuring sshd..."
	local template_dir="${DOTFILES_PATH["host"]}/.template"
	local openssh_dir="/etc/ssh"
	[[ -e "${openssh_dir}/sshd_config" ]] && $SUDO rm "${openssh_dir}/sshd_config"
	$SUDO cp "${template_dir}/openssh-server/sshd_config" "${openssh_dir}/sshd_config"
	local port_num="$((1024 + RANDOM % (65535 - 1024 + 1)))"
	sudo sed -i "s/^Port [0-9]\+/Port $port_num/" "${openssh_dir}/sshd_config"
	printf "SSH port: %s\n" "$port_num" >>"${SYSTEM_PATH["dotfiles_secret"]}"
	local ssh_dir="${SYSTEM_PATH["home"]}/.ssh"
	[[ ! -e "$ssh_dir" ]] && mkdir "$ssh_dir"
	chmod 700 "$ssh_dir"

	if [[ "$TEST" == "false" ]]; then
		log_param_info "Restarting sshd..."
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
		"--username"
		"$INSTALL_USER"
	)
	[[ "$initialized" == "true" ]] && arr_ref+=("--initialized") || true
	[[ "$TEST" == "true" ]] && arr_ref+=("--test") || true
}

main() {
	log_param_info "Start installation script as ${COLOR["yellow"]}$(whoami)${COLOR["reset"]}..."

	log_vars \
		"INSTALL_USER" "DOTFILES_PATH[\"src\"]" \
		"DOTFILES_PATH[\"host\"]" "HOST_PREFIX" \
		"HOST" "INITIALIZED" "TEST" "SUDO" "OS"

	if [[ "$INITIALIZED" == "true" ]]; then
		log_debug "Change current directory to ${SYSTEM_PATH["home"]}"
		cd "${SYSTEM_PATH["home"]}"
		"do_setup_${HOST}"
	else
		if [[ -n "$SUDO" ]]; then
			sudo -v
		fi

		log_param_info "Create ${COLOR["yellow"]}${INSTALL_USER}${COLOR["reset"]}"
		local passwd
		passwd="$(get_random_str 64)"

		add_user "$INSTALL_USER" "$passwd"

		log_param_info "Create secret file on ${SYSTEM_PATH["dotfiles_secret"]}"
		printf "# This is secret file. Do NOT share with others.\n# Delete the file, once you complete the process.\n" >"${SYSTEM_PATH["dotfiles_secret"]}"
		printf "Password for %s: %s\n" "$INSTALL_USER" "$passwd" >>"${SYSTEM_PATH["dotfiles_secret"]}"
		chown "$INSTALL_USER" "${SYSTEM_PATH["dotfiles_secret"]}"
		chmod 600 "${SYSTEM_PATH["dotfiles_secret"]}"

		local run_cmd
		get_script_run_cmd "$(get_script_path)" "true" "run_cmd"
		log_vars "run_cmd[@]"

		log_param_info "Done user creation"
		sudo -u "$INSTALL_USER" -- "${run_cmd[@]}"
	fi
}

if [[ -z "${BASH_SOURCE[0]+x}" && "$INITIALIZED" == "false" ]]; then
	# Download script
	if [[ "$TEST" == "true" ]]; then
		dev_param_install_file="${SYSTEM_PATH["dotfiles_dev_a_param"]}/install.sh"
		log_param_info "Copying script from ${COLOR["yellow"]}$dev_param_install_file${COLOR["reset"]}..."
		cp "$dev_param_install_file" "${SYSTEM_PATH["dotfiles_tmp_param_installer"]}"
	else
		log_param_info "Downloading script from ${COLOR["yellow"]}Git${COLOR["reset"]} repository..."
		curl -fsSL "${URL["dotfiles_param_installer"]}" -o "${SYSTEM_PATH["dotfiles_tmp_param_installer"]}"
	fi
	chmod +x "${SYSTEM_PATH["dotfiles_tmp_param_installer"]}"

	get_script_run_cmd "${SYSTEM_PATH["dotfiles_tmp_param_installer"]}" "false" "run_cmd"
	printf "Restarting...\n\n"
	"${run_cmd[@]}"
else
	main
fi
