@echo off
setlocal enabledelayedexpansion

:: VS Code with Wingman AI - Portable Build Script (Windows)
:: This script builds portable VS Code distributions with Wingman AI integrated as a native feature

:: Configuration
set "SCRIPT_DIR=%~dp0"
set "BUILD_DIR=%SCRIPT_DIR%\.build-wingman"
set "DIST_DIR=%SCRIPT_DIR%\dist"
set "PRODUCT_NAME=VSCode-Wingman"
set "PRODUCT_VERSION=1.95.0-wingman"

:: Get current date/time for build naming
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "DATE=%dt:~0,8%_%dt:~8,6%"

:: Colors (basic for batch)
set "COLOR_INFO=[94m"
set "COLOR_SUCCESS=[92m"
set "COLOR_WARNING=[93m"
set "COLOR_ERROR=[91m"
set "COLOR_RESET=[0m"

:: Parse command line arguments
set "platform=win32"
set "arch=x64"
set "clean=false"
set "skip_deps=false"
set "skip_compile=false"
set "docs_only=false"

:parse_args
if "%~1"=="" goto :done_parsing
if "%~1"=="-h" goto :show_help
if "%~1"=="--help" goto :show_help
if "%~1"=="-c" set "clean=true" & shift & goto :parse_args
if "%~1"=="--clean" set "clean=true" & shift & goto :parse_args
if "%~1"=="-p" set "platform=%~2" & shift & shift & goto :parse_args
if "%~1"=="--platform" set "platform=%~2" & shift & shift & goto :parse_args
if "%~1"=="-a" set "arch=%~2" & shift & shift & goto :parse_args
if "%~1"=="--arch" set "arch=%~2" & shift & shift & goto :parse_args
if "%~1"=="--skip-deps" set "skip_deps=true" & shift & goto :parse_args
if "%~1"=="--skip-compile" set "skip_compile=true" & shift & goto :parse_args
if "%~1"=="--docs-only" set "docs_only=true" & shift & goto :parse_args
echo %COLOR_ERROR%Unknown option: %~1%COLOR_RESET%
goto :show_help

:done_parsing

echo %COLOR_INFO%Starting VSCode-Wingman build process...%COLOR_RESET%
echo %COLOR_INFO%Target platform: %platform%%COLOR_RESET%
echo %COLOR_INFO%Target architecture: %arch%%COLOR_RESET%

:: Clean if requested
if "%clean%"=="true" (
    echo %COLOR_INFO%Cleaning build directory...%COLOR_RESET%
    if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
)

:: Generate docs only if requested
if "%docs_only%"=="true" (
    call :generate_documentation
    goto :eof
)

:: Check prerequisites
call :check_prerequisites
if !errorlevel! neq 0 exit /b !errorlevel!

:: Setup build environment
if "%skip_deps%"=="false" (
    call :setup_build_environment
    if !errorlevel! neq 0 exit /b !errorlevel!
)

:: Build
if "%skip_compile%"=="false" (
    call :build_extensions
    if !errorlevel! neq 0 exit /b !errorlevel!

    call :build_vscode
    if !errorlevel! neq 0 exit /b !errorlevel!
)

:: Package
call :package_for_platform "%platform%" "%arch%"
if !errorlevel! neq 0 exit /b !errorlevel!

call :generate_documentation

echo %COLOR_SUCCESS%Build completed successfully!%COLOR_RESET%
echo %COLOR_INFO%Output directory: %DIST_DIR%%COLOR_RESET%
echo %COLOR_INFO%Available packages:%COLOR_RESET%
dir "%DIST_DIR%"

goto :eof

:check_prerequisites
echo %COLOR_INFO%Checking prerequisites...%COLOR_RESET%

:: Check Node.js
node --version >nul 2>&1
if !errorlevel! neq 0 (
    echo %COLOR_ERROR%Node.js is required but not installed%COLOR_RESET%
    exit /b 1
)

for /f "tokens=*" %%i in ('node --version') do set "NODE_VERSION=%%i"
echo %COLOR_INFO%Using Node.js version: %NODE_VERSION%%COLOR_RESET%

