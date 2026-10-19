@echo off
rem Refresh the translation sources (i18n\*.ts) from the QML files and compile them into
rem Locales\*.qm, which SAO Utils loads automatically for its UI language.
rem Requires the Qt 5 tools lupdate and lrelease in PATH.
rem To add a language, add a "call :lang <file name> <Qt language code>" line below
rem (file names follow SAO Utils: zh, zh_TW, ja, ...).
setlocal
cd /d "%~dp0.."
if not exist Locales mkdir Locales

call :lang zh zh_CN
goto :eof

:lang
lupdate qml\main-stand.qml qml\CoreSettings.qml qml\StyleSettings.qml qml\SettingNote.qml qml\Console.qml qml\OptionSettings.qml qml\ProcessListEditor.qml qml\HeartPage.qml -source-language en -target-language %2 -no-obsolete -ts i18n\%1.ts
lrelease i18n\%1.ts -qm Locales\%1.qm
goto :eof
