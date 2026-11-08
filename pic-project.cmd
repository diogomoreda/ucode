
@echo off
setlocal EnableExtensions DisableDelayedExpansion

title PIC Project Generator

rem ============================================================
rem Paths
rem ============================================================

set "APP_DIR=%~dp0"
set "CONFIG_FILE=%~dp0config.ini"

rem ============================================================
rem Command dispatcher
rem ============================================================

if /i "%~1"=="config" goto configure
if /i "%~1"=="new" goto new_project
if /i "%~1"=="create" goto new_project
if /i "%~1"=="help" goto help
if "%~1"=="" goto help

echo Unknown command: %~1
echo.
goto help


rem ============================================================
rem Help
rem ============================================================

:help

echo.
echo PIC Project Generator
echo =====================
echo.
echo Usage:
echo.
echo   pic-project config    Configure MPLAB X tools
echo   pic-project new       Create a new PIC project
echo   pic-project create    Alias for new
echo   pic-project help      Show this help
echo.

goto end


rem ============================================================
rem Configuration wizard
rem ============================================================

:configure

echo.
echo PIC Project Generator - Configuration
echo ======================================
echo.

call :load_config

if not defined MPLABX_ROOT set "MPLABX_ROOT=%ProgramFiles(x86)%\Microchip\MPLABX\v3.35"
if not defined MPASM_EXE set "MPASM_EXE=%MPLABX_ROOT%\mpasmx\mpasmx.exe"
if not defined MPASM_INCLUDE_DIR set "MPASM_INCLUDE_DIR=%MPLABX_ROOT%\mpasmx"
if not defined MAKE_EXE set "MAKE_EXE=%MPLABX_ROOT%\gnuBins\GnuWin32\bin\make.exe"

echo Enter the paths to your MPLAB X installation and tools.
echo Press ENTER to accept the displayed default.
echo.

set "INPUT="

set /p "INPUT=MPLAB X root [%MPLABX_ROOT%]: "
if defined INPUT set "MPLABX_ROOT=%INPUT%"

echo.
set "INPUT="

set /p "INPUT=MPASMX executable [%MPASM_EXE%]: "
if defined INPUT set "MPASM_EXE=%INPUT%"

echo.
set "INPUT="

set /p "INPUT=MPASMX include directory [%MPASM_INCLUDE_DIR%]: "
if defined INPUT set "MPASM_INCLUDE_DIR=%INPUT%"

echo.
set "INPUT="

set /p "INPUT=GNU Make executable [%MAKE_EXE%]: "
if defined INPUT set "MAKE_EXE=%INPUT%"

rem ------------------------------------------------------------
rem Validate configuration
rem ------------------------------------------------------------

echo.
echo Validating paths...
echo.

if not exist "%MPASM_EXE%" goto config_missing_mpasm
if not exist "%MPASM_INCLUDE_DIR%\" goto config_missing_include
if not exist "%MAKE_EXE%" goto config_missing_make

goto save_config


:config_missing_mpasm
echo ERROR: MPASMX executable not found:
echo %MPASM_EXE%
goto config_error


:config_missing_include
echo ERROR: MPASMX include directory not found:
echo %MPASM_INCLUDE_DIR%
goto config_error


:config_missing_make
echo ERROR: GNU Make executable not found:
echo %MAKE_EXE%
goto config_error


rem ------------------------------------------------------------
rem Save configuration
rem ------------------------------------------------------------

:save_config

> "%CONFIG_FILE%" echo # PIC Project Generator - Global Configuration
>> "%CONFIG_FILE%" echo.
>> "%CONFIG_FILE%" echo MPLABX_ROOT=%MPLABX_ROOT%
>> "%CONFIG_FILE%" echo MPASM_EXE=%MPASM_EXE%
>> "%CONFIG_FILE%" echo MPASM_INCLUDE_DIR=%MPASM_INCLUDE_DIR%
>> "%CONFIG_FILE%" echo MAKE_EXE=%MAKE_EXE%

echo.
echo Configuration saved successfully.
echo.
echo Location:
echo %CONFIG_FILE%
echo.

goto end


:config_error

echo.
echo Configuration was not saved.
echo Correct the paths and try again.
echo.

goto end


rem ============================================================
rem Load global configuration
rem ============================================================

:load_config

set "MPLABX_ROOT="
set "MPASM_EXE="
set "MPASM_INCLUDE_DIR="
set "MAKE_EXE="

if not exist "%CONFIG_FILE%" exit /b 0

