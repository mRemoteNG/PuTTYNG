#Requires -Version 5.1
<#
.SYNOPSIS
    Clones upstream PuTTY, applies the mRemoteNG patches, and builds PuTTYNG.exe.
.DESCRIPTION
    This is the single entry point for producing PuTTYNG.exe. It replaces the old
    two-script arrangement (PuTTYNG.ps1 + make22.cmd); the MSVC toolchain discovery
    and CMake invocation that used to live in make22.cmd are now the
    Import-VisualStudioEnvironment and Invoke-PuttyBuild functions below.

    The source changes live in .\patches as real unified diffs and are applied with
    'git apply --3way'. That replaces the previous approach of matching anchor strings
    in PowerShell, which broke silently whenever upstream edited a nearby line. A
    three-way apply uses the blob SHAs recorded in each patch, so patches keep applying
    across upstream drift, and re-applying an already-applied patch is a no-op.

    The Visual Studio install is located with vswhere rather than hardcoded paths, so
    any edition of VS 2017 or later that has the C++ toolset will work. VsDevCmd.bat
    also puts VS's bundled CMake and Ninja on PATH, so no separate CMake install is
    needed.

    WARNING: unless -SkipClone is given, the .\putty folder is DELETED and re-cloned.
    Any local edits in .\putty will be lost.
.PARAMETER SkipClone
    Reuse the existing .\putty folder instead of deleting and re-cloning it. Patching
    still runs, but is a no-op on an already-patched tree.

    Note that this reuses the existing build tree too, so object files compiled without
    /DPUTTYNG (for example by an older build) will be reused if their source has not
    changed, silently producing a binary with the PUTTYNG blocks missing. If in doubt,
    delete .\putty\Release and the *.dir folders, or just run without -SkipClone.
.PARAMETER PuttyRef
    Optional upstream tag, branch or commit to check out after cloning, e.g. '0.84'.
    Defaults to whatever the clone lands on. Pin this for reproducible builds.
.PARAMETER PatchFolder
    Folder holding the *.patch files, applied in filename order. Defaults to .\patches.
.PARAMETER Configuration
    CMake build configuration. Defaults to Release.
.PARAMETER OutputName
    Filename to rename the built putty.exe to. Defaults to PuTTYNG.exe.
.EXAMPLE
    .\PuTTYNG.ps1
    Full run: clone upstream, patch, build, produce .\putty\Release\PuTTYNG.exe
.EXAMPLE
    .\PuTTYNG.ps1 -PuttyRef 0.84
    Build reproducibly against the 0.84 tag.
.EXAMPLE
    .\PuTTYNG.ps1 -SkipClone
    Rebuild the existing tree without re-cloning it.
#>
[CmdletBinding()]
param(
    [switch]$SkipClone,

    [string]$PuttyRef,

    [string]$PatchFolder = "$PSScriptRoot\patches",

    [ValidateSet('Release', 'Debug', 'RelWithDebInfo', 'MinSizeRel')]
    [string]$Configuration = 'Release',

    [string]$OutputName = 'PuTTYNG.exe'
)

Function Write-CustomError()
{
<#
.Synopsis
   Displays error information to the console
.DESCRIPTION
    Writes property information from the current [ErrorRecord] object
    in the pipeline to the console
.EXAMPLE
   Write-CustomError -UserMessage "Exception occurred at memory location $x" -ErrorObject $_
.EXAMPLE
   Write-CustomError -UserMessage "Exception occurred at memory location $x" -ErrorObject $_ -FullDetail
.INPUTS
   $Error[0]
.OUTPUTS
   [String]
.COMPONENT
   adminkitMiscTools
.FUNCTIONALITY
   General Utility
#>
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$False)]
        [String]$UserMessage,

        [Parameter(Mandatory=$True)]
        [Object]$ErrorObject,

        [Parameter(Mandatory=$false)]
        [Switch]$FullDetail
    )

    BEGIN
    {}
    PROCESS
    {
        if($UserMessage) {
             Write-Host "`nERROR: $UserMessage" -ForegroundColor Red
        }

        $ErrorData = @()
        if($FullDetail)
        {
            $ErrorData = $ErrorData + [PSCustomObject]@{AccountUsed=$ENV:USERNAME;
                                            ExceptionMessage=$ErrorObject.ToString();
                                            CategoryInfo=$ErrorObject.CategoryInfo;
                                            ExceptionType=$ErrorObject.Exception.GetType();
                                            ErrorDetails=$ErrorObject.ErrorDetails;
                                            FullyQualifiedErrorId=$ErrorObject.FullyQualifiedErrorId;
                                            InvocationInfo=$ErrorObject.InvocationInfo;
                                            PipelineIterationInfo=$ErrorObject.PipelineIterationInfo;
                                            ScriptStackTrace=$ErrorObject.ScriptStackTrace
                                            TargetObject=$ErrorObject.TargetObject;
                                            }
        }
        return $ErrorData
    }
    END
    {}
}

