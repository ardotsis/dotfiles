#!/bin/bash
set -e -u -o pipefail -C

declare -ar _PARAM_0=("--host" "-h" "value" "")
declare -ar _PARAM_1=("--username" "-u" "value" "ardotsis")
declare -ar _PARAM_2=("--initialized" "-i" "flag" "false")
declare -ar _PARAM_3=("--test" "-t" "flag" "false")

declare -a _ARGS=("$@")
declare -A _PARAMS=()
_IS_ARGS_PARSED="false"

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
		local key="${long_name#--}"

		arg_index=0
		while ((arg_index < ${#_ARGS[@]})); do
			local some_arg="${_ARGS[$arg_index]}"
			if [[ "$some_arg" == "$long_name" || "$some_arg" == "$short_name" ]]; then
				if [[ "$type" == "value" ]]; then
					local value_index=$((arg_index + 1))
					if ((value_index < ${#_ARGS[@]})); then
						value="${_ARGS[$value_index]}"
					else
						show_missing_param_err "$short_name" "$long_name"
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

		if [[ -z "${!_PARAMS["$key"]+x}" ]]; then
			if [[ -n "$default_value" ]]; then
				_PARAMS["${long_name#--}"]="$default_value"
			else
				show_missing_param_err "$short_name" "$long_name"
			fi
		fi

		i=$((i + 1))
	done

	_IS_ARGS_PARSED="true"
}

_parse_args

get_arg() {
	local name="$1"

	if [[ "$_IS_ARGS_PARSED" == "false" ]]; then
		_parse_args
	fi

}

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

readonly DOTFILES_UPSTREAM="main"
readonly HOST_PREFIX="${HOST^^}_"

declare -A SYSTEM_PATH
SYSTEM_PATH["home"]="/home/$INSTALL_USER"
SYSTEM_PATH["tmp"]="/var/tmp"
SYSTEM_PATH["dotfiles_repo"]="${SYSTEM_PATH["home"]}/.dotfiles"
SYSTEM_PATH["dotfiles_dev_data"]="${SYSTEM_PATH["tmp"]}/.dotfiles"
SYSTEM_PATH["dotfiles_secret"]="${SYSTEM_PATH["home"]}/dotfiles_secret"
SYSTEM_PATH["dotfiles_tmp_installer"]="${SYSTEM_PATH["tmp"]}/install_dotfiles.sh"
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
URL["dotfiles_installer"]="https://raw.githubusercontent.com/ardotsis/dotfiles/refs/heads/main/install.sh"
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
	[[ "$TEST" == "true" ]] && arr_ref+=("--test") || true
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

##################################################
#                    Scripts                     #
##################################################
clone_dotfiles_repo() {
	if ! is_cmd_exist git; then
		install_package "git"
	fi

	if [[ "$TEST" == "true" ]]; then
		cp -r "${SYSTEM_PATH["dotfiles_dev_data"]}" "${SYSTEM_PATH["dotfiles_repo"]}"
		chown -R "$INSTALL_USER:$INSTALL_USER" "${SYSTEM_PATH["dotfiles_repo"]}"
	else
		git clone -b "$DOTFILES_UPSTREAM" "${URL["dotfiles_repo"]}" "${SYSTEM_PATH["dotfiles_repo"]}"
	fi
}

install_listed_packages() {
	while read -r pkg; do
		if ! is_cmd_exist "$pkg"; then
			install_package "$pkg"
		fi
	done <"${DOTFILES_PATH["packages"]}"
}

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

do_link() {
	local a_home_dir="${1-${SYSTEM_PATH["home"]}}"
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
			[[ -z "$item" ]] && continue
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

	local template_dir="${DOTFILES_PATH["common"]}/.template"

	log_info "Resetting openssh config directory..."
	local openssh_dir="/etc/ssh"
	local sshd_config="${openssh_dir}/sshd_config"
	[[ -e "$openssh_dir" ]] && $SUDO rm -rf "$openssh_dir"
	$SUDO install -d -m 0755 "$openssh_dir"
	$SUDO install -m 0600 "${template_dir}/openssh-server/sshd_config" "$sshd_config"

	# Generate port number
	local ssh_port="$((1024 + RANDOM % (65535 - 1024 + 1)))"
	sudo sed -i "s/^Port [0-9]\+/Port $ssh_port/" "$sshd_config"
	printf "SSH port: %s\n" "$ssh_port" >>"${SYSTEM_PATH["dotfiles_secret"]}"

	log_info "Resetting home ssh directory..."
	local ssh_dir="${SYSTEM_PATH["home"]}/.ssh"
	local authorized_keys="$ssh_dir/authorized_keys"
	[[ -e "$ssh_dir" ]] && rm -rf "$ssh_dir"
	install -d -m 0700 "$ssh_dir"
	install -m 600 /dev/null "$authorized_keys"

	log_info "Resetting iptables directory..."
	local iptables_dir="/etc/iptables"
	local rules_v4="${iptables_dir}/rules.v4"
	local rules_v6="${iptables_dir}/rules.v6"
	[[ -e "$iptables_dir" ]] && $SUDO rm -rf "$iptables_dir"
	$SUDO install -d -m 0755 "$iptables_dir"
	$SUDO install -m 644 "${template_dir}/iptables/rules.v4" "$rules_v4"
	$SUDO install -m 644 "${template_dir}/iptables/rules.v6" "$rules_v6"

	if [[ "$TEST" == "false" ]]; then
		log_info "Restarting sshd..."
		$SUDO systemctl restart sshd
	fi
}

do_setup_arch() {
	log_warn "dotfiles for arch - Not implemented yet.\nExiting..."
}

main() {
	log_info "Start installation script as ${COLOR["yellow"]}$(whoami)${COLOR["reset"]}..."

	# shellcheck disable=SC2153
	if [[ "$INITIALIZED" == "true" ]]; then
		log_debug "Change current directory to ${SYSTEM_PATH["home"]}"
		cd "${SYSTEM_PATH["home"]}"
		"do_setup_${HOST}"
	else
		if [[ -n "$SUDO" ]]; then
			sudo -v
		fi

		log_info "Create ${COLOR["yellow"]}${INSTALL_USER}${COLOR["reset"]}"
		local passwd
		passwd="$(get_random_str 64)"

		add_user "$INSTALL_USER" "$passwd"

		log_info "Create secret file on ${SYSTEM_PATH["dotfiles_secret"]}"
		printf "# This is secret file. Do NOT share with others.\n# Delete the file, once you complete the process.\n" >"${SYSTEM_PATH["dotfiles_secret"]}"
		printf "Password for %s: %s\n" "$INSTALL_USER" "$passwd" >>"${SYSTEM_PATH["dotfiles_secret"]}"
		chown "$INSTALL_USER:$INSTALL_USER" "${SYSTEM_PATH["dotfiles_secret"]}"
		chmod 600 "${SYSTEM_PATH["dotfiles_secret"]}"

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
		dev_install_file="${SYSTEM_PATH["dotfiles_dev_data"]}/install.sh"
		log_info "Copying script from ${COLOR["yellow"]}$dev_install_file${COLOR["reset"]}..."
		cp "$dev_install_file" "${SYSTEM_PATH["dotfiles_tmp_installer"]}"
	else
		log_info "Downloading script from ${COLOR["yellow"]}Git${COLOR["reset"]} repository..."
		curl -fsSL "${URL["dotfiles_installer"]}" -o "${SYSTEM_PATH["dotfiles_tmp_installer"]}"
	fi
	chmod +x "${SYSTEM_PATH["dotfiles_tmp_installer"]}"

	get_script_run_cmd "${SYSTEM_PATH["dotfiles_tmp_installer"]}" "false" "run_cmd"
	printf "Restarting...\n\n"
	"${run_cmd[@]}"
else
	main
	if [[ "$TEST" == "true" ]]; then
		log_debug "Test mode is enabled. Keeping docker container running..."
		tail -f /dev/null
	fi
fi
