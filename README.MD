# PuTTYNG

This is a modified version of [PuTTY](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html) from [Simon Tatham](https://www.chiark.greenend.org.uk/~sgtatham/) to be used with [mRemoteNG](https://mremoteng.org/).

| Branch | Build |
|:-----------------: |:-------------------:|
| `master` | [![Build PuTTYNG](https://github.com/mRemoteNG/PuTTYNG/actions/workflows/build.yml/badge.svg?branch=master)](https://github.com/mRemoteNG/PuTTYNG/actions/workflows/build.yml) |

## Download

Prebuilt binaries are published on the [Releases](https://github.com/mRemoteNG/PuTTYNG/releases) page,
alongside a `SHA256SUMS.txt` you can check the download against:

```powershell
Get-FileHash .\PuTTYNG-<version>-x64.exe -Algorithm SHA256
```

The binary is not code signed, so Windows SmartScreen will warn the first time you run it.

Each release also carries `PuTTY-LICENCE.txt`. See [Licence](#licence) below.

## Building it yourself

Upstream PuTTY is not vendored into this repository. The build clones it fresh and applies
the mRemoteNG changes as patches, so there is very little to keep in sync here.

**Requirements**

- Visual Studio 2017 or later with the **Desktop development with C++** workload
  (any edition, including the free Build Tools). It is found automatically via `vswhere`.
- Git.

CMake and Ninja come from the Visual Studio install, so no separate CMake is needed.

**Run it**

```powershell
.\PuTTYNG.ps1
```

Output lands in `putty\Release\PuTTYNG.exe`.

| Parameter | Purpose |
| --- | --- |
| `-PuttyRef` | Upstream tag/branch/commit to build, e.g. `0.84`. Pin this for a reproducible build. |
| `-SkipClone` | Reuse the existing `.\putty` folder instead of deleting and re-cloning it. |
| `-Configuration` | CMake configuration. Defaults to `Release`. |
| `-OutputName` | Name for the built exe. Defaults to `PuTTYNG.exe`. |

Note that without `-SkipClone` the `.\putty` folder is **deleted and re-cloned**, so any local
edits in it are lost.

## What the script does

1. Clones https://git.tartarus.org/simon/putty.git.
2. Applies every patch in [`patches/`](patches/) with `git apply --3way`.
3. Stamps the mRemoteNG version strings into `version.h`, derived from the upstream tag.
4. Builds the `putty` target with `/DPUTTYNG` defined.

The clone is deliberately not shallow: `git describe` needs the tag history for step 3, and
`git apply --3way` needs the pre-image blobs to fall back to a three-way merge when upstream
has moved. A full clone takes about 15 seconds.

**Files changed in the PuTTY tree:**

| File | How | What |
| --- | --- | --- |
| `cmdline.c` | patch | Adds the `-hwndparent` and `-auth-plugin` / `-auth_plugin` options. |
| `putty.h` | patch | Declares `hwnd_parent` as `extern` (defined once in `windows/window.c`), forces `IsZoomed()` true so the embedded window behaves as maximised. |
| `windows/window.c` | patch | Defines `hwnd_parent`; writes errors into the terminal instead of a modal `MessageBox`, which would otherwise block an embedded session. |
| `.gitignore` | patch | Ignores the in-source CMake build output. |
| `version.h` | script | Version strings, derived from the upstream tag at build time. |

All the C changes sit behind `#ifdef PUTTYNG`, so a build without that define produces stock
PuTTY. See [`patches/README.md`](patches/README.md) for how to refresh a patch after an
upstream release.

## Continuous integration

[`.github/workflows/build.yml`](.github/workflows/build.yml) builds on `windows-latest` by
running `PuTTYNG.ps1`, so CI and local builds share one definition. Every run uploads the exe
and its checksum as a build artifact; pushing a `v*` tag publishes them as a release. The
workflow also asserts the mRemoteNG option strings are present in the built binary, because a
build that loses the `PUTTYNG` define would otherwise succeed while silently producing stock
PuTTY.

A manual build can be run from the Actions tab, optionally against a specific upstream PuTTY ref.

## Licence

PuTTY is MIT licensed, copyright Simon Tatham and contributors. The MIT licence requires the
copyright and permission notice to accompany every copy of the software, so releases ship
`PuTTY-LICENCE.txt` (the upstream `LICENCE` file, verbatim) next to the executable. Keep the two
together if you redistribute the binary.

When building locally the same text is at `putty\LICENCE` in the cloned tree.