#===================================================================================================
# Source patching
#===================================================================================================

Function Invoke-PatchSet()
{
<#
.SYNOPSIS
    Applies every *.patch in a folder to a PuTTY source tree, in filename order.
.DESCRIPTION
    Uses 'git apply --3way'. When a patch no longer applies cleanly by context, git
    falls back to a real three-way merge against the blob SHAs recorded in the patch
    header, which is why these survive upstream moving the surrounding code. The same
    property makes re-application a no-op, so this is safe to run over an already
    patched tree.

    A patch that genuinely conflicts makes git exit non-zero and leave conflict markers
    in the file; that is turned into a terminating error here rather than being allowed
    through into a broken build.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$WorkFolder,
        [Parameter(Mandatory=$true)][string]$PatchFolder
    )

    if (-not (Test-Path -LiteralPath $PatchFolder)) {
        throw "Patch folder '$PatchFolder' not found."
    }

    $patches = @(Get-ChildItem -LiteralPath $PatchFolder -Filter '*.patch' | Sort-Object Name)
    if ($patches.Count -eq 0) {
        throw "No .patch files found in '$PatchFolder'."
    }

    foreach ($patch in $patches) {
        $output = & git.exe -C $WorkFolder apply --3way -- $patch.FullName 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to apply '$($patch.Name)':`n$($output -join [Environment]::NewLine)`n`nThe patch probably needs refreshing against current upstream - see patches\README.md."
        }
        Write-Host "  Applied $($patch.Name)"
    }

    Write-Host "  $($patches.Count) patch(es) applied."
}

Function Update-VersionHeader()
{
<#
.SYNOPSIS
    Stamps the mRemoteNG version strings into version.h.
.DESCRIPTION
    Deliberately not a patch file: these values are derived from the upstream tag at
    build time, so they differ with every release and cannot be expressed as a static
    diff. Skips itself if version.h has already been stamped.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$WorkFolder,
        [Parameter(Mandatory=$true)][string]$VersionTag
    )

    $workFile = Join-Path $WorkFolder 'version.h'
    $content = Get-Content -LiteralPath $workFile -Raw
    $changed = $false

    # The version strings and the APPNAME override are guarded separately, so a tree
    # stamped by an older revision of this script still picks up the APPNAME fix.
    if ($content.Contains('mRemoteNG')) {
        Write-Host "  version.h version strings already stamped, skipping."
    }
    elseif (-not $content.Contains('Unidentified build')) {
        throw "Anchor 'Unidentified build' not found in '$workFile' - upstream has changed the version header."
    }
    else {
        $setNewVersion = $VersionTag.split(".")[0] + "," + $VersionTag.split(".")[1] + ",0,1"

        #Change version data
        $content = $content.Replace('Unidentified build', 'Release ' + $VersionTag + ' mRemoteNG')
        $content = $content.Replace('-Unidentified-Local-Build', '-Release-mRemoteNG-Build')
        $content = $content.Replace('0,0,0,0', $setNewVersion)
        $changed = $true
        Write-Host "  version.h stamped as 'Release $VersionTag mRemoteNG'."
    }

    # PuTTY's version resource takes InternalName and OriginalFilename from the APPNAME
    # macro (windows/version.rc2). windows/putty.rc defines APPNAME as "PuTTY" before
    # putty-common.rc2 -> version.rc2 pulls in version.h, so redefining it here lands
    # between that definition and its use.
    #
    # This matters because mRemoteNG's PuttyTypeDetector identifies PuTTYNG by
    # InternalName containing "PuTTYNG", and uses that to enable embedded mode
    # (-hwndparent). Without the override the build reports InternalName "PuTTY" and is
    # misdetected as stock PuTTY. #undef first so the redefinition is not a compiler
    # warning. Thanks to @robertpopa22 for diagnosing this (mRemoteNG/PuTTYNG#7).
    if ($content.Contains('#define APPNAME "PuTTYNG"')) {
        Write-Host "  version.h already overrides APPNAME, skipping."
    }
    else {
        $newline = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
        $content = $content.TrimEnd("`r", "`n") + $newline + $newline +
            '/* Override APPNAME so the version resource reports InternalName = PuTTYNG.' + $newline +
            '   mRemoteNG detects PuTTYNG by that field to enable embedded mode. */' + $newline +
            '#undef APPNAME' + $newline +
            '#define APPNAME "PuTTYNG"' + $newline
        $changed = $true
        Write-Host "  version.h APPNAME overridden to 'PuTTYNG'."
    }

    if ($changed) {
        # -NoNewline: $content already carries its own trailing newline.
        Set-Content -LiteralPath $workFile -Value $content -NoNewline
    }
}

#===================================================================================================
# Build helpers (these replace the old make22.cmd)
#===================================================================================================

Function Import-VisualStudioEnvironment()
{
<#
.SYNOPSIS
    Locates a Visual Studio install with the C++ toolset and imports its developer
    environment into the current PowerShell session.
.DESCRIPTION
    vswhere.exe ships with every Visual Studio since 2017 and always lives at the same
    path, so it is a version-independent way to find the install. VsDevCmd.bat can only
    set variables for the cmd.exe process that runs it, so it is invoked via cmd.exe and
    the resulting environment block is harvested and copied into this session. That puts
    cl.exe, cmake.exe and ninja.exe on PATH.
#>
    [CmdletBinding()]
    param(
        [string]$Architecture = 'amd64'
    )

    $installHint = 'winget install --id Microsoft.VisualStudio.2022.BuildTools --override "--quiet --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"'

    $vsWhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vsWhere)) {
        throw "Cannot find vswhere.exe at '$vsWhere' - is Visual Studio installed?`nTo install the build tools:`n  $installHint"
    }

    # -requires filters out installs that lack the C++ toolset (e.g. a VS install with
    # only the .NET workload), which would otherwise be found but could not compile.
    $installPath = & $vsWhere -latest -products * `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -property installationPath | Select-Object -First 1

    if (-not $installPath) {
        throw "No Visual Studio install with the C++ toolset was found.`nAdd the 'Desktop development with C++' workload, or install the build tools:`n  $installHint"
    }

    $devCmd = Join-Path $installPath 'Common7\Tools\VsDevCmd.bat'
    if (-not (Test-Path -LiteralPath $devCmd)) {
        throw "Found Visual Studio at '$installPath' but '$devCmd' is missing."
    }

    Write-Host "Using Visual Studio at: $installPath"

    # Run VsDevCmd, then dump the environment it produced. The marker separates
    # VsDevCmd's own banner from the variables we want.
    $marker = '__VSDEVCMD_ENV_FOLLOWS__'
    $output = & cmd.exe /c "call `"$devCmd`" -arch=$Architecture -host_arch=$Architecture >nul 2>&1 && echo $marker && set"

    $reachedMarker = $false
    $imported = 0
    foreach ($line in $output) {
        # cmd's "echo $marker && set" emits the marker with a trailing space, so trim.
        if (-not $reachedMarker) {
            if ($line.Trim() -eq $marker) { $reachedMarker = $true }
            continue
        }
        # Names like 'ProgramFiles(x86)' are not valid in the env: PSDrive syntax,
        # so set them through the .NET API instead.
        if ($line -match '^([^=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2])
            $imported++
        }
    }

    if (-not $reachedMarker) {
        throw "VsDevCmd.bat failed to initialise the developer environment."
    }

    Write-Verbose "Imported $imported environment variables from VsDevCmd.bat"
}

Function Invoke-PuttyBuild()
{
<#
.SYNOPSIS
    Configures and builds the putty target, then renames the result.
.DESCRIPTION
    No -G generator is passed, so CMake selects the newest Visual Studio generator it
    finds. Hardcoding one (as make22.cmd did with "Visual Studio 17 2022") breaks every
    time the installed Visual Studio version changes.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SourceDir,

        [string]$Configuration = 'Release',

        [string]$OutputName = 'PuTTYNG.exe'
    )

    # The CL variable is prepended to every cl.exe command line, which is how the
    # PUTTYNG define reaches the #ifdef blocks introduced by the patches.
    # (Setting CMAKE_C_FLAGS as an environment variable does nothing - CMake does not
    # read it - so that is deliberately not attempted here.)
    $env:CL = ('/DPUTTYNG ' + $env:CL).Trim()

    # MSBuild keeps worker nodes alive for about 15 minutes after a build to speed up
    # the next one, and those processes hold open handles to the build tree. That makes
    # the delete-and-re-clone at the start of the *next* run fail with "it is in use",
    # so opt out of node reuse.
    $env:MSBUILDDISABLENODEREUSE = '1'

    Push-Location -LiteralPath $SourceDir
    try {
        Write-Host "`nConfiguring..."
        & cmake -A x64 .
        if ($LASTEXITCODE -ne 0) { throw "CMake configuration failed (exit code $LASTEXITCODE)" }

        Write-Host "`nBuilding..."
        & cmake --build . --config $Configuration --target putty
        if ($LASTEXITCODE -ne 0) { throw "Build failed (exit code $LASTEXITCODE)" }

        Write-Host "`nRenaming..."
        $builtExe = Join-Path $SourceDir "$Configuration\putty.exe"
        if (-not (Test-Path -LiteralPath $builtExe)) {
            throw "Expected '$builtExe' was not produced by the build."
        }

        $targetExe = Join-Path $SourceDir "$Configuration\$OutputName"
        # Rename-Item fails outright if the destination already exists.
        if (Test-Path -LiteralPath $targetExe) { Remove-Item -LiteralPath $targetExe -Force }
        Rename-Item -LiteralPath $builtExe -NewName $OutputName

        # Deliberately no return value: cmake writes to the success stream, so anything
        # returned here would arrive mixed in with the entire build log.
    }
    finally {
        Pop-Location
    }
}