for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%CONFIG_FILE%") do (
    if /i "%%A"=="MPLABX_ROOT" set "MPLABX_ROOT=%%B"
    if /i "%%A"=="MPASM_EXE" set "MPASM_EXE=%%B"
    if /i "%%A"=="MPASM_INCLUDE_DIR" set "MPASM_INCLUDE_DIR=%%B"
    if /i "%%A"=="MAKE_EXE" set "MAKE_EXE=%%B"
)

exit /b 0


rem ============================================================
rem New project
rem ============================================================

:new_project

echo.
echo PIC Project Generator - New Project
echo ====================================
echo.

if not exist "%CONFIG_FILE%" goto new_no_config

call :load_config

if not exist "%MPASM_EXE%" goto new_bad_mpasm
if not exist "%MPASM_INCLUDE_DIR%\" goto new_bad_include
if not exist "%MAKE_EXE%" goto new_bad_make

echo Toolchain configuration verified.
echo.

rem ------------------------------------------------------------
rem Project name
rem ------------------------------------------------------------

set "PROJECT_NAME="

set /p "PROJECT_NAME=Project name: "

if not defined PROJECT_NAME goto new_invalid_name

set "PROJECTS_DIR=%APP_DIR%projects"

if not exist "%PROJECTS_DIR%\" md "%PROJECTS_DIR%"
if not exist "%PROJECTS_DIR%\" goto new_create_error

rem ------------------------------------------------------------
rem Processor search
rem ------------------------------------------------------------

:select_processor

echo.
echo Available PIC processors
echo ------------------------

set "SEARCH="

set /p "SEARCH=Search (e.g. 16F, 18F, 1455): "

set /a DEVICE_COUNT=0

for %%F in ("%MPASM_INCLUDE_DIR%\P*.INC") do if exist "%%~fF" call :show_device "%%~nF" "%SEARCH%"

if "%DEVICE_COUNT%"=="0" goto new_no_devices

echo.
echo Enter the processor name shown above.
echo You can enter it with or without the leading P.
echo.

set "PROCESSOR="

set /p "PROCESSOR=Processor: "

if not defined PROCESSOR goto select_processor

if /i "%PROCESSOR:~0,1%"=="P" set "PROCESSOR=%PROCESSOR:~1%"

if not exist "%MPASM_INCLUDE_DIR%\P%PROCESSOR%.INC" goto new_invalid_processor

rem ------------------------------------------------------------
rem Project directory
rem ------------------------------------------------------------

set "PROJECT_DIR=%PROJECTS_DIR%\%PROCESSOR%_%PROJECT_NAME%"

if exist "%PROJECT_DIR%\" goto new_exists

echo.
echo Creating project...
echo.

md "%PROJECT_DIR%"
if not exist "%PROJECT_DIR%\" goto new_create_error

rem ------------------------------------------------------------
rem Generate main.asm
rem ------------------------------------------------------------

> "%PROJECT_DIR%\main.asm" echo         LIST P=%PROCESSOR%
>> "%PROJECT_DIR%\main.asm" echo #include "P%PROCESSOR%.INC"
>> "%PROJECT_DIR%\main.asm" echo.
>> "%PROJECT_DIR%\main.asm" echo         ORG     0x0000
>> "%PROJECT_DIR%\main.asm" echo         GOTO    start
>> "%PROJECT_DIR%\main.asm" echo.
>> "%PROJECT_DIR%\main.asm" echo start:
>> "%PROJECT_DIR%\main.asm" echo         GOTO    start
>> "%PROJECT_DIR%\main.asm" echo.
>> "%PROJECT_DIR%\main.asm" echo         END





rem ============================================================
rem Generate Makefile
rem ============================================================

rem Store an actual TAB character.
set "TAB=	"

