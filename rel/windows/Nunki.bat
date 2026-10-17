@echo off
rem Starts Nunki with a console window: the launcher for when something is
rem wrong and you want to read what the program says. Nunki.exe beside this
rem file is the one to double-click otherwise.
rem
rem The data goes where Nunki.exe puts it, outside this folder, so that a
rem new version unzipped beside the old one finds it: see "Where your data
rem lives" in the README. NUNKI_DATA, when it is set, is left alone.
setlocal
if "%NUNKI_DATA%"=="" set NUNKI_DATA=%LOCALAPPDATA%\NunkiData
if "%PORT%"=="" set PORT=4062
rem What the release writes when it starts goes beside the data, not in here.
if "%RELEASE_TMP%"=="" set RELEASE_TMP=%NUNKI_DATA%\tmp
rem Erlang distribution off (see rel/env.bat.eex). `set
rem RELEASE_DISTRIBUTION=sname` before this file gives a node that
rem `bin\nunki.bat remote` can attach to, for one session.
if "%RELEASE_DISTRIBUTION%"=="" set RELEASE_DISTRIBUTION=none
echo Starting Nunki on http://localhost:%PORT%
echo Data: %NUNKI_DATA%
echo Close this window to stop it. Nothing is announced while it is stopped.
echo.
"%~dp0bin\nunki.bat" start
endlocal
