#!/bin/bash
set -e -u -o pipefail -C

declare -r DEFAULT_USERNAME="ardotsis"

declare -ar _PARAM_0=("--host" "-h" "value" "")
declare -ar _PARAM_1=("--username" "-u" "value" "$DEFAULT_USERNAME")
declare -ar _PARAM_2=("--docker" "-d" "flag" "false")
declare -ar _PARAM_3=("--debug" "-de" "flag" "false")
declare -A _PARAMS=()
declare -a _ARGS=("$@")
declare _IS_ARGS_PARSED="false"

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
IS_DOCKER=$(get_arg "docker")
declare -r IS_DOCKER
IS_DEBUG=$(get_arg "debug")
declare -r IS_DEBUG
CURRENT_USER="$(whoami)"
declare -r CURRENT_USER

declare -r HOME_DIR="/home/$INSTALL_USER"
declare -r TMP_DIR="/var/tmp"
declare -r REPO_DIRNAME=".dotfiles"
declare -r DEV_REPO_DIR="$TMP_DIR/${REPO_DIRNAME}_dev"
declare -r TMP_INSTALL_SCRIPT_FILE="$TMP_DIR/install_dotfiles.sh"
declare -r GIT_REMOTE_BRANCH="main"
declare -r HOST_PREFIX="${HOST^^}#"
declare -Ar HOST_OS=(
	["vultr"]="debian"
	["arch"]="arch"
	["mc"]="ubuntu"
)
declare -r OS="${HOST_OS["$HOST"]}"
declare -r PASSWD_LENGTH=72

declare -A DOTFILES_REPO
DOTFILES_REPO["_dir"]="$HOME_DIR/$REPO_DIRNAME"
DOTFILES_REPO["src"]="${DOTFILES_REPO["_dir"]}/dotfiles"
DOTFILES_REPO["common"]="${DOTFILES_REPO["src"]}/common"
DOTFILES_REPO["host"]="${DOTFILES_REPO["src"]}/hosts/$HOST"
DOTFILES_REPO["packages"]="${DOTFILES_REPO["src"]}/packages.txt"
DOTFILES_REPO["template"]="${DOTFILES_REPO["host"]}/.template"
declare -r DOTFILES_REPO

declare -A APP
APP["_dir"]="$HOME_DIR/dotfiles-app"
APP["secret"]="${APP["_dir"]}/DOTFILES_SECRET_FILE"
APP["backups"]="${APP["_dir"]}/backups"
declare -A APP

declare -A HOME_SSH
HOME_SSH["_dir"]="$HOME_DIR/.ssh"
HOME_SSH["authorized_keys"]="${HOME_SSH["_dir"]}/authorized_keys"
HOME_SSH["config"]="${HOME_SSH["_dir"]}/config"
declare -r HOME_SSH

declare -A OPENSSH_SERVER
OPENSSH_SERVER["etc"]="/etc/ssh"
OPENSSH_SERVER["sshd_config"]="${OPENSSH_SERVER["etc"]}/sshd_config"
declare -r OPENSSH_SERVER

declare -A IPTABLES
IPTABLES["etc"]="/etc/iptables"
IPTABLES["rules_v4"]="${IPTABLES["etc"]}/rules.v4"
IPTABLES["rules_v6"]="${IPTABLES["etc"]}/rules.v6"
IPTABLES["service"]="/etc/systemd/system/iptables-restore.service"
declare -r IPTABLES

declare -Ar PERMISSION=(
	["$TMP_INSTALL_SCRIPT_FILE"]="f root root 0755"

	["${APP["_dir"]}"]="d $INSTALL_USER $INSTALL_USER 0700"
	["${APP["secret"]}"]="f $INSTALL_USER $INSTALL_USER 0600"
	["${APP["backups"]}"]="d $INSTALL_USER $INSTALL_USER 0700"

	["${HOME_SSH["_dir"]}"]="d $INSTALL_USER $INSTALL_USER 0700"
	["${HOME_SSH["authorized_keys"]}"]="f $INSTALL_USER $INSTALL_USER 0600"
	["${HOME_SSH["config"]}"]="f $INSTALL_USER $INSTALL_USER 0600"

	["${OPENSSH_SERVER["etc"]}"]="d root root 0755"
	["${OPENSSH_SERVER["sshd_config"]}"]="f root root 0600"

	["${IPTABLES["etc"]}"]="d root root 0755"
	["${IPTABLES["rules_v4"]}"]="f root root 0644"
	["${IPTABLES["rules_v6"]}"]="f root root 0644"
	["${IPTABLES["service"]}"]="f root root 0644"
)

