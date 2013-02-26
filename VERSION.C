/*
 * PuTTY version numbering
 */

#define STR1(x) #x
#define STR(x) STR1(x)

#if defined SNAPSHOT

#if defined SVN_REV
#define SNAPSHOT_TEXT STR(SNAPSHOT) ":r" STR(SVN_REV)
#else
#define SNAPSHOT_TEXT STR(SNAPSHOT)
#endif

char ver[] = "Development snapshot " SNAPSHOT_TEXT;
char sshver[] = "PuTTY-Snapshot-" SNAPSHOT_TEXT;

#undef SNAPSHOT_TEXT

#elif defined RELEASE

char ver[] = "Release " STR(RELEASE);
char sshver[] = "PuTTY-Release-" STR(RELEASE);

#elif defined PRERELEASE

char ver[] = "Pre-release " STR(PRERELEASE) ":r" STR(SVN_REV);
char sshver[] = "PuTTY-Prerelease-" STR(PRERELEASE) ":r" STR(SVN_REV);

#elif defined SVN_REV

char ver[] = "Custom build r" STR(SVN_REV) ", " __DATE__ " " __TIME__;
char sshver[] = "PuTTY-Custom-r" STR(SVN_REV);

#elif defined PUTTYNG

#ifndef NG_VER_MAJOR
#define NG_VER_MAJOR 0
#endif
#ifndef NG_VER_MINOR
#define NG_VER_MINOR 0
#endif
#ifndef NG_VER_BUILD
#define NG_VER_BUILD 0
#endif
#ifndef NG_VER_REVISION
#define NG_VER_REVISION 0
#endif
#define RELEASE NG_VER_MAJOR.NG_VER_MINOR
#define RELEASE_FULL RELEASE.NG_VER_BUILD.NG_VER_REVISION
char ver[] = "Release " STR(RELEASE_FULL);
char sshver[] = "PuTTY-Release-" STR(RELEASE);
#else

char ver[] = "Unidentified build, " __DATE__ " " __TIME__;
char sshver[] = "PuTTY-Local: " __DATE__ " " __TIME__;

#endif

/*
 * SSH local version string MUST be under 40 characters. Here's a
 * compile time assertion to verify this.
 */
enum { vorpal_sword = 1 / (sizeof(sshver) <= 40) };
