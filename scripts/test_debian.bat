@echo off
set "REPO_DIR=%~dp0.."
set "INSTALL_ARGS=%*"
set "DOCKERFILE=Dockerfile.debian"
set "IMAGE_NAME=dotfiles-debian"
set "DOCKER_CLI_HINTS=false"

cd %REPO_DIR%

@REM CLean up containers
for /f "tokens=*" %%i in ('docker ps -a --filter "ancestor=%IMAGE_NAME%:latest" -q') do (
    docker rm -f %%i
)

@REM Clean up "<none>" images
for /f "tokens=*" %%i in ('docker images -f "dangling=true" -q') do (
    docker rmi -f %%i
)

cls
docker build --build-arg INSTALL_ARGS=%INSTALL_ARGS% -f "%REPO_DIR%\tests\%DOCKERFILE%" -t "%IMAGE_NAME%:latest" %REPO_DIR%
docker run --name "%IMAGE_NAME%-container" --rm "%IMAGE_NAME%:latest"
