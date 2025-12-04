@echo off

@REM Batch arguments
set "INSTALL_ARGS=%~1"
set "REBUILD_FLAG=%~2"

@REM Paths
set "REPO_DIR=%~dp0.."
set "DOCKERFILE=%REPO_DIR%\tests\Dockerfile.debian"
set "IMAGE_NAME=dotfiles-debian"
set "IMAGE_TAG=latest"
set "IMAGE=%IMAGE_NAME%:%IMAGE_TAG%"
set "CONTAINER_NAME=%IMAGE_NAME%-container"
set "DOTFILES_DEV_DATA=/var/tmp/.dotfiles"

@REM Docker configurations
set "DOCKER_CLI_HINTS=false"

echo Cleaning up running containers created from '%IMAGE%'...
for /f "tokens=*" %%i in ('docker ps -aq --filter "ancestor=%IMAGE%" -q') do (
    docker rm -f %%i
)

if "%REBUILD_FLAG%"=="--rebuild" (
    docker build --no-cache --build-arg INSTALL_ARGS="%INSTALL_ARGS%" -f "%DOCKERFILE%" -t "%IMAGE%" "%REPO_DIR%"

    echo Cleaning up dangling images...
    for /f "tokens=*" %%i in ('docker images -f "dangling=true" -q') do (
        docker rmi -f %%i
    )
    echo Cleaning up build history...
    docker buildx history rm --all
)
echo.
docker run --rm --mount type=bind,source="%REPO_DIR%",target="%DOTFILES_DEV_DATA%",readonly --name "%CONTAINER_NAME%" "%IMAGE%"
