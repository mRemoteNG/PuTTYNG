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
	SET "_VSPATHBASE=C:\Program Files\Microsoft Visual Studio\2022\Professional"
)

echo.
call "%_VSPATHBASE%\Common7\Tools\VsDevCmd.bat"
echo.
echo Cleaning...
"%_VSPATHBASE%\SDK\ScopeCppSDK\vc15\VC\bin\nmake.exe" -f MAKEFILE.NG clean
echo.
echo Building...
"%_VSPATHBASE%\SDK\ScopeCppSDK\vc15\VC\bin\nmake.exe" -f MAKEFILE.NG VER="/DNG_VER_MAJOR=0 /DNG_VER_MINOR=76 /DNG_VER_BUILD=0 /DNG_VER_REVISION=0"
echo.
rcedit-x64.exe PuTTYNG.exe --set-file-version "0.76"
rcedit-x64.exe PuTTYNG.exe --set-product-version "4 RemoteNG"
echo Finished
echo.