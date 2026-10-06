@echo off
rem Porneste jocul direct (fara editor). Cauta Godot 4 in Downloads daca HUNT_GODOT nu e setat.
setlocal
cd /d "%~dp0"
if not defined HUNT_GODOT (
  for /r "%USERPROFILE%\Downloads" %%F in (Godot_v4*_win64.exe) do if not defined HUNT_GODOT set "HUNT_GODOT=%%F"
)
if not defined HUNT_GODOT (
  echo Nu gasesc Godot 4 in Downloads. Seteaza HUNT_GODOT cu calea catre Godot.exe.
  pause
  exit /b 1
)
echo Actualizez importul Godot (prima data dureaza putin)...
"%HUNT_GODOT%" --headless --path "%~dp0." --import
echo Pornesc jocul cu %HUNT_GODOT%
start "" "%HUNT_GODOT%" --path "%~dp0."
