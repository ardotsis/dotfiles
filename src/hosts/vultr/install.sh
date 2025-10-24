#!/bin/bash -eu
DOTFILES_REPO="https://github.com/ardotsis/dotfiles.git"
USERNAME="ardotsis"
IS_DOCKER_ENV=false

for arg in "$@"; do
	case $arg in
	--docker)
		IS_DOCKER_ENV=true
		;;
	esac
done

show_title() {
	local text="$1"
	local width=50
	local padding=$(((width - ${#text} - 2) / 2))
	local extra=$(((width - ${#text} - 2) % 2))

	printf "#%.0s" $(seq 1 "$width")
	echo
	printf "#%*s%s%*s#\n" "$padding" "" "$text" "$((padding + extra))" ""
	printf "#%.0s" $(seq 1 "$width")
	echo
}

is_root() {
	[ "$(id -u)" -eq 0 ]
}

is_cmd_exist() {
	local cmd="$1"

	if command -v "$cmd" >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

install_pkg() {
	local pkg="$1"

	apt-get install -y --no-install-recommends "$pkg"
}

rm_pkg() {
	local pkg="$1"

	apt-get remove -y "$pkg"
	apt-get purge -y "$pkg"
	apt-get autoremove -y
}

create_user() {
	local username="$1"
	local password="$2"

	useradd -m "$username"
	echo "$username:$password" | chpasswd
}

gen_password() {
	local length="$1"

	printf %s "$(tr -dc "A-Za-z0-9!?%=" </dev/urandom | head -c "$length")"
}

setup_sshd_config() {
	local ssh_port="$1"

	# Delete unnecessary files
	mv /etc/ssh/sshd_config.d /etc/ssh/sshd_config.d.bak

	# Backup current file and restore OpenSSH defaults.
	mv /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
	cp /usr/share/openssh/sshd_config /etc/ssh/sshd_config

	sed -i "s/#Port 22/Port $ssh_port/" /etc/ssh/sshd_config
	sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config
	sed -i "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/" /etc/ssh/sshd_config
	sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
}

main() {
	if $IS_DOCKER_ENV; then
		echo "Run script as Docker environment mode."
	fi

	if ! is_root; then
		echo "Please run this script as root."
		exit 1
	fi

	apt-get update
	apt-get upgrade -y

	if ! is_cmd_exist git; then
		show_title "Install Git"
		apt-get install git -y
	fi

	show_title "Create User"
	password=$(gen_password 32)
	create_user "$USERNAME" "$password"

	show_title "Uninstall UFW"
	if is_cmd_exist ufw; then
		echo "Disabling UFW.."
		ufw disable
		echo "Uninstalling UFW.."
		rm_pkg "ufw"
	fi

	show_title "Setup sshd config"
	ssh_port=$(shuf -i 1024-65535 -n 1)
	setup_sshd_config "$ssh_port"

	if ! $IS_DOCKER_ENV; then
		echo "Restarting sshd.."
		systemctl restart sshd
	fi

	echo
	printf "%s\n%s\n%s" \
		"New password for $USERNAME: $password" \
		"Copy this password and store it securely!" \
		"SSH port: $ssh_port"
}

main
