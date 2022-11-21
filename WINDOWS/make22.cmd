@echo off
echo.

REM CD to the directory above the script location - which should be the main src path
cd "%~dp0"..

echo Starting
if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat" (
	SET "_VSPATHBASE=C:\Program Files\Microsoft Visual Studio\2022\Community"
) 
if exist "C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\Tools\VsDevCmd.bat" (
	SET "_VSPATHBASE=C:\Program Files\Microsoft Visual Studio\2022\Professional"
)
if exist "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\VsDevCmd.bat" (
	SET "_VSPATHBASE=C:\Program Files\Microsoft Visual Studio\2022\Enterprise"
)

echo.
call "%_VSPATHBASE%\Common7\Tools\VsDevCmd.bat"
echo.
call "%_VSPATHBASE%\Common7\Tools\vsdevcmd\ext\vcvars.bat"
echo.
echo configuring...
cmake -G "Visual Studio 17 2022" -A Win32 .
IF %ERRORLEVEL% NEQ 0 (echo Error during configuration && exit /b %ERRORLEVEL% )
echo.
echo Building...
cmake --build . --config Release --target putty
IF %ERRORLEVEL% NEQ 0 (echo Error during building && exit /b %ERRORLEVEL% )
echo.
echo Renaming...
rename ..\Release\putty.exe PuTTYNG.exe
echo Finished
echo.