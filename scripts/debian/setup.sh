#!/bin/bash

read -p "New username: " USER_NAME
read -p "Password: " PASSWORD
read -p "SSH port: " SSH_PORT

sudo apt update -y
sudo apt upgrade -y

################# Create new user #################
# Add new user
sudo useradd -m "$USER_NAME"
# Set password for user
echo "$USER_NAME:$PASSWORD" | sudo chpasswd
# Create "wheel" group
sudo groupadd wheel
# Add user to "wheel" group
sudo usermod -aG wheel "$USER_NAME"
# Allow run commands without sudo to "wheel" group
echo "%wheel ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/wheel

################# SSH configurations #################
# Use default "sshd_config"
mv /etc/ssh/sshd_config /etc/ssh/sshd_config.old
cp /usr/share/openssh/sshd_config /etc/ssh/sshd_config
# Remove unnecessary files
sudo rm /etc/ssh/sshd_config.d/*.conf
# Edit "sshd_config" file
sudo sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sudo sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config
sudo sed -i "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/" /etc/ssh/sshd_config
sudo sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
# Restart ssh services
sudo systemctl restart sshd
sudo systemctl restart ssh  # should i restart ssh service too..? (/・ω・)/

################# UFW configurations #################
# Reset ufw settings
echo "y" | sudo ufw reset
# Set ports
sudo ufw allow "$SSH_PORT"/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

################# Setup user #################
# Change current directory to new user's home
USER_HOME=$(eval echo "~$USER_NAME")
# Create ".ssh" directory
sudo mkdir -p "$USER_HOME/.ssh"
sudo chown "$USER_NAME:$USER_NAME" "$USER_HOME/.ssh"
# Change default shell to bash
chsh -s /bin/bash $USER_NAME

################# Install applications #################
sudo apt install -y neovim
