# PuTTYNG patches

Unified diffs against upstream PuTTY, applied by `PuTTYNG.ps1` with `git apply --3way`
in filename order.

| Patch | Target | Purpose |
| --- | --- | --- |
| `0001-cmdline-mremoteng-options.patch` | `cmdline.c` | Adds the `-hwndparent` and `-auth-plugin` / `-auth_plugin` command line options, guarded by `#ifdef PUTTYNG`. |
| `0002-putty-h-hwnd-parent.patch` | `putty.h`, `windows/window.c` | Declares `hwnd_parent` as `extern` in the header (defined once in `windows/window.c`) and forces `IsZoomed()` to true so the embedded window always behaves as maximised. |
| `0003-window-inline-error-output.patch` | `windows/window.c` | Writes fatal and non-fatal errors into the terminal instead of raising a modal `MessageBox`, which would otherwise block an embedded session. |
| `0004-gitignore-build-artifacts.patch` | `.gitignore` | Ignores the in-source CMake build output (`Release/`, `x64/`, `*.slnx`). |

Base commit these were generated against: `61574e2e` (`0.84-13-g61574e2e`).

## Why patch files rather than string replacement

The previous approach searched for anchor strings such as
`char *title = dupprintf("%s Fatal Error", appname);` and spliced text around them. That
gave no protection when upstream edited a nearby line: the patch either silently did not
apply, or applied in the wrong place.

`git apply --3way` records the pre- and post-image blob SHAs in each patch header. When
the surrounding context has moved, git performs a real three-way merge instead of a
positional match, and a genuine conflict fails loudly with conflict markers rather than
producing a quietly wrong source tree.

Two useful properties follow:

- **Idempotent.** Re-applying an already-applied patch is a no-op, so `PuTTYNG.ps1` is
  safe to re-run over an existing tree.
- **Drift tolerant.** These patches were verified to apply cleanly to `0.83` as well as
  the commit they were cut from.

## Version stamping is not a patch

`version.h` is handled by `Update-VersionHeader` in `PuTTYNG.ps1`, not by a patch file.
Its contents are derived from `git describe` at build time, so they change with every
upstream release and cannot be expressed as a static diff.

## Regenerating a patch

Edit the file in a patched `.\putty` tree, then re-cut the diff. Redirect through `cmd`
rather than `Set-Content`, so git's LF output is preserved verbatim:

```powershell
cmd /c "git -C .\putty diff -- cmdline.c > .\patches\0001-cmdline-mremoteng-options.patch"
```

## Refreshing after an upstream release

If a patch stops applying, `PuTTYNG.ps1` fails with the failing filename. To refresh:

```powershell
git -C .\putty apply --3way .\patches\0003-window-inline-error-output.patch  # resolve conflict markers by hand
cmd /c "git -C .\putty diff -- windows/window.c > .\patches\0003-window-inline-error-output.patch"
```

Then update the base commit noted above.

## Adding a patch

Create the file with the next free number. Order matters only where two patches touch the
same file. Anything ending in `.patch` in this folder is picked up automatically.
