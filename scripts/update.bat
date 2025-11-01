@echo off
set COMMIT_MESSAGE=%1

git fetch
git merge
git add -A
git commit -m %COMMIT_MESSAGE%
git push
