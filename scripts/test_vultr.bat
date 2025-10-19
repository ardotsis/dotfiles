@echo off
docker build -f .\tests\Dockerfile.vultr -t dotfiles-vultr:latest .
docker run --rm dotfiles-vultr:latest
