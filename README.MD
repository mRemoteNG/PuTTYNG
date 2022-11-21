# PuTTYNG

This is a modified version of [PuTTY](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html) from [Simon Tatham](https://www.chiark.greenend.org.uk/~sgtatham/) to be used with [mRemoteNG](https://mremoteng.org/).

| Branch | Build |
|:-----------------: |:-------------------:|
| `Master` | [![Build status](https://ci.appveyor.com/api/projects/status/cv5of42aqanpr7l8?svg=true)](https://ci.appveyor.com/project/mremoteng/puttyng-publish) |

**The following files within the project were modified:**
- BE_ALL_S.C
- CMakeLists.txt
- CMDLINE.C
- PUTTY.H
- version.h
- cmake/platforms/windows.cmake
- WINDOWS/PUTTY.RC
- WINDOWS/VERSION.RC2 
- WINDOWS/WINDOW.C

**New PuTTY Build env**
- Install cmake
- open command prompt
- cd to local copy
- cmake .
- cmake --build . --config Release --target putty

OR

- cd to local copy\WINDOWS
- make22.cmd

Build output: Release\PuTTYNG.exe


**To update PuTTYNG from the original repository:**
- git remote add putty https://git.tartarus.org/simon/putty.git
- git fetch --tags
- git remote update putty
- git checkout master
- git merge tags/0.{version}
- git push master

After that create a new tag from within GitHub to trigger the AppVeyor release build.
