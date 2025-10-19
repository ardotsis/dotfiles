@echo off
docker build -f .\tests\Dockerfile.vultr -t dotfiles-vultr:latest . --no-cache
docker run --rm dotfiles-vultr:latest