#===================================================================================================
# Main
#===================================================================================================

# Clear-Host throws if there is no real console (e.g. output redirected to a file).
try { Clear-Host } catch { }
write-host "/============================================================================================/"
write-host "/ This will make a some changes in original putty files to make it compatible with mRemoteNG /"
write-host "/============================================================================================/"
write-host ""
$workFolder = "$PSScriptRoot\putty"

if ($SkipClone) {
    if (-not (Test-Path -LiteralPath $workFolder)) {
        Write-Host "-SkipClone was given but '$workFolder' does not exist. Run without -SkipClone first." -ForegroundColor Red
        exit 1
    }
    Write-Host "-SkipClone given: reusing the existing tree in '$workFolder'."
}
else {
    #In case its exists, do delete incase of new version
    if (Test-Path -LiteralPath $workFolder) {
        Write-Host "folder found, deleting to be sure we have clean original version before modifications will be applyed"
        Remove-Item -LiteralPath $workFolder -Recurse -Force -ErrorAction SilentlyContinue

        # A locked folder is only a non-terminating error, so without this re-check the
        # script carries on and fails further down with a confusing "destination path
        # already exists" from git clone.
        if (Test-Path -LiteralPath $workFolder) {
            Write-Host "Could not delete '$workFolder' - it is in use." -ForegroundColor Red
            Write-Host "Close whatever is holding it open (a shell whose current directory is inside it, an editor, or Explorer) and try again," -ForegroundColor Red
            Write-Host "or run with -SkipClone to build the existing tree in place." -ForegroundColor Red
            write-host ""
            exit 1
        }
    }

    Write-Host "Clonning..."
    #clone putty into current directory
    try {
          & git.exe clone https://git.tartarus.org/simon/putty.git $workFolder
          if ($LASTEXITCODE -ne 0) { throw "git clone failed (exit code $LASTEXITCODE)" }
     }
    catch {
         Write-CustomError -UserMessage 'There was an error' -ErrorObject $_ -FullDetail
    }

    #Second check
    if (-not (Test-Path -LiteralPath $workFolder)) {
        Write-Host "Cloning seems not succesfull, please check internet connection"
        write-host ""
        exit 1
    }

    if ($PuttyRef) {
        Write-Host "Checking out upstream ref '$PuttyRef'..."
        & git.exe -C $workFolder checkout --quiet $PuttyRef
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Could not check out '$PuttyRef'." -ForegroundColor Red
            exit 1
        }
    }
}

