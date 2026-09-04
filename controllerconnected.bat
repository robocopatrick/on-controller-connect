@echo off
set "LOG=%~dp0controller.log"

echo [%date% %time%] PS5 Controller %~1 >> "%LOG%"
