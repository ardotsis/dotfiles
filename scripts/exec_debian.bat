@echo off
set "DOCKER_CLI_HINTS=false"

set "IMAGE_NAME=dotfiles-debian"
docker exec -it --user kana "%IMAGE_NAME%-container" zsh
