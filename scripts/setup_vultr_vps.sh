#!/bin/bash

# 変数の設定
USER_NAME=""             # ユーザー名（必要に応じて変更）
PASSWORD=""
SSH_PORT="22"            # SSHポート番号（必要に応じて変更）
KEY_PASSPHRASE=""        # SSH鍵のパスフレーズ（必要に応じて変更）

# システムの更新
sudo apt update -y
sudo apt upgrade -y

# 新規ユーザーを追加
sudo useradd -m "$USER_NAME"

# パスワードの設定
echo "$USER_NAME:$PASSWORD" | sudo chpasswd

# "wheel" グループの作成
sudo groupadd wheel

# ユーザーを "wheel" グループに追加
sudo usermod -aG wheel "$USER_NAME"

# "wheel" グループのユーザーにパスワードなしで sudo 権限を付与 (NOPASSWD)
echo "%wheel ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/wheel

# SSH設定の編集（ポート番号変更含む）
sudo sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sudo sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config
sudo sed -i "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/" /etc/ssh/sshd_config
sudo sed -i "s/PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config

# SSHサービスの再起動
sudo systemctl restart sshd
sudo systemctl restart ssh

# UFWの設定をリセット
sudo ufw reset

# 必要なポートの設定
sudo ufw allow "$SSH_PORT"/tcp       # SSH用 (新しいポート)
sudo ufw allow http/tcp              # HTTP用
sudo ufw allow https/tcp             # HTTPS用
sudo ufw enable                      # UFWを有効化

# neovimのインストール
sudo apt install -y neovim

# -------------------------------
# SSH鍵の生成と設定
# -------------------------------
# ユーザーのホームディレクトリに移動
USER_HOME=$(eval echo "~$USER_NAME")

# SSHディレクトリの作成
sudo mkdir -p "$USER_HOME/.ssh"
sudo chown "$USER_NAME:$USER_NAME" "$USER_HOME/.ssh"
sudo chmod 700 "$USER_HOME/.ssh"

# SSH鍵の生成（パスフレーズ指定）
sudo -u "$USER_NAME" ssh-keygen -t rsa -b 4096 -f "$USER_HOME/.ssh/id_rsa" -N "$KEY_PASSPHRASE" -C "$USER_NAME@server"

# 公開鍵をauthorized_keysにコピー
sudo -u "$USER_NAME" cat "$USER_HOME/.ssh/id_rsa.pub" >> "$USER_HOME/.ssh/authorized_keys"
sudo chmod 600 "$USER_HOME/.ssh/authorized_keys"

# プライベートキーの内容を取得
PRIVATE_KEY=$(sudo -u "$USER_NAME" cat "$USER_HOME/.ssh/id_rsa")

# 最後に生成されたプライベートキーを表示
echo "セットアップ完了！ユーザー名: $USER_NAME、新しいSSHポート: $SSH_PORT"
echo "ユーザー "$USER_NAME" のプライベートキーは以下です："
echo "----------------------------------------"
echo "$PRIVATE_KEY"
echo "----------------------------------------"
echo "このキーを安全な場所に保存してください。"

# スクリプト終了メッセージ
echo "DockerとDocker Composeのインストール、SSH設定、UFW設定、およびユーザー権限設定が完了しました。"