declare -Ar URL=(
	["dotfiles_repo"]="https://github.com/ardotsis/dotfiles.git"
	["dotfiles_install_script"]="https://raw.githubusercontent.com/ardotsis/dotfiles/refs/heads/main/install.sh"
)

declare -Ar CLR=(
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

declare -Ar LOG_CLR=(
	["debug"]="${CLR["white"]}"
	["info"]="${CLR["green"]}"
	["warn"]="${CLR["yellow"]}"
	["error"]="${CLR["red"]}"
	["var"]="${CLR["purple"]}"
	["value"]="${CLR["cyan"]}"
	["path"]="${CLR["yellow"]}"
	["highlight"]="${CLR["red"]}"
)

if [[ "$(id -u)" == "0" ]]; then
	declare -r SUDO=""
else
	declare -r SUDO="sudo"
fi

##################################################
#                Common Functions                #
##################################################
_log() {
	local level="$1"
	local msg="$2"

	# TODO: fix lineno
	local caller="_GLOBAL_"
	for funcname in "${FUNCNAME[@]}"; do
		[[ "$funcname" == "_log" ]] && continue
		[[ "$funcname" == "log_"* ]] && continue
		[[ "$funcname" == "main" ]] && continue
		caller="$funcname"
		break
	done

	local timestamp
	timestamp="$(date "+%Y-%m-%d %H:%M:%S")"
	printf "[%s] [%b%s%b] [%s:%s] (%s) %b\n" "$timestamp" "${LOG_CLR["${level}"]}" "${level^^}" "${CLR["reset"]}" "$caller" "${BASH_LINENO[0]}" "$CURRENT_USER" "$msg" >&2
}
log_debug() { _log "debug" "$1"; }
log_info() { _log "info" "$1"; }
log_warn() { _log "warn" "$1"; }
log_error() { _log "error" "$1"; }
log_vars() {
	local var_names=("$@")

	local msg=""
	for var_name in "${var_names[@]}"; do
		fmt="${LOG_CLR["var"]}\$$var_name${CLR["reset"]}=\"${LOG_CLR["value"]}${!var_name}${CLR["reset"]}\""
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
	local -n arr_ref="$2"

	arr_ref=(
		"$script_path"
		"--host"
		"$HOST"
		"--username"
		"$INSTALL_USER"
	)
	# TODO: Detect flag(s) automatically
	[[ "$IS_DOCKER" == "true" ]] && arr_ref+=("--docker") || true
	[[ "$IS_DEBUG" == "true" ]] && arr_ref+=("--debug") || true
}

is_cmd_exist() {
	local cmd="$1"

	if command -v "$cmd" >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

is_usr_exist() {
	local username="$1"

	if id "$username" >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

_get_random_str() {
	local length="$1"
	local chars="$2"

	# Use printf to flush buffer forcefully
	printf "%s" "$(tr -dc "$chars" </dev/urandom | head -c "$length")"
}

get_random_str() {
	local length="$1"
	_get_random_str "$length" "A-Za-z0-9!?%="
}

get_safe_random_str() {
	local length="$1"
	_get_random_str "$length" "A-Za-z0-9"
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

backup_item() {
	local item_path="$1"

	local parent_dir basename dst timestamp
	parent_dir="$(dirname "$item_path")"
	basename="$(basename "$item_path")"
	timestamp="$(date "+%Y-%m-%d_%H-%M-%S")"
	dst="${APP["backups"]}/${basename}_${timestamp}.tgz"

	log_info "Create backup: \"${LOG_CLR["path"]}$dst${CLR["reset"]}\""

	$SUDO tar czvf "$dst" -C "$parent_dir" "$basename"
}

set_perm_item() {
	local template_uri="$1"
	local item_path="$2"

	read -r -a perm <<<"${PERMISSION[$item_path]}" # TODO: Don't use 'read'
	local type="${perm[0]}"
	local group="${perm[1]}"
	local user="${perm[2]}"
	local num="${perm[3]}"

	local is_curled="false"
	local install_cmd=("install" "-m" "$num" "-o" "$user" "-g" "$group")

	if [[ -n "$SUDO" ]]; then
		install_cmd=("$SUDO" "${install_cmd[@]}")
	fi

	if [[ -e "$item_path" ]]; then
		backup_item "$item_path"
		$SUDO rm -rf "$item_path"
	fi

	# Source: Internet file
	if [[ "$template_uri" == "https://"* ]]; then
		curl_file_path="$TMP_DIR/$(get_random_str 16)"
		curl -fsSL "$template_uri" >"$curl_file_path"
		install_cmd=("${install_cmd[@]}" "$curl_file_path" "$item_path")
		is_curled="true"
	# Source: Local file
	else
		if [[ "$type" == "f" ]]; then
			if [[ -n "$template_uri" ]]; then
				install_cmd=("${install_cmd[@]}" "$template_uri" "$item_path")
			else
				install_cmd=("${install_cmd[@]}" "/dev/null" "$item_path")
			fi
		elif [[ "$type" == "d" ]]; then
			install_cmd=("${install_cmd[@]}" "$item_path" "-d")
		fi
	fi

	# Execute "install" command
	log_debug "Create item: \"${LOG_CLR["path"]}$item_path${CLR["reset"]}\" (template=\"${LOG_CLR["path"]}$template_uri${CLR["reset"]}\" owner=$user, group=$group, mode=$num)"
	"${install_cmd[@]}"

	if [[ $is_curled == "true" ]]; then
		rm -rf "$curl_file_path"
	fi
}

##################################################
#                    Scripts                     #
##################################################
clone_dotfiles_repo() {
	if ! is_cmd_exist git; then
		install_package "git"
	fi

	if [[ "$IS_DEBUG" == "true" ]]; then
		log_debug "New debug symlink: \"${LOG_CLR["path"]}${DOTFILES_REPO["_dir"]}${CLR["reset"]}\" -> \"${LOG_CLR["path"]}$DEV_REPO_DIR${CLR["reset"]}\""
		ln -s "$DEV_REPO_DIR" "${DOTFILES_REPO["_dir"]}"
	else
		git clone -b "$GIT_REMOTE_BRANCH" "${URL["dotfiles_repo"]}" "${DOTFILES_REPO["_dir"]}"
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

	local as_host_dir as_common_dir
	as_host_dir="$(convert_home_path "$a_home_dir" "host")"
	as_common_dir="$(convert_home_path "$a_home_dir" "common")"
	# log_vars "a_home_dir" "as_host_dir" "as_common_dir"

	map_dir_items() {
		local dir_path="$1"
		local -n arr_ref="$2"

		# Do NOT use double quotes with -d options to preserve null character
		mapfile -d $'\0' "${!arr_ref}" < \
			<(find "$dir_path" -mindepth 1 -maxdepth 1 -printf "%f\0")
	}

	log_debug "Processing \"${LOG_CLR["path"]}$a_home_dir${CLR["reset"]}\"..."

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
			local basename_
			basename_="$(basename "$path")"
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
				# TODO: "Empty element in $item_type items"
				continue
			fi

			local as_home_item="${a_home_dir}/${item}"
			# shellcheck disable=SC2034
			local as_common_item="${as_common_dir}/${item}"
			# shellcheck disable=SC2034
			local as_host_item="${as_host_dir}/${item}"

			if [[ -e "$as_home_item" ]]; then
				log_debug "Backup: $as_home_item"
				backup_item "$as_home_item"
				rm -rf "$as_home_item"
			fi

			if [[ "$item_type" == "union" ]]; then
				local as_var="as_host_item"
			else
				local as_var="as_${item_type}_item"
			fi
			local actual_item="${!as_var}"

			# Directory
			if [[ -d "$actual_item" ]]; then
				if [[ "$item_type" == "host" && "$item" == "$HOST_PREFIX"* ]]; then
					renamed_as_home_item="${a_home_dir}/${item#"${HOST_PREFIX}"}"
					log_debug "Create directory: \"${LOG_CLR["path"]}$renamed_as_home_item${CLR["reset"]}\""
					mkdir "$renamed_as_home_item"
					do_link "$as_home_item" "$item_type" "$as_home_item"
				else
					log_debug "Create directory: \"${LOG_CLR["path"]}$as_home_item${CLR["reset"]}\""
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
					# TODO cache
					local basename_="${prefix_base##*/}"
					local original_dir="${basename_#"${HOST_PREFIX}"}"
					local as_home_item="${a_home_dir%/*}/${original_dir}"
				fi
				log_info "New symlink: \"${LOG_CLR["path"]}$as_home_item${CLR["reset"]}\" -> (${item_type^^}) \"${LOG_CLR["path"]}$actual_item${CLR["reset"]}\""
				ln -sf "$actual_item" "$as_home_item"
			fi
		done
	done
}

##################################################
#                   Installers                   #
##################################################
do_setup_vultr() {
	log_info "Clone dotfiles repository"
	clone_dotfiles_repo
	log_info "Start linking dotfiles"
	do_link
	log_info "Install packages"
	install_listed_packages

	# Uninstall UFW
	if is_cmd_exist ufw; then
		log_info "Uninstall UFW"
		$SUDO ufw disable
		remove_package "ufw"
	fi

	set_perm_item "" "${HOME_SSH["_dir"]}"

	# Install files / directories
	# SSH
	set_perm_item "" "${HOME_SSH["_dir"]}"
	set_perm_item "" "${HOME_SSH["authorized_keys"]}"
	set_perm_item "" "${HOME_SSH["config"]}"
	# openssh-server
	set_perm_item "${DOTFILES_REPO["template"]}/openssh-server/sshd_config" "${OPENSSH_SERVER["sshd_config"]}"
	# iptables
	local tmpl_iptables="${DOTFILES_REPO["template"]}/iptables"
	set_perm_item "" "${IPTABLES["etc"]}"
	set_perm_item "" "${IPTABLES["rules_v4"]}" "$tmpl_iptables/rules.v4"
	set_perm_item "$tmpl_iptables/rules.v6" "${IPTABLES["rules_v6"]}"
	set_perm_item "$tmpl_iptables/iptables-restore.service" "${IPTABLES["service"]}"

	# Change SSH port
	local ssh_port="$((1024 + RANDOM % (65535 - 1024 + 1)))"
	$SUDO sed -i "s/^Port [0-9]\+/Port $ssh_port/" "${OPENSSH_SERVER["sshd_config"]}"
	$SUDO sed -i "s|^-A INPUT -p tcp --dport [0-9]\+ -j ACCEPT$|-A INPUT -p tcp --dport $ssh_port -j ACCEPT|" "${IPTABLES["rules_v4"]}"

	# Change default shell to Zsh
	log_info "Change default shell to Zsh"
	$SUDO chsh -s "$(which zsh)" "$(whoami)"

	# Oh My Zsh installation script
	log_info "Executing oh-my-zsh installation script..."
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

	# Docker installation script
	if [[ "$IS_DOCKER" == "false" ]]; then
		log_info "Executing Docker installation script.."
		sh -c "$(curl -fsSL https://get.docker.com)"
	fi

	# Prepare SSH config for "client" and "Git"
	# [ Client ] --> [ This Host ]
	local ssh_publickey
	if [[ "$IS_DEBUG" == "true" ]]; then
		ssh_publickey="some_ssh_publickey"
	else
		read -r -p "Paste SSH public key: " ssh_publickey </dev/tty
	fi
	printf "%s" "$ssh_publickey" >>"${HOME_SSH["authorized_keys"]}"

	{
		printf "# Config template for SSH client\n"
		printf "Host %s\n" "$HOST"
		printf "  HostName %s\n" "$(curl -fsSL https://api.ipify.org)"
		printf "  Port %s\n" "$ssh_port"
		printf "  User %s\n" "$INSTALL_USER"
		printf "  IdentityFile ~/.ssh/%s\n" "$HOST"
		printf "  IdentitiesOnly yes\n"
		printf "\n"
	} >>"${APP["secret"]}"

	# [ This Host ] --> [ Git ]
	local ssh_git_passphrase
	ssh_git_passphrase="$(get_random_str $PASSWD_LENGTH)"
	local git_filename="git"
	ssh-keygen -t ed25519 -b 4096 -f "${HOME_SSH["_dir"]}/$git_filename" -N "$ssh_git_passphrase"

	{
		printf "# SSH passphrase for Git\n%s\n\n" "$ssh_git_passphrase"
		printf "# SSH public key for Git\n"
		cat "${HOME_SSH["_dir"]}/${git_filename}.pub"
		printf "\n"
	} >>"${APP["secret"]}"

	{
		printf "Host git\n"
		printf "  HostName github.com\n"
		printf "  User git\n"
		printf "  IdentityFile ~/.ssh/%s\n" "$git_filename"
		printf "  IdentitiesOnly yes\n"
		printf "\n"
	} >>"${HOME_SSH["config"]}"

	rm -f "${HOME_SSH["_dir"]}/${git_filename}.pub"

	# Reload services
	if [[ "$IS_DOCKER" == "false" ]]; then
		log_info "Restart sshd service"
		$SUDO systemctl restart sshd
		log_info "Reload systemctl daemon"
		$SUDO systemctl daemon-reload
		log_info "Enable iptables-restore service"
		$SUDO systemctl enable iptables-restore.service
	fi
}

do_setup_arch() {
	log_warn "dotfiles for arch - Not implemented yet"
}

# Naming "_main" to prevent the log function from logging it as "_GLOBAL_"
_main() {
	log_vars "HOST" "INSTALL_USER" "CURRENT_USER" "IS_DOCKER" "IS_DEBUG"

	if is_usr_exist "$INSTALL_USER"; then
		cd "$HOME_DIR"
		"do_setup_${HOST}"
	else
		log_info "Create user: ${LOG_CLR["highlight"]}${INSTALL_USER}${CLR["reset"]}"

		# Update sudo credentials for non-root user
		if [[ -n "$SUDO" ]]; then
			sudo -v
		fi

		# Create user
		local passwd
		passwd="$(get_random_str $PASSWD_LENGTH)"
		add_user "$INSTALL_USER" "$passwd"

		# Create app directory
		set_perm_item "" "${APP["_dir"]}"
		set_perm_item "" "${APP["backups"]}"
		set_perm_item "" "${APP["secret"]}"
		printf "# Do NOT share with others!\n# Delete this file, once you complete the process.\n\n" >>"${APP["secret"]}"
		printf "# Password for %s\n%s\n\n" "$INSTALL_USER" "$passwd" >>"${APP["secret"]}"

		local run_cmd
		get_script_run_cmd "$(get_script_path)" "run_cmd"
		log_info "Done user creation. Starting install script as ${LOG_CLR["highlight"]}$INSTALL_USER${CLR["reset"]}..."
		log_vars "run_cmd[@]"
		sudo -u "$INSTALL_USER" -- "${run_cmd[@]}"
	fi
}

log_debug "================ Begin ${LOG_CLR["highlight"]}$CURRENT_USER${CLR["reset"]} session ================"
if [[ -z "${BASH_SOURCE[0]+x}" ]]; then
	log_info "Download script"
	if [[ "$IS_DEBUG" == "true" ]]; then
		dev_install_file="$DEV_REPO_DIR/install.sh"
		log_debug "Copy script from \"${LOG_CLR["path"]}$dev_install_file${CLR["reset"]}\""
		set_perm_item "$dev_install_file" "$TMP_INSTALL_SCRIPT_FILE"
	else
		log_debug "Download script from \"${LOG_CLR["path"]}Git${CLR["reset"]}\" repository"
		set_perm_item "${URL["dotfiles_install_script"]}" "$TMP_INSTALL_SCRIPT_FILE"
	fi

	get_script_run_cmd "$TMP_INSTALL_SCRIPT_FILE" "run_cmd"
	log_info "Restarting...\n"
	"${run_cmd[@]}"
else
	_main
	if [[ "$IS_DOCKER" == "true" ]]; then
		log_info "Docker mode is enabled. Keeping docker container running..."
		tail -f /dev/null
	fi
fi
log_debug "================ End ${LOG_CLR["highlight"]}$CURRENT_USER${CLR["reset"]} session ================"
