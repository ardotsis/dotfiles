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
sudo systemctl restart ssh  # should i restart ssh service too?

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
# Create "authorized_keys" file
sudo -u $USER_NAME touch "$USER_HOME/.ssh/authorized_keys"
# Change default shell to bash
chsh -s /bin/bash $USER_NAME
# Run ssh-agent on login and add key (WILL REMOVE)
echo "
# Start ssh-agent if not already running
if [ -z \"\$SSH_AGENT_PID\" ]; then
    eval \$(ssh-agent -s) > /dev/null
fi

# Add SSH keys if not already added
ssh-add -l &>/dev/null
if [ \$? -ne 0 ]; then
    ssh-add ~/.ssh/id_rsa  # Replace with your actual key path if different
fi
" >> "$USER_HOME/.bashrc"

################# Install applications #################
sudo apt install -y neovim

################# ZSH (TODO) #################
# sudo apt install zsh
# sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
# git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
# source ~/.zshrc

# PLZ COPY THE CONFIG FILE FROM THE VPS

# plugins=(
#   git
#   ssh-agent
#   zsh-autosuggestions
#   zsh-syntax-highlighting
# )

# source $ZSH/oh-my-zsh.sh
# zstyle :omz:plugins:ssh-agent identities github