#Get version of last update
[string]$getLastTag = & git.exe -C $workFolder describe --tags --match="*.*" --abbrev=0 HEAD | Select-Object -First 1
if ($LASTEXITCODE -ne 0 -or -not $getLastTag) {
    Write-Host "Could not determine the upstream version tag." -ForegroundColor Red
    exit 1
}

Write-Host "Starting modification process (upstream version $getLastTag)"
try {
    Invoke-PatchSet -WorkFolder $workFolder -PatchFolder $PatchFolder
    Update-VersionHeader -WorkFolder $workFolder -VersionTag $getLastTag
}
catch {
    Write-CustomError -UserMessage 'There was an error' -ErrorObject $_ -FullDetail
    Write-Host $_.Exception.Message -ForegroundColor Red
    write-host ""
    exit 1
}

# Build
Write-host "`nBuild has been started"
try {
    Import-VisualStudioEnvironment
    Invoke-PuttyBuild -SourceDir $workFolder -Configuration $Configuration -OutputName $OutputName
    $producedExe = Join-Path $workFolder "$Configuration\$OutputName"
    Write-host "Build has been completed"
    Write-Host "Finished: $producedExe" -ForegroundColor Green
}
catch {
    Write-CustomError -UserMessage 'There was an error' -ErrorObject $_ -FullDetail
    Write-Host $_.Exception.Message -ForegroundColor Red
    write-host ""
    exit 1
}

write-host ""
