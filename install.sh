#!/bin/bash
set -e -u -o pipefail -C

declare -r DEFAULT_USERNAME="ardotsis"

declare -ar _PARAM_0=("--host" "-h" "value" "")
declare -ar _PARAM_1=("--username" "-u" "value" "$DEFAULT_USERNAME")
declare -ar _PARAM_2=("--initialized" "-i" "flag" "false")
declare -ar _PARAM_3=("--local" "-l" "flag" "false")
declare -ar _PARAM_4=("--docker" "-d" "flag" "false")

_IS_ARGS_PARSED="false"
declare -A _PARAMS=()
declare -a _ARGS=("$@")

_parse_args() {
	show_missing_param_err() {
		printf "Please provide a value for '%s' (%s) parameter.\n" "$1" "$2"
		exit 1
	}

	local i=0
	while :; do
		local param_var="_PARAM_${i}"
		[[ -z "${!param_var+x}" ]] && break

		declare -n a_param="$param_var"
		local long_name="${a_param[0]}"
		local short_name="${a_param[1]}"
		local type="${a_param[2]}"
		local default_value="${a_param[3]}"
		local key="${long_name#--}" # 1. "--my-name" -> "my-name"
		key="${key//-/_}"           # 2. "my-name" -> "my_name"

		local arg_index=0
		while ((arg_index < ${#_ARGS[@]})); do
			local some_arg="${_ARGS[$arg_index]}"
			if [[ "$some_arg" == "$long_name" || "$some_arg" == "$short_name" ]]; then
				if [[ "$type" == "value" ]]; then
					local value_index=$((arg_index + 1))
					if ((value_index < ${#_ARGS[@]})); then
						value="${_ARGS[$value_index]}"
					else
						show_missing_param_err "$long_name" "$short_name"
					fi
					_PARAMS["$key"]="$value"
					_ARGS=("${_ARGS[@]:0:$arg_index}" "${_ARGS[@]:$arg_index+2}")
				elif [[ "$type" == "flag" ]]; then
					_PARAMS["$key"]="true"
				fi
				break
			fi
			arg_index=$((arg_index + 1))
		done

		if [[ -z "${_PARAMS["$key"]+x}" ]]; then
			if [[ -n "$default_value" ]]; then
				_PARAMS["$key"]="$default_value"
			else
				show_missing_param_err "$long_name" "$short_name"
			fi
		fi
		i=$((i + 1))
	done

	declare -r _IS_ARGS_PARSED="true"
}

get_arg() {
	local name="$1"
	if [[ "$_IS_ARGS_PARSED" == "false" ]]; then
		_parse_args
	fi
	printf %s "${_PARAMS[$name]}"
}

HOST=$(get_arg "host")
declare -r HOST
INSTALL_USER=$(get_arg "username")
declare -r INSTALL_USER
IS_LOCAL=$(get_arg "local")
declare -r IS_LOCAL
IS_DOCKER=$(get_arg "docker")
declare -r IS_DOCKER
IS_INITIALIZED=$(get_arg "initialized")
declare -r IS_INITIALIZED
CURRENT_USER="$(whoami)"
declare -r CURRENT_USER

declare -Ar HOST_OS=(
	["vultr"]="debian"
	["arch"]="arch"
	["mc"]="ubuntu"
)
declare -r OS="${HOST_OS["$HOST"]}"
declare -r HOST_PREFIX="${HOST^^}_"
declare -r HOME_DIR="/home/$INSTALL_USER"
declare -r HOME_SSH_DIR="$HOME_DIR/.ssh"
declare -r _TMP_DIR="/var/tmp"
declare -r GIT_REMOTE_BRANCH="main"
declare -r REPO_DIRNAME=".dotfiles"
declare -r REPO_DIR="$HOME_DIR/$REPO_DIRNAME"
declare -r SECRET_FILE="$HOME_DIR/SECRET_FILE"
declare -r DOCKER_VOL_DIR="$_TMP_DIR/${REPO_DIRNAME}_docker-volume"
declare -r TMP_INSTALL_SCRIPT_FILE="$_TMP_DIR/install_dotfiles.sh"

declare -A DOTFILES_REPO
DOTFILES_REPO["src"]="$REPO_DIR/dotfiles"
DOTFILES_REPO["common"]="${DOTFILES_REPO["src"]}/common"
DOTFILES_REPO["host"]="${DOTFILES_REPO["src"]}/hosts/$HOST"
DOTFILES_REPO["packages"]="${DOTFILES_REPO["src"]}/packages.txt"
DOTFILES_REPO["template"]="${DOTFILES_REPO["host"]}/template"
declare -r DOTFILES_REPO

declare -A OPENSSH_SERVER
OPENSSH_SERVER["etc"]="/etc/ssh"
OPENSSH_SERVER["sshd_config"]="${OPENSSH_SERVER["etc"]}/sshd_config"
declare -r OPENSSH_SERVER

declare -A IPTABLES
IPTABLES["etc"]="/etc/iptables"
IPTABLES["rules_v4"]="${IPTABLES["etc"]}/rules.v4"
IPTABLES["rules_v6"]="${IPTABLES["etc"]}/rules.v6"
declare -r IPTABLES

declare -Ar PERMISSION=(
	# Home items
	["$HOME_SSH_DIR"]="d $INSTALL_USER $INSTALL_USER 0700"
	["$HOME_SSH_DIR/authorized_keys"]="f $INSTALL_USER $INSTALL_USER 0600"
	# Script item
	["$SECRET_FILE"]="f $INSTALL_USER $INSTALL_USER 0600"
	["$TMP_INSTALL_SCRIPT_FILE"]="f $CURRENT_USER $CURRENT_USER 0700"
	# openssh-server
	["${OPENSSH_SERVER["etc"]}"]="d root root 0755"
	["${OPENSSH_SERVER["sshd_config"]}"]="f root root 0600"
	# iptables
	["${IPTABLES["etc"]}"]="d root root 0700"
	["${IPTABLES["rules_v4"]}"]="f root root 0600"
	["${IPTABLES["rules_v6"]}"]="f root root 0600"
)

declare -Ar URL=(
	["dotfiles_repo"]="https://github.com/ardotsis/dotfiles.git"
	["dotfiles_install_script"]="https://raw.githubusercontent.com/ardotsis/dotfiles/refs/heads/main/install.sh"
)

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

if [[ "$(id -u)" == "0" ]]; then
	declare -r SUDO=""
else
	if [[ "$OS" == "debian" ]]; then
		declare -r SUDO="sudo"
	fi
fi

##################################################
#                Common Functions                #
##################################################
_log() {
	local level="$1"
	local msg="$2"

	local caller="<Global>"
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
	[[ "$IS_LOCAL" == "true" ]] && arr_ref+=("--local") || true
	[[ "$IS_DOCKER" == "true" ]] && arr_ref+=("--docker") || true
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

	log_info "Installing $pkg..."
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

set_template() {
	local item_path="$1"
	local template_path="${2:-}"
	local file_url="${3:-}"

	read -r -a perm <<<"${PERMISSION[$item_path]}" # TODO: Don't use 'read'
	local type="${perm[0]}"
	local group="${perm[1]}"
	local user="${perm[2]}"
	local num="${perm[3]}"

	if [[ -e "$item_path" ]]; then
		log_info "Deleting $item_path..."
		$SUDO rm -rf "$item_path"
	fi

	local install_cmd=("install" "-m" "$num" "-o" "$user" "-g" "$group")

	if [[ -n "$SUDO" ]]; then
		install_cmd=("$SUDO" "${install_cmd[@]}")
	fi

	if [[ -n "$file_url" ]]; then
		curl_cmd=("curl" "-fsSL" "$file_url")
		install_cmd=("${install_cmd[@]}" "$item_path")
		"${curl_cmd[@]}" | "${install_cmd[@]}"
	else
		if [[ "$type" == "f" ]]; then
			if [[ -n "$template_path" ]]; then
				install_cmd=("${install_cmd[@]}" "$template_path" "$item_path")
			else
				install_cmd=("${install_cmd[@]}" "/dev/null" "$item_path")
			fi
		elif [[ "$type" == "d" ]]; then
			install_cmd=("${install_cmd[@]}" "$item_path" "-d")
		fi
		"${install_cmd[@]}"
	fi

	log_info "Create '$item_path' ($user:$group $num)"
}

##################################################
#                    Scripts                     #
##################################################
clone_dotfiles_repo() {
	if ! is_cmd_exist git; then
		install_package "git"
	fi

	if [[ "$IS_LOCAL" == "true" ]]; then
		ln -s "$DOCKER_VOL_DIR" "$REPO_DIR"
	else
		git clone -b "$GIT_REMOTE_BRANCH" "${URL["dotfiles_repo"]}" "$REPO_DIR"
	fi
}

install_listed_packages() {
	while read -r pkg; do
		if ! is_cmd_exist "$pkg"; then
			install_package "$pkg"
		fi
	done <"${DOTFILES_REPO["packages"]}"
}

convert_home_path() {
	local original_path="$1"
	local to="$2"

	# shellcheck disable=SC2034
	local home="$HOME_DIR"
	local common="${DOTFILES_REPO["common"]}"
	local host="${DOTFILES_REPO["host"]}"

	local from
	for home_type in "home" "common" "host"; do
		if [[ "$original_path" == "${!home_type}"* ]]; then
			from="$home_type"
		fi
	done

	# Convert home position
	printf "%s" "${original_path/#${!from}/${!to}}"
}

do_link() {
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
						pre_common_items=("${pre_common_items[@]:0:$c_i}" "${pre_common_items[@]:$c_i+1}")
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
			if [[ -z "$item" ]]; then
				log_warn "Empty element in $item_type items"
				continue
			fi
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

			# Directory
			if [[ -d "$actual_item" ]]; then
				if [[ "$item_type" == "host" && "$item" == "$HOST_PREFIX"* ]]; then
					renamed_as_home_item="${a_home_dir}/${item#"${HOST_PREFIX}"}"
					log_info "Create directory: '$renamed_as_home_item'"
					mkdir "$renamed_as_home_item"
					do_link "$as_home_item" "$item_type" "$as_home_item"
				else
					log_info "Create directory: '$as_home_item'"
					mkdir "$as_home_item"
					if [[ "$item_type" == "union" ]]; then
						do_link "$as_home_item"
					else
						do_link "$as_home_item" "$item_type"
					fi
				fi
			# File
			elif [[ -f "$actual_item" ]]; then
				if [[ "$item_type" == "host" && -n "$prefix_base" ]]; then
					log_debug "Rename home link"
					# TODO cache
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

##################################################
#                   Installers                   #
##################################################
do_setup_vultr() {
	log_info "Start setup vultr"
	clone_dotfiles_repo
	do_link
	install_listed_packages

	# Disable and uninstall UFW
	if is_cmd_exist ufw; then
		log_info "Uninstalling UFW..."
		$SUDO ufw disable
		remove_package "ufw"
	fi

	set_template "$HOME_SSH_DIR"
	set_template "$HOME_SSH_DIR/authorized_keys"

	local sshd_config_tmpl="${DOTFILES_REPO["template"]}/openssh-server/sshd_config"
	set_template "${OPENSSH_SERVER["etc"]}"
	set_template "${OPENSSH_SERVER["sshd_config"]}" "$sshd_config_tmpl"

	# Generate SSH port number
	local ssh_port="$((1024 + RANDOM % (65535 - 1024 + 1)))"
	sudo sed -i "s/^Port [0-9]\+/Port $ssh_port/" "${OPENSSH_SERVER["sshd_config"]}"
	printf "SSH port: %s\n" "$ssh_port" >>"$SECRET_FILE"

	# log_info "Resetting iptables directory..."
	# $SUDO install -d -m 0755 "$iptables_dir"
	# $SUDO install -m 0644 "${template_dir}/iptables/rules.v4" "$rules_v4"
	# $SUDO install -m 0644 "${template_dir}/iptables/rules.v6" "$rules_v6"
	# $SUDO install -m 0644 "${iptables_dir}/iptables-restore.service"

	if [[ "$IS_DOCKER" == "false" ]]; then
		log_info "Restarting sshd..."
		$SUDO systemctl restart sshd
		log_info "Reloading systemctl daemon..."
		$SUDO systemctl daemon-reload
		log_info "Enabling iptables-restore service..."
		$SUDO systemctl enable iptables-restore.service
	fi
}

do_setup_arch() {
	log_warn "dotfiles for arch - Not implemented yet.\nExiting..."
}

main() {
	log_info "Start installation script as ${COLOR["yellow"]}$CURRENT_USER${COLOR["reset"]}..."

	if [[ "$IS_INITIALIZED" == "true" ]]; then
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

		add_user "$INSTALL_USER" "$passwd"

		log_info "Create secret file on $SECRET_FILE"
		printf "# This is secret file. Do NOT share with others.\n# Delete the file, once you complete the process.\n" >"$SECRET_FILE"
		printf "Password for %s: %s\n" "$INSTALL_USER" "$passwd" >>"$SECRET_FILE"
		set_template "$SECRET_FILE"

		local run_cmd
		get_script_run_cmd "$(get_script_path)" "true" "run_cmd"
		log_vars "run_cmd[@]"

		log_info "Done user creation"
		sudo -u "$INSTALL_USER" -- "${run_cmd[@]}"
	fi
}

if [[ -z "${BASH_SOURCE[0]+x}" && "$IS_INITIALIZED" == "false" ]]; then
	# Download script
	if [[ "$IS_LOCAL" == "true" ]]; then
		dev_install_file="$DOCKER_VOL_DIR/install.sh"
		log_info "Copying script from ${COLOR["yellow"]}$dev_install_file${COLOR["reset"]}..."
		set_template "$TMP_INSTALL_SCRIPT_FILE" "$dev_install_file"
	else
		log_info "Downloading script from ${COLOR["yellow"]}Git${COLOR["reset"]} repository..."
		set_template "$TMP_INSTALL_SCRIPT_FILE" "" "${URL["dotfiles_repo"]}"
	fi

	get_script_run_cmd "$TMP_INSTALL_SCRIPT_FILE" "false" "run_cmd"
	printf "Restarting...\n\n"
	"${run_cmd[@]}"
else
	main
	if [[ "$IS_DOCKER" == "true" ]]; then
		log_debug "Docker mode is enabled. Keeping docker container running..."
		tail -f /dev/null
	fi
fi
