@echo off
set "COMMIT_MESSAGE=%~1"

if "%COMMIT_MESSAGE%"=="" (
    set "COMMIT_MESSAGE=%date%"
)

git fetch
git merge
git add -A
git commit -m "%COMMIT_MESSAGE%"
git push
