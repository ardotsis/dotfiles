@echo off
docker build -f .\tests\Dockerfile.vultr -t dotfiles-vultr:latest .
docker run --name dotfiles-vultr-container --rm dotfiles-vultr:latest
