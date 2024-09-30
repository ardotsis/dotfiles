#!/bin/bash

USER_NAME=""             
PASSWORD=""
SSH_PORT="22"            
KEY_PASSPHRASE=""       

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
sudo sed -i "s/PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config

# Restart ssh services
sudo systemctl restart sshd
sudo systemctl restart ssh

# Reset ufw settings
echo "y" | sudo ufw reset

# Set ports
sudo ufw allow "$SSH_PORT"/tcp       # SSH用 (新しいポート)
sudo ufw allow http/tcp              # HTTP用
sudo ufw allow https/tcp             # HTTPS用
sudo ufw enable                      # UFWを有効化

# Install neovim
sudo apt install -y neovim

# Change current directory to new user's home
USER_HOME=$(eval echo "~$USER_NAME")

# Create ".ssh" directory as user
sudo mkdir -p "$USER_HOME/.ssh"
sudo chown "$USER_NAME:$USER_NAME" "$USER_HOME/.ssh"
sudo chmod 700 "$USER_HOME/.ssh"

# Generate SSH keys
sudo -u "$USER_NAME" ssh-keygen -t ed25519 -b 4096 -f "$USER_HOME/.ssh/id_rsa" -N "$KEY_PASSPHRASE" -C "$USER_NAME@server"

# Copy public kes to "authorized_keys" file
sudo -u "$USER_NAME" cat "$USER_HOME/.ssh/id_rsa.pub" >> "$USER_HOME/.ssh/authorized_keys"
sudo chmod 600 "$USER_HOME/.ssh/authorized_keys"

# Get private key's content
PRIVATE_KEY=$(sudo -u "$USER_NAME" cat "$USER_HOME/.ssh/id_rsa")

# Show private key
echo "$PRIVATE_KEY"
