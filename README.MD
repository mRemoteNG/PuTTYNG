PuTTYNG specific file changes:
- BE_ALL_S.C
- CMDLINE.C
- PUTTY.H
- WINDOWS/PUTTY.RC
- WINDOWS/VERSION.RC2 
- WINDOWS/WINDOW.C

MAKEFILE.NG (merge changes from Makefile.vc):
- MAKEFILE = MAKEFILE.NG
- rename putty.exe to puttyng.exe
- change the "all" target to only build puttyng.exe

To update PuTTYNG from the original repository:
- git remote add putty https://git.tartarus.org/simon/putty.git
- git fetch --tags
- git remote update putty
- git checkout master
- git merge tags/0.76