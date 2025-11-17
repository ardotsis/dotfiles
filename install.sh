#!/bin/bash
set -e -u -o pipefail -C

##################################################
#                 Configurations                 #
##################################################
readonly USERNAME="ardotsis"

# Local paths
readonly HOME_DIR="/home/$USERNAME"
readonly DOTFILES_DIR="$HOME_DIR/.dotfiles"
readonly DOTFILES_SRC_DIR="$DOTFILES_DIR/dotfiles"
readonly COMMON_DIR="$DOTFILES_SRC_DIR/common"
readonly DOTFILES_SCRIPT_FILE="/var/tmp/install_dotfiles.sh"

# Endpoints
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
	"-s" | "--setup")
		readonly IS_SETUP="true"
		;;
	"-d" | "--debug")
		readonly DEBUG="true"
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

# Source: https://stackoverflow.com/a/28938235
declare -A COLOR=(
	# Reset
	["reset"]="\033[0m"

	# Regular Colors
	["black"]="\033[0;30m"
	["red"]="\033[0;31m"
	["green"]="\033[0;32m"
	["yellow"]="\033[0;33m"
	["blue"]="\033[0;34m"
	["purple"]="\033[0;35m"
	["cyan"]="\033[0;36m"
	["white"]="\033[0;37m"

	# Bold
	["bblack"]="\033[1;30m"
	["bred"]="\033[1;31m"
	["bgreen"]="\033[1;32m"
	["byellow"]="\033[1;33m"
	["bblue"]="\033[1;34m"
	["bpurple"]="\033[1;35m"
	["bcyan"]="\033[1;36m"
	["bwhite"]="\033[1;37m"

	# Underline
	["ublack"]="\033[4;30m"
	["ured"]="\033[4;31m"
	["ugreen"]="\033[4;32m"
	["uyellow"]="\033[4;33m"
	["ublue"]="\033[4;34m"
	["upurple"]="\033[4;35m"
	["ucyan"]="\033[4;36m"
	["uwhite"]="\033[4;37m"

	# Background
	["on_black"]="\033[40m"
	["on_red"]="\033[41m"
	["on_green"]="\033[42m"
	["on_yellow"]="\033[43m"
	["on_blue"]="\033[44m"
	["on_purple"]="\033[45m"
	["on_cyan"]="\033[46m"
	["on_white"]="\033[47m"

	# High Intensity
	["iblack"]="\033[0;90m"
	["ired"]="\033[0;91m"
	["igreen"]="\033[0;92m"
	["iyellow"]="\033[0;93m"
	["iblue"]="\033[0;94m"
	["ipurple"]="\033[0;95m"
	["icyan"]="\033[0;96m"
	["iwhite"]="\033[0;97m"

	# Bold High Intensity
	["biblack"]="\033[1;90m"
	["bired"]="\033[1;91m"
	["bigreen"]="\033[1;92m"
	["biyellow"]="\033[1;93m"
	["biblue"]="\033[1;94m"
	["bipurple"]="\033[1;95m"
	["bicyan"]="\033[1;96m"
	["biwhite"]="\033[1;97m"

	# High Intensity backgrounds
	["on_iblack"]="\033[0;100m"
	["on_ired"]="\033[0;101m"
	["on_igreen"]="\033[0;102m"
	["on_iyellow"]="\033[0;103m"
	["on_iblue"]="\033[0;104m"
	["on_ipurple"]="\033[0;105m"
	["on_icyan"]="\033[0;106m"
	["on_iwhite"]="\033[0;107m"
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

log() {
	local level="$1"
	local msg="$2"

	if [[ "$DEBUG" == "true" ]]; then
		local timestamp
		timestamp="$(date "+%Y-%m-%d %H:%M:%S")"
		printf "[%s] [%b%s%b] [%s] %b\n" "$timestamp" "${LOG_COLOR["${level}"]}" "${level^^}" "${COLOR["reset"]}" "${FUNCNAME[2]}" "$msg" >&2
	fi
}
log_debug() { log "debug" "$1"; }
log_info() { log "info" "$1"; }
log_warn() { log "warn" "$1"; }
log_error() { log "error" "$1"; }
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

	log "debug" "$msg"
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
						log_info "Host prefer item detected: '${pre_common_items[$c_i]}'"
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

add_ardotsis_chan() {
	local passwd="$1"

	print_header "Add ar.sis chan"
	if [[ "$OS" == "debian" ]]; then
		$SUDO useradd -m -s "/bin/bash" -G "sudo" "$USERNAME"
		printf "%s:%s" "$USERNAME" "$passwd" | $SUDO chpasswd
		printf "%s ALL=(ALL) NOPASSWD: ALL\n" "$USERNAME" >"/etc/sudoers.d/$USERNAME"
	fi
}

clone_dotfiles_repo() {
	local from="$1"

	log_info "Clone dotfiles repository from $from..."
	if [[ "$from" == "git" ]]; then
		git clone -b main "$DOTFILES_REPO" $DOTFILES_DIR
	elif [[ "$from" == "local" ]]; then
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

	install_package "neovim"

	print_header "Clone Dotfiles Repository"
	if [[ "$DEBUG" == "true" ]]; then
		clone_dotfiles_repo "local"
	else
		clone_dotfiles_repo "git"
	fi

	link
}

do_setup_arch() {
	log_error "do_setup_arch - Not implemented yet."
}

main() {
	log_info "Start installation script..."

	# Download install script when script invoked via pipeline
	if ! [[ -t 0 ]]; then
		log_info "Downloading script..."
		curl -fsSL "$DOTFILES_SCRIPT_URL" -o "$DOTFILES_SCRIPT_FILE"
		chmod +x "$DOTFILES_SCRIPT_FILE"
		cmd=(
			"$DOTFILES_SCRIPT_FILE"
			"--host"
			"$HOST"
			"$([[ "$DEBUG" == "true" ]] && printf "%s" "--debug")"
		)

		"${cmd[@]}"
		exit 0
	fi

	log_vars \
		"USERNAME" "DOTFILES_DIR" "DOTFILES_SRC_DIR" \
		"COMMON_DIR" "HOST_DIR" "HOST_PREFIX" \
		"HOST" "IS_SETUP" "DEBUG" "SUDO" "OS"

	if [[ "$IS_SETUP" == "true" ]]; then
		"do_setup_${HOST}"
	else
		sudo -v
		local passwd
		passwd=$(get_random_str 32)
		add_ardotsis_chan "$passwd"
		log_info "Password for $USERNAME: $passwd"

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