:: Check npm
npm --version >nul 2>&1
if !errorlevel! neq 0 (
    echo %COLOR_ERROR%npm is required but not installed%COLOR_RESET%
    exit /b 1
)

:: Check yarn
yarn --version >nul 2>&1
if !errorlevel! neq 0 (
    echo %COLOR_WARNING%yarn not found, installing globally...%COLOR_RESET%
    npm install -g yarn
)

exit /b 0

:setup_build_environment
echo %COLOR_INFO%Setting up build environment...%COLOR_RESET%

:: Create directories
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"
if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"

:: Install dependencies
echo %COLOR_INFO%Installing VS Code dependencies...%COLOR_RESET%
yarn install --frozen-lockfile
if !errorlevel! neq 0 exit /b !errorlevel!

:: Install extension dependencies
echo %COLOR_INFO%Installing Wingman AI extension dependencies...%COLOR_RESET%
cd /d "%SCRIPT_DIR%\extensions\wingman-ai"
npm install
if !errorlevel! neq 0 exit /b !errorlevel!

npm run compile
if !errorlevel! neq 0 exit /b !errorlevel!

cd /d "%SCRIPT_DIR%"
exit /b 0

:build_extensions
echo %COLOR_INFO%Building VS Code extensions...%COLOR_RESET%
yarn gulp compile-extensions
if !errorlevel! neq 0 exit /b !errorlevel!

echo %COLOR_INFO%Building Wingman AI extension...%COLOR_RESET%
cd /d "%SCRIPT_DIR%\extensions\wingman-ai"
npm run vscode:prepublish
if !errorlevel! neq 0 exit /b !errorlevel!

cd /d "%SCRIPT_DIR%"
exit /b 0

:build_vscode
echo %COLOR_INFO%Building VS Code core...%COLOR_RESET%

:: Set environment for production build
set NODE_ENV=production
set VSCODE_QUALITY=stable

:: Compile TypeScript
yarn gulp transpile-client
if !errorlevel! neq 0 exit /b !errorlevel!

yarn gulp compile
if !errorlevel! neq 0 exit /b !errorlevel!

echo %COLOR_SUCCESS%VS Code compilation completed%COLOR_RESET%
exit /b 0

:package_for_platform
set "target_platform=%~1"
set "target_arch=%~2"

echo %COLOR_INFO%Packaging for %target_platform%-%target_arch%...%COLOR_RESET%

set "package_name=%PRODUCT_NAME%-%target_platform%-%target_arch%-%DATE%"
set "output_dir=%DIST_DIR%\%package_name%"

:: Create package directory
if not exist "%output_dir%" mkdir "%output_dir%"

if "%target_platform%"=="win32" (
    call :package_windows "%target_arch%" "%output_dir%" "%package_name%"
) else (
    echo %COLOR_ERROR%This batch script only supports Windows builds. Use the shell script for other platforms.%COLOR_RESET%
    exit /b 1
)

exit /b 0

:package_windows
set "target_arch=%~1"
set "output_dir=%~2"
set "package_name=%~3"

echo %COLOR_INFO%Creating Windows portable executable...%COLOR_RESET%

:: Build Windows package
yarn gulp "vscode-win32-%target_arch%-min"
if !errorlevel! neq 0 exit /b !errorlevel!

:: Copy to output directory
echo %COLOR_INFO%Copying files to output directory...%COLOR_RESET%
xcopy /E /I /Q "..\VSCode-win32-%target_arch%\*" "%output_dir%\"
if !errorlevel! neq 0 exit /b !errorlevel!

:: Create portable launcher
echo %COLOR_INFO%Creating portable launcher...%COLOR_RESET%
(
echo @echo off
echo set VSCODE_PORTABLE=%%~dp0data
echo if not exist "%%VSCODE_PORTABLE%%" mkdir "%%VSCODE_PORTABLE%%"
echo start "" "%%~dp0Code.exe" %%*
) > "%output_dir%\portable.bat"