> "%PROJECT_DIR%\Makefile" echo # ============================================================
>> "%PROJECT_DIR%\Makefile" echo # PIC Assembly Project
>> "%PROJECT_DIR%\Makefile" echo # ============================================================
>> "%PROJECT_DIR%\Makefile" echo.
>> "%PROJECT_DIR%\Makefile" echo SHELL := cmd.exe
>> "%PROJECT_DIR%\Makefile" echo.
>> "%PROJECT_DIR%\Makefile" echo include ../../config.ini
>> "%PROJECT_DIR%\Makefile" echo.
>> "%PROJECT_DIR%\Makefile" echo PROCESSOR := %PROCESSOR%
>> "%PROJECT_DIR%\Makefile" echo SOURCE := main.asm
>> "%PROJECT_DIR%\Makefile" echo TARGET := main
>> "%PROJECT_DIR%\Makefile" echo BUILD_DIR := build
>> "%PROJECT_DIR%\Makefile" echo DEVICE_INCLUDE := P$(PROCESSOR).INC
>> "%PROJECT_DIR%\Makefile" echo.
>> "%PROJECT_DIR%\Makefile" echo .PHONY: all build rebuild clean
>> "%PROJECT_DIR%\Makefile" echo.
>> "%PROJECT_DIR%\Makefile" echo all: build
>> "%PROJECT_DIR%\Makefile" echo.
>> "%PROJECT_DIR%\Makefile" echo build: $(BUILD_DIR)/$(TARGET).HEX
>> "%PROJECT_DIR%\Makefile" echo.
>> "%PROJECT_DIR%\Makefile" echo $(BUILD_DIR)/$(TARGET).HEX: $(SOURCE)
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@if not exist "$(BUILD_DIR)" mkdir "$(BUILD_DIR)"
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@if exist "$(TARGET).HEX" del /q "$(TARGET).HEX"
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@if exist "$(TARGET).ERR" del /q "$(TARGET).ERR"
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@if exist "$(TARGET).LST" del /q "$(TARGET).LST"
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@if exist "$(TARGET).COD" del /q "$(TARGET).COD"
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@if exist "$(BUILD_DIR)\$(TARGET).HEX" del /q "$(BUILD_DIR)\$(TARGET).HEX"
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@if exist "$(BUILD_DIR)\$(TARGET).ERR" del /q "$(BUILD_DIR)\$(TARGET).ERR"
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@if exist "$(BUILD_DIR)\$(TARGET).LST" del /q "$(BUILD_DIR)\$(TARGET).LST"
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@if exist "$(BUILD_DIR)\$(TARGET).COD" del /q "$(BUILD_DIR)\$(TARGET).COD"
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@echo Preparing PIC$(PROCESSOR)...
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@copy /y "$(MPASM_INCLUDE_DIR)\$(DEVICE_INCLUDE)" "$(DEVICE_INCLUDE)" ^>nul
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@echo Building PIC$(PROCESSOR)...
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@"$(MPASM_EXE)" /p$(PROCESSOR) /aINHX32 /l /e $(SOURCE)
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@if exist "$(DEVICE_INCLUDE)" move /y "$(DEVICE_INCLUDE)" "$(BUILD_DIR)\" ^>nul
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@if exist "$(TARGET).HEX" move /y "$(TARGET).HEX" "$(BUILD_DIR)\" ^>nul
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@if exist "$(TARGET).ERR" move /y "$(TARGET).ERR" "$(BUILD_DIR)\" ^>nul
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@if exist "$(TARGET).LST" move /y "$(TARGET).LST" "$(BUILD_DIR)\" ^>nul
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@if exist "$(TARGET).COD" move /y "$(TARGET).COD" "$(BUILD_DIR)\" ^>nul
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@if not exist "$(BUILD_DIR)\$(TARGET).ERR" (echo ERROR: ERR file was not generated. ^& exit /b 1)
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@echo.
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@echo Checking warnings...
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@findstr /i /l /c:"Warning[" "$(BUILD_DIR)\$(TARGET).ERR" ^|^| ver ^>nul
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@echo.
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@echo Checking errors...
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@findstr /i /l /c:"Error[" /c:"Fatal[" "$(BUILD_DIR)\$(TARGET).ERR" ^>nul ^&^& (echo Assembly errors detected. ^& exit /b 1) ^|^| exit /b 0
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@if not exist "$(BUILD_DIR)\$(TARGET).HEX" (echo ERROR: HEX file was not generated. ^& exit /b 1)
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@echo.
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@echo Build successful.
>> "%PROJECT_DIR%\Makefile" echo.
>> "%PROJECT_DIR%\Makefile" echo rebuild: clean build
>> "%PROJECT_DIR%\Makefile" echo.
>> "%PROJECT_DIR%\Makefile" echo clean:
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@if exist "$(BUILD_DIR)" rmdir /s /q "$(BUILD_DIR)"
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@if exist "$(TARGET).HEX" del /q "$(TARGET).HEX"
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@if exist "$(TARGET).ERR" del /q "$(TARGET).ERR"
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@if exist "$(TARGET).LST" del /q "$(TARGET).LST"
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@if exist "$(TARGET).COD" del /q "$(TARGET).COD"
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@if exist "$(DEVICE_INCLUDE)" del /q "$(DEVICE_INCLUDE)"
>> "%PROJECT_DIR%\Makefile" echo(%TAB%@echo Clean complete.



rem ============================================================
rem Generate build.cmd
rem ============================================================

> "%PROJECT_DIR%\build.cmd" echo @echo off
>> "%PROJECT_DIR%\build.cmd" echo call "%MAKE_EXE%" %%*
>> "%PROJECT_DIR%\build.cmd" echo exit /b %%errorlevel%%

rem ============================================================
rem Generate VS Code tasks.json
rem ============================================================

md "%PROJECT_DIR%\.vscode"

> "%PROJECT_DIR%\.vscode\tasks.json" echo {
>> "%PROJECT_DIR%\.vscode\tasks.json" echo     "version": "2.0.0",
>> "%PROJECT_DIR%\.vscode\tasks.json" echo     "tasks": [
>> "%PROJECT_DIR%\.vscode\tasks.json" echo         {
>> "%PROJECT_DIR%\.vscode\tasks.json" echo             "label": "Build PIC project",
>> "%PROJECT_DIR%\.vscode\tasks.json" echo             "type": "shell",
>> "%PROJECT_DIR%\.vscode\tasks.json" echo             "command": "${workspaceFolder}\\build.cmd",
>> "%PROJECT_DIR%\.vscode\tasks.json" echo             "args": ["build"],
>> "%PROJECT_DIR%\.vscode\tasks.json" echo             "group": {
>> "%PROJECT_DIR%\.vscode\tasks.json" echo                 "kind": "build",
>> "%PROJECT_DIR%\.vscode\tasks.json" echo                 "isDefault": true
>> "%PROJECT_DIR%\.vscode\tasks.json" echo             },
>> "%PROJECT_DIR%\.vscode\tasks.json" echo             "problemMatcher": []
>> "%PROJECT_DIR%\.vscode\tasks.json" echo         }
>> "%PROJECT_DIR%\.vscode\tasks.json" echo     ]
>> "%PROJECT_DIR%\.vscode\tasks.json" echo }

rem ============================================================
rem Generate VS Code settings.json
rem ============================================================

> "%PROJECT_DIR%\.vscode\settings.json" echo {
>> "%PROJECT_DIR%\.vscode\settings.json" echo     "files.associations": {
>> "%PROJECT_DIR%\.vscode\settings.json" echo         "*.asm": "pic-assembly",
>> "%PROJECT_DIR%\.vscode\settings.json" echo         "*.inc": "pic-assembly",
>> "%PROJECT_DIR%\.vscode\settings.json" echo         "*.lst": "plaintext",
>> "%PROJECT_DIR%\.vscode\settings.json" echo         "*.err": "plaintext",
>> "%PROJECT_DIR%\.vscode\settings.json" echo         "*.hex": "plaintext"
>> "%PROJECT_DIR%\.vscode\settings.json" echo     }
>> "%PROJECT_DIR%\.vscode\settings.json" echo }

rem ============================================================
rem Success
rem ============================================================

echo.
echo Project created successfully.
echo.
echo Name:      "%PROJECT_NAME%"
echo Processor: %PROCESSOR%
echo Location:  "%PROJECT_DIR%"
echo.
echo Generated files:
echo   .vscode\tasks.json
echo   main.asm
echo   Makefile
echo   build.cmd
echo.
echo Open the project folder in VS Code:
echo.
echo   code "%PROJECT_DIR%"
echo.
echo Press CTRL + SHIFT + B to build.
echo.

goto end


rem ============================================================
rem Device listing helper
rem ============================================================

:show_device

set "DEVICE_FILE=%~1"
set "DEVICE=%DEVICE_FILE:~1%"

rem Only list device names beginning with a digit.

echo(%DEVICE%| findstr /r /i "^[0-9][A-Z0-9]*$" >nul
if errorlevel 1 exit /b 0

rem Apply optional search filter.

if "%~2"=="" goto show_device_match

echo(%DEVICE%| findstr /i /c:"%~2" >nul
if errorlevel 1 exit /b 0

:show_device_match

echo   %DEVICE%
set /a DEVICE_COUNT+=1

exit /b 0


rem ============================================================
rem New project error handling
rem ============================================================

:new_no_config
echo ERROR: Configuration not found.
echo Run: pic-project config
goto end

:new_bad_mpasm
echo ERROR: MPASMX executable not found.
echo Run: pic-project config
goto end

:new_bad_include
echo ERROR: MPASMX include directory not found.
echo Run: pic-project config
goto end

:new_bad_make
echo ERROR: GNU Make executable not found.
echo Run: pic-project config
goto end

:new_invalid_name
echo ERROR: Project name cannot be empty.
goto end

:new_exists
echo ERROR: Project directory already exists:
echo "%PROJECT_DIR%"
goto end

:new_create_error
echo ERROR: Could not create project directory.
goto end

:new_no_devices
echo ERROR: No matching PIC processor include files found.
echo Check MPASM_INCLUDE_DIR in config.ini.
goto end

:new_invalid_processor
echo.
echo ERROR: Processor include file not found:
echo P%PROCESSOR%.INC
echo.
goto select_processor


rem ============================================================
rem Exit
rem ============================================================

:end

endlocal
