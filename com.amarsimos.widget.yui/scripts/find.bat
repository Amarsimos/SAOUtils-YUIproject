@echo off
rem Yui's file search (<<find:>>): runs Everything's command line tool es.exe and writes a status file.
rem Arguments: %1 es.exe path from Option ("" = look for it), %2 search text, %3 result file, %4 status file.
rem The status file holds "code=<es.exe exit code>" (or "code=missing") and es="<es.exe path used>".
setlocal DisableDelayedExpansion
rem Results of earlier searches are no longer needed.
del /q "%~dp3find-*.txt" "%~dp3find-*.status" 2>nul
set "ES=%~1"
if defined ES goto run
for %%P in (es.exe) do set "ES=%%~$PATH:P"
if not defined ES if exist "%ProgramFiles%\Everything\es.exe" set "ES=%ProgramFiles%\Everything\es.exe"
if not defined ES if exist "%ProgramFiles(x86)%\Everything\es.exe" set "ES=%ProgramFiles(x86)%\Everything\es.exe"
:run
if not defined ES goto missing
if not exist "%ES%" goto missing
"%ES%" -n 20 -export-txt "%~3" "%~2"
>"%~4" echo code=%errorlevel%
>>"%~4" echo es="%ES%"
exit /b
:missing
>"%~4" echo code=missing
>>"%~4" echo es="%ES%"
