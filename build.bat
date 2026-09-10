@echo off
setlocal EnableDelayedExpansion

REM Always run from the script directory.
cd /d "%~dp0"

REM ---------------------------------------------------------------------------
REM Configurable build options
REM   GENERATOR  - CMake generator (default: auto-detect)
REM   ARCH       - Architecture for multi-config generators (default: x64)
REM   CONFIGS    - Configurations to build, space-separated (default: Release Debug)
REM ---------------------------------------------------------------------------
if "%GENERATOR%"=="" (
    where ninja >nul 2>nul
    if not errorlevel 1 (
        set "GENERATOR=Ninja Multi-Config"
    ) else (
        set "GENERATOR=Visual Studio 17 2022"
    )
)
if "%ARCH%"=="" set "ARCH=x64"
if "%CONFIGS%"=="" set "CONFIGS=Release Debug"

REM A cache written by a different generator cannot be reused; drop it so a
REM generator switch reconfigures cleanly instead of failing in CMake.
if exist "build\CMakeCache.txt" call :check_generator

echo [INFO] Configuring with generator: %GENERATOR%
echo "%GENERATOR%" | findstr /I /C:"Visual Studio" >nul
if not errorlevel 1 (
    cmake -S src -B build -G "%GENERATOR%" -A %ARCH%
) else (
    REM Ninja needs a compiler on PATH. Prefer the MSVC environment so CMake
    REM does not silently pick up an incompatible compiler (e.g. MinGW GCC).
    where cl >nul 2>nul
    if errorlevel 1 call :setup_msvc
    cmake -S src -B build -G "%GENERATOR%"
)
if errorlevel 1 goto :fail

for %%C in (%CONFIGS%) do (
    echo [INFO] Building: %%C
    cmake --build build --config %%C
    if errorlevel 1 goto :fail

    REM extract_tickets is EXCLUDE_FROM_ALL, so build it explicitly. It lands in
    REM build\tools\%%C\ rather than the shipped output directory.
    echo [INFO] Building tool extract_tickets for %%C
    cmake --build build --config %%C --target extract_tickets
    if errorlevel 1 goto :fail
)

echo [OK] Build completed successfully.
exit /b 0

REM Drop a stale CMakeCache when the selected generator differs from the one
REM stored in build\CMakeCache.txt. CMake cannot switch generators in place.
:check_generator
set "CACHED_GENERATOR="
for /f "tokens=2 delims==" %%G in ('findstr /B "CMAKE_GENERATOR:" "build\CMakeCache.txt" 2^>nul') do set "CACHED_GENERATOR=%%G"
if defined CACHED_GENERATOR if not "%CACHED_GENERATOR%"=="%GENERATOR%" (
    echo [INFO] Cached generator "%CACHED_GENERATOR%" differs from "%GENERATOR%"; cleaning build directory.
    rmdir /s /q build
)
exit /b 0

REM Activate the MSVC x64 environment for Ninja builds. No-op when no
REM Visual Studio with C++ tools is installed.
:setup_msvc
REM Stray quotes in PATH break the VS environment scripts; strip them.
set "PATH=%PATH:"=%"
set "VSINSTALL="
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" set "VSINSTALL=%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools"
if "%VSINSTALL%"=="" if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" set "VSINSTALL=%ProgramFiles(x86)%\Microsoft Visual Studio\2022\Community"
if "%VSINSTALL%"=="" if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat" set "VSINSTALL=%ProgramFiles(x86)%\Microsoft Visual Studio\2022\Professional"
if "%VSINSTALL%"=="" if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat" set "VSINSTALL=%ProgramFiles(x86)%\Microsoft Visual Studio\2022\Enterprise"
if "%VSINSTALL%"=="" call :find_vs_vswhere
if "%VSINSTALL%"=="" (
    echo [WARN] No Visual Studio with MSVC tools found; skipping MSVC environment setup.
    exit /b 0
)
echo [INFO] Activating MSVC environment: %VSINSTALL%
call "%VSINSTALL%\VC\Auxiliary\Build\vcvars64.bat" >nul
where cl >nul 2>nul
if errorlevel 1 echo [WARN] MSVC activation did not provide cl.exe; configure may fail.
exit /b 0

REM Fallback: locate any VS install via vswhere (covers newer versions and
REM custom install paths). Prefers a 17.x (2022) install, then the latest.
:find_vs_vswhere
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" exit /b 0
for /f "usebackq delims=" %%i in (`"%VSWHERE%" -products * -version "[17.0,18.0)" -property installationPath -latest 2^>nul`) do set "VSINSTALL=%%i"
if "%VSINSTALL%"=="" for /f "usebackq delims=" %%i in (`"%VSWHERE%" -products * -property installationPath -latest 2^>nul`) do set "VSINSTALL=%%i"
if "%VSINSTALL%"=="" exit /b 0
if not exist "%VSINSTALL%\VC\Auxiliary\Build\vcvars64.bat" set "VSINSTALL="
exit /b 0

:fail
echo [ERROR] Build failed.
exit /b 1