:: Create data directory for portable mode
if not exist "%output_dir%\data" mkdir "%output_dir%\data"

:: Create self-extracting archive if 7z is available
where 7z >nul 2>&1
if !errorlevel! equ 0 (
    echo %COLOR_INFO%Creating self-extracting archive...%COLOR_RESET%
    cd /d "%DIST_DIR%"
    7z a -sfx7z.sfx "%package_name%.exe" "%package_name%\"
    cd /d "%SCRIPT_DIR%"
)

echo %COLOR_SUCCESS%Windows package created: %output_dir%%COLOR_RESET%
exit /b 0

:generate_documentation
echo %COLOR_INFO%Generating documentation...%COLOR_RESET%

:: Create README.md
(
echo # VSCode with Wingman AI - Portable Edition
echo.
echo This is a portable distribution of Visual Studio Code with Wingman AI integrated as a native feature.
echo.
echo ## What's Included
echo.
echo - **Visual Studio Code**: The popular open-source code editor
echo - **Wingman AI**: Integrated AI coding assistant with support for:
echo   - Anthropic Claude
echo - **OpenAI GPT models**
echo - **Azure OpenAI**
echo - **Ollama** ^(local models^)
echo.
echo ## Features
echo.
echo - **Seamless Integration**: Wingman AI loads automatically and appears as a native VS Code feature
echo - **Hidden from Extensions**: Wingman AI doesn't appear in the Extensions marketplace or panel
echo - **Portable**: All settings and data stored locally, no installation required
echo - **Full Functionality**: All standard VS Code features remain unchanged
echo.
echo ## Windows Instructions
echo.
echo 1. Extract the archive or run the self-extracting executable
echo 2. Run `portable.bat` or `Code.exe` directly
echo 3. Settings and extensions will be stored in the `data` folder
echo.
echo ## Using Wingman AI
echo.
echo Wingman AI is automatically available in the sidebar and through the following shortcuts:
echo - `Ctrl+Shift+Space`: Code completion
echo - `Ctrl+I`: Open composer
echo.
echo ## Upgrading
echo.
echo To upgrade this distribution:
echo 1. Backup your `data` folder ^(contains all settings and extensions^)
echo 2. Download the new version
echo 3. Extract to a new folder
echo 4. Copy your `data` folder to the new installation
echo 5. Delete the old version
echo.
echo ## Build Information
echo.
echo - Build Date: %date% %time%
echo - VS Code Version: %PRODUCT_VERSION%
echo - Platform: Windows
echo.
echo ## Troubleshooting
echo.
echo If you encounter issues:
echo 1. Delete the `data` folder to reset to defaults
echo 2. Check the developer console ^(Help ^> Toggle Developer Tools^)
echo 3. Refer to the VS Code documentation for general issues
echo.
echo ## License
echo.
echo This distribution combines:
echo - VS Code: MIT License ^(Microsoft^)
echo - Wingman AI: MIT License ^(Russell Canfield^)
echo.
echo See individual license files for details.
) > "%DIST_DIR%\README.md"

echo %COLOR_SUCCESS%Documentation generated in %DIST_DIR%%COLOR_RESET%
exit /b 0

:show_help
echo VSCode with Wingman AI - Build Script ^(Windows^)
echo.
echo Usage: %~nx0 [OPTIONS]
echo.
echo Options:
echo     -h, --help          Show this help message
echo     -c, --clean         Clean build directory before building
echo     -p, --platform      Target platform ^(win32^) [default: win32]
echo     -a, --arch          Target architecture ^(x64^|arm64^) [default: x64]
echo     --skip-deps         Skip dependency installation
echo     --skip-compile      Skip compilation step
echo     --docs-only         Generate documentation only
echo.
echo Examples:
echo     %~nx0                          # Build for Windows x64
echo     %~nx0 -a arm64                 # Build for Windows ARM64
echo     %~nx0 --clean                  # Clean and build
echo     %~nx0 --docs-only              # Generate documentation only
echo.
exit /b 0
