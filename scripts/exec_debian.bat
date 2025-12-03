@echo off
set "IMAGE_NAME=dotfiles-debian"
docker exec -it "%IMAGE_NAME%-container" bash
