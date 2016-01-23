call "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\Tools\VsDevCmd.bat"
nmake -f MAKEFILE.NG clean
nmake -f MAKEFILE.NG VER="/DNG_VER_MAJOR=0 /DNG_VER_MINOR=0 /DNG_VER_BUILD=0 /DNG_VER_REVISION=0"
