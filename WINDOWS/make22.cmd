@echo off
echo.
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
echo Building...
REM ".." here because we're in the windows dir and cmake works off of the root dir
cmake ..
cmake --build .. --config Release --target putty
echo.
echo Finished
echo.