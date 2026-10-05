@echo off
set "HUNT_GODOT=C:\Users\Razvan\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if not exist "%HUNT_GODOT%" (
  echo Nu gasesc Godot la locatia initiala. Importa project.godot din Godot.
  pause
  exit /b 1
)
start "" "%HUNT_GODOT%" --editor --path "%~dp0." res://game/main.tscn
