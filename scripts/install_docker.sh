#!/bin/bash

# -------------------------------
# Docker のインストール
# -------------------------------
# 依存関係のインストール
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

# Docker公式GPGキーを追加
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Dockerのリポジトリを追加
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

# Dockerのインストール
sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Docker Compose のインストール
DOCKER_COMPOSE_VERSION="1.29.2"
sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# 実行権限の付与
sudo chmod +x /usr/local/bin/docker-compose

# ユーザーを docker グループに追加（sudo なしで Docker 実行可能に）
sudo usermod -aG docker "$USER_NAME"

# Docker のバージョン確認
docker --version
docker-compose --version

