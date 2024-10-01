#!/bin/bash

USER_NAME=""             
PASSWORD=""
SSH_PORT="22"            

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

# Edit "sshd_config" file
sudo sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sudo sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config
sudo sed -i "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/" /etc/ssh/sshd_config
sudo sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config

# Restart ssh services
sudo systemctl restart sshd
sudo systemctl restart ssh

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


