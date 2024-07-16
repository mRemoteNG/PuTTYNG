# PuTTYNG

This is a modified version of [PuTTY](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html) from [Simon Tatham](https://www.chiark.greenend.org.uk/~sgtatham/) to be used with [mRemoteNG](https://mremoteng.org/).

| Branch | Build |
|:-----------------: |:-------------------:|
| `Master` | [![Build status](https://ci.appveyor.com/api/projects/status/cv5of42aqanpr7l8?svg=true)](https://ci.appveyor.com/project/mremoteng/puttyng-publish) |

After reviewing changes I decide to dismiss putty files from our repository as almost no changes in them are done
some small changes now are made by script, in feature will try to avoid even such...

So just run PuTTYNG.ps1 and it will do all for you! 

Script will clone https://git.tartarus.org/simon/putty.git and then do changes mentioned below:

**The following files within the project will be modified:**
- CMDLINE.C
- PUTTY.H
- version.h
- window.c

**New PuTTY Build env**
- Install cmake
- open command prompt
- cd to local copy of putty
- cmake .
- cmake --build . --config Release --target putty

OR

- run PUTTYNG.ps1

Build output will be in: putty\Release\PuTTYNG.exe
