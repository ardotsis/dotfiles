@echo off
set "INSTALL_ARGS=%*"
set "IMAGE_NAME=dotfiles-vultr"
set "DOCKER_CLI_HINTS=false"

@REM CLean up containers
for /f "tokens=*" %%i in ('docker ps -a --filter "ancestor=%IMAGE_NAME%:latest" -q') do (
    docker rm -f %%i
)

@REM Clean up "<none>" images
for /f "tokens=*" %%i in ('docker images -f "dangling=true" -q') do (
    docker rmi -f %%i
)

cls
docker build --build-arg INSTALL_ARGS=%INSTALL_ARGS% -f .\tests\Dockerfile.vultr -t %IMAGE_NAME%:latest .
docker run --name %IMAGE_NAME%-container --rm %IMAGE_NAME%:latest
