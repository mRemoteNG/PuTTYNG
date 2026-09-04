# Changelog
All notable changes to this project will be documented in this file.

## [0.84.0.1]

### Added
- `patches/` directory holding the mRemoteNG source changes as unified diffs, applied
  with `git apply --3way`. See `patches/README.md` for what each patch does and how to
  refresh one after an upstream release.
- `PuTTYNG.ps1` parameters: `-SkipClone` (rebuild the existing tree without re-cloning),
  `-PuttyRef` (pin the upstream tag/branch/commit for reproducible builds),
  `-PatchFolder`, `-Configuration` and `-OutputName`.
- GitHub Actions workflow (`.github/workflows/build.yml`) that builds `PuTTYNG.exe` on
  `windows-latest` by running `PuTTYNG.ps1`, so CI and local builds share one definition.
  Every run uploads the exe and a SHA256 checksum as a build artifact; pushing a `v*`
  tag additionally publishes them as a GitHub release. Manual runs accept an upstream
  PuTTY ref. The workflow asserts the option strings are present in the built binary,
  because the mRemoteNG changes sit behind `#ifdef PUTTYNG` and a build that fails to
  define it still succeeds while silently producing stock PuTTY.

### Changed
- Merged `make22.cmd` into `PuTTYNG.ps1`; the build is now a single entry point.
- Visual Studio is located with `vswhere` instead of three hardcoded VS 2022 paths, so
  any edition of VS 2017 or later with the C++ toolset works. Builds no longer break
  when the installed Visual Studio version changes.
- Dropped the pinned `-G "Visual Studio 17 2022"` generator; CMake now selects the
  newest installed Visual Studio generator itself.
- CMake and Ninja are taken from the Visual Studio install via `VsDevCmd.bat`, so no
  separate CMake installation is required.
- Source changes are applied as patch files rather than by matching anchor strings in
  PowerShell. A three-way apply survives upstream moving the surrounding code, is
  idempotent, and fails loudly with conflict markers instead of silently misapplying.
  The patches were verified to apply cleanly to both 0.83 and 0.84.
- `.gitignore` now covers the in-source CMake build output (`Release/`, `x64/`, `*.slnx`).
- README refreshed: the build badge now points at GitHub Actions instead of AppVeyor, and
  the build instructions match the current script. The old "install cmake, run `cmake .`"
  steps were misleading, as a manual build without `/DPUTTYNG` silently produces stock
  PuTTY. Adds download and checksum verification instructions, the script parameters, and
  a breakdown of which files are changed by patch versus by the script.

### Fixed
- The build reported `InternalName` and `OriginalFilename` as `PuTTY` rather than
  `PuTTYNG`. PuTTY's version resource takes both from the `APPNAME` macro, which
  `windows/putty.rc` defines as `"PuTTY"` before `version.rc2` includes `version.h`;
  the script never overrode it. mRemoteNG's `PuttyTypeDetector` identifies PuTTYNG by
  `InternalName`, so builds were misdetected as stock PuTTY and embedded mode
  (`-hwndparent`) did not activate. `version.h` now undefines and redefines `APPNAME`,
  and CI asserts the resulting `InternalName`. Diagnosed by @robertpopa22 in
  mRemoteNG/PuTTYNG#7.
- Releases shipped the executable without PuTTY's licence. PuTTY is MIT licensed, which
  requires the copyright and permission notice to accompany every copy, so the upstream
  `LICENCE` is now published alongside the binary as `PuTTY-LICENCE.txt`. The build fails
  rather than publishing a download without it, and `SHA256SUMS.txt` now covers every
  file shipped rather than just the executable.
- `PUTTYNG` was defined only by `$env:CL`. The accompanying `$env:CMAKE_C_FLAGS` and
  `$env:CMAKE_CXX_FLAGS` assignments did nothing, as CMake does not read those as
  environment variables.
- Build failures were swallowed. `Start-Process -Wait` does not set `$LASTEXITCODE`, so
  a failed compile still reported "Build has been completed" and exited 0. Every step is
  now checked and the script exits non-zero on failure.
- Two malformed line endings in `windows/window.c`. The patch logic advanced past the
  anchor by exactly one character, which consumed the LF of a CRLF pair and left a bare
  CR. Git will not normalise a file containing lone CRs, so this also made the whole
  5,957-line file appear modified in every diff.
- The "existing block start not found" guard could never fire: `IndexOf` returns `-1`,
  but the anchor length was added to it before the `>= 0` test. A missing anchor
  produced an `ArgumentOutOfRangeException` instead of the intended message.
- Re-running the patch step duplicated the `#ifdef PUTTYNG` blocks in `cmdline.c` and
  `putty.h`, because each replacement re-emitted its own anchor.
- A locked `putty` folder was reported only as a non-terminating error, so the script
  continued and failed later with a confusing "destination path already exists" from
  `git clone`. It now stops with an actionable message.
- MSBuild node reuse kept worker processes alive holding handles to the build tree,
  which could block the delete-and-re-clone at the start of the next run.
  `MSBUILDDISABLENODEREUSE` is now set.
- `clear` threw "The handle is invalid" when output was redirected to a file.
- The final rename failed if `PuTTYNG.exe` already existed from a previous build.

### Removed
- `make22.cmd`, superseded by `PuTTYNG.ps1`.

## [0.81.0.1]

### Updated
- #243: Suppress pop-up windows creation in case of error or fatal error
