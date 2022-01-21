@echo off
echo.
echo Starting
if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat" (
	call "C:\Program Files\Microsoft Visual Studio\\2022\Community\Common7\Tools\VsDevCmd.bat"
) 
if exist "C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\Tools\VsDevCmd.bat" (
	call "C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\Tools\VsDevCmd.bat"
)
if exist "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\VsDevCmd.bat" (
	call "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\VsDevCmd.bat"
)
echo.
echo Cleaning...
"C:\Program Files\Microsoft Visual Studio\2022\Professional\SDK\ScopeCppSDK\vc15\VC\bin\nmake.exe" -f MAKEFILE.NG clean
echo.
echo Building...
"C:\Program Files\Microsoft Visual Studio\2022\Professional\SDK\ScopeCppSDK\vc15\VC\bin\nmake.exe" -f MAKEFILE.NG VER="/DNG_VER_MAJOR=0 /DNG_VER_MINOR=76 /DNG_VER_BUILD=0 /DNG_VER_REVISION=0"
echo.
echo Finished
echo.