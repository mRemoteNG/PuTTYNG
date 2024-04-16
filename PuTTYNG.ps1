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

clear
write-host "/============================================================================================/"
write-host "/ This will make a some changes in original putty files to make it compatible with mRemoteNG /"
write-host "/============================================================================================/"
write-host ""
$workFolder = "$PSScriptRoot\putty"

#In case its exists, do delete incase of new version
if (Test-Path -LiteralPath $workFolder) {
      Remove-Item -LiteralPath $workFolder -Verbose -Recurse -WhatIf
    }

#clone putty into current directory
try { 
      Start-Process -FilePath "git.exe" -ArgumentList "clone https://git.tartarus.org/simon/putty.git" -Wait 
 }
catch {
     Write-CustomError -UserMessage 'There was an error' -ErrorObject $_ -FullDetail
}

#Get version of last update
cd putty
$getLastTag = git.exe describe --tags --match="*.*" --abbrev=0 HEAD 2>&1
cd ..

$workFile = "$workFolder\version.h"
$setNewVersion = $getLastTag.split(".")[0] + "," + $getLastTag.split(".")[1] + ",0,0"
write-host "Version: " $setNewVersion

#Change version data
(Get-Content $workFile).Replace('Unidentified build', 'Release '+ $getLastTag + ' mRemoteNG') | Set-Content $workFile
(Get-Content $workFile).Replace('-Unidentified-Local-Build', '-Release-mRemoteNG-Build') | Set-Content $workFile
(Get-Content $workFile).Replace('0,0,0,0', $setNewVersion) | Set-Content $workFile

#Add mRemoteNG required changes
$workFile = "$workFolder\cmdline.c"
$newContent = '
#ifdef PUTTYNG
	if (!stricmp(p, "-hwndparent")) {
		RETURN(2);
		hwnd_parent = atoi(value);
		return 2;
	}
#endif

if (!strcmp(p, "-load")) {'
(Get-Content $workFile).Replace('if (!strcmp(p, "-load")) {', $newContent) | Set-Content $workFile

#Add mRemoteNG required changes
$workFile = "$workFolder\putty.h"
$newContent = 'extern const char *const appname;

#ifdef PUTTYNG
int hwnd_parent;
#define IsZoomed(hWnd) TRUE
#endif // PUTTYNG'
(Get-Content $workFile).Replace('extern const char *const appname;', $newContent) | Set-Content $workFile

# run cmake
try { 
      Start-Process -FilePath "make22.cmd" -Wait 
 }
catch {
     Write-CustomError -UserMessage 'There was an error' -ErrorObject $_ -FullDetail
}

Write-host "Build has been completed"
write-host ""