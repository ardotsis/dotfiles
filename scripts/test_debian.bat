@echo off

@REM Batch arguments
set "INSTALL_ARGS=%~1"
set "REBUILD_FLAG=%~2"

@REM Paths
set "REPO_DIR=%~dp0.."
set "DOCKERFILE=%REPO_DIR%\tests\Dockerfile.debian"
set "IMAGE_NAME=dotfiles-debian"
set "IMAGE_TAG=%IMAGE_NAME%:latest"
set "CONTAINER_NAME=%IMAGE_NAME%-container"

@REM Docker configurations
set "DOCKER_CLI_HINTS=false"

@REM Clean up docker objects
echo Clean up running containers
for /f "tokens=*" %%i in ('docker ps -a --filter "ancestor=%IMAGE_TAG%" -q') do (
    docker rm -f %%i
)
echo Clean up ^<none^> images
for /f "tokens=*" %%i in ('docker images -f "dangling=true" -q') do (
    docker rmi -f %%i
)

@REM Build & Run
if "%REBUILD_FLAG%"=="--rebuild" (
    docker build --no-cache --build-arg INSTALL_ARGS="%INSTALL_ARGS%" -f "%DOCKERFILE%" -t "%IMAGE_TAG%" "%REPO_DIR%"
)
docker run --rm --name "%CONTAINER_NAME%" "%IMAGE_TAG%"
