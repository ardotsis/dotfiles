@echo off
set "INSTALL_ARGS=%*"
set DOCKER_CLI_HINTS=false
docker build --build-arg INSTALL_ARGS=%INSTALL_ARGS% -f .\tests\Dockerfile.vultr -t dotfiles-vultr:latest .
docker run --name dotfiles-vultr-container --rm dotfiles-vultr:latest
