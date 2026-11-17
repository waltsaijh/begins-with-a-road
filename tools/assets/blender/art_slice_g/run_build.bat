@echo off
setlocal
rem Builds editable .blend files + previews for all six towers from towers.py.
rem Add "export" as an argument (run_build.bat export) to also overwrite the game GLBs.
set "HERE=%~dp0"
set "BLENDER="
for /f "delims=" %%i in ('where blender 2^>nul') do if not defined BLENDER set "BLENDER=%%i"
if not defined BLENDER for /d %%d in ("C:\Program Files\Blender Foundation\Blender*") do if exist "%%d\blender.exe" set "BLENDER=%%d\blender.exe"
if not defined BLENDER (
  echo Blender not found. Edit this file and set BLENDER to the full path of blender.exe
  pause
  exit /b 1
)
set "EXTRA="
if /i "%1"=="export" set "EXTRA=--export"
echo Using "%BLENDER%"
echo Building six towers... about one minute.
"%BLENDER%" --background --factory-startup --python "%HERE%build_blender.py" -- %EXTRA% > "%HERE%build_log.txt" 2>&1
findstr /c:"BUILD_OK" "%HERE%build_log.txt" >nul && (echo Done! Opening previews... & start "" "%HERE%previews") || (echo Build failed - tell Claude, the log is in build_log.txt)
pause
