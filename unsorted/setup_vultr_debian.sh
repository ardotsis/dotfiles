#!/bin/bash

read -p "New username: " USER_NAME
read -p "Password: " PASSWORD
read -p "SSH port: " SSH_PORT

# Update system
sudo apt update -y
sudo apt upgrade -y

# Add new user
sudo useradd -m "$USER_NAME"

# Set password for new user
echo "$USER_NAME:$PASSWORD" | sudo chpasswd

# Create "wheel" group
sudo groupadd wheel

# Add user to "wheel" group
sudo usermod -aG wheel "$USER_NAME"

# Allow "wheel" group to run sudo command without password
echo "%wheel ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/wheel

# Use default sshd_config
mv /etc/ssh/sshd_config /etc/ssh/sshd_config.old
cp /usr/share/openssh/sshd_config /etc/ssh/sshd_config

# Edit "sshd_config" file
sudo sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sudo sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config
sudo sed -i "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/" /etc/ssh/sshd_config
sudo sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config

sudo rm /etc/ssh/sshd_config.d/*.conf

# Restart ssh services
sudo systemctl restart sshd
sudo systemctl restart ssh  # for some case stupid

# Reset ufw settings
echo "y" | sudo ufw reset

# Set ports
sudo ufw allow "$SSH_PORT"/tcp
sudo ufw allow http/tcp
sudo ufw allow https/tcp
sudo ufw enable

# Install neovim
sudo apt install -y neovim

# Change current directory to new user's home
USER_HOME=$(eval echo "~$USER_NAME")

# Create ".ssh" directory as user
sudo mkdir -p "$USER_HOME/.ssh"
sudo chown "$USER_NAME:$USER_NAME" "$USER_HOME/.ssh"

# Change default shell to bash
chsh -s /bin/bash $USER_NAME

 # Uninstall all conflicting packages
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Run docker command without sudo
sudo usermod -aG docker $USER

sudo systemctl start docker
sudo systemctl enable docker
