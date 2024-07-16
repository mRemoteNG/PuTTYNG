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
        Write-Host "folder found, deleting to be sure we have clean original version before modifications will be applyed"
        Remove-Item -LiteralPath $workFolder -Verbose -Recurse -Force
    }

Write-Host "Clonning..."
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

#Second check
if (Test-Path -LiteralPath $workFolder) {
    Write-Host "Clone completed, folder exist, starting modification process"
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
    Write-Host "Code block replaced successfully in '$workFile'."
    #===================================================================================================

    #Add mRemoteNG required changes
    $workFile = "$workFolder\putty.h"
    $newContent = 'extern const char *const appname;

    #ifdef PUTTYNG
    int hwnd_parent;
    #define IsZoomed(hWnd) TRUE
    #endif // PUTTYNG'
    (Get-Content $workFile).Replace('extern const char *const appname;', $newContent) | Set-Content $workFile
    Write-Host "Code block replaced successfully in '$workFile'."
    #===================================================================================================

    #Add mRemoteNG required changes
    $workFile = "$workFolder\version.h"
    $setNewVersion = $getLastTag.split(".")[0] + "," + $getLastTag.split(".")[1] + ",0,1"

    #Change version data
    (Get-Content $workFile).Replace('Unidentified build', 'Release '+ $getLastTag + ' mRemoteNG') | Set-Content $workFile
    (Get-Content $workFile).Replace('-Unidentified-Local-Build', '-Release-mRemoteNG-Build') | Set-Content $workFile
    (Get-Content $workFile).Replace('0,0,0,0', $setNewVersion) | Set-Content $workFile
    Write-Host "Code block replaced successfully in '$workFile'."
    #===================================================================================================

    #Add mRemoteNG required changes
    [string]$workFile = "$workFolder\windows\window.c"
    [string]$existingBlockStart = 'char *title = dupprintf("%s Fatal Error", appname);'
    [string]$existingBlockEnd = 'if (conf_get_int(wgs->conf, CONF_close_on_exit) == FORCE_ON)' 
    [string]$newBlock  = '    win_seat_output(seat,true,"\r\n\r\n",4);
        win_seat_output(seat,0,"------------------- ",20);
        win_seat_output(seat,0,title,strlen(title));
        win_seat_output(seat,0," ------------------\r\n",22);
        win_seat_output(seat,0,"- ",2);
        win_seat_output(seat,0,msg,strlen(msg));
        win_seat_output(seat,0,"\r\n\r\n",4);
        //show_mouseptr(wgs, true);
        //MessageBox(wgs->term_hwnd, msg, title, MB_ICONERROR | MB_OK);
        sfree(title);

        '

    # Read the content of the file
    $fileContent = Get-Content -Path $workFile -Raw
    # Find the position of the existing block start
    $startIndex = $fileContent.IndexOf($existingBlockStart) + $existingBlockStart.Length + 1;

    if ($startIndex -ge 0) {
        # Find the end of the existing block (e.g., next empty line or closing brace)
        $endIndex = $fileContent.IndexOf($existingBlockEnd, $startIndex)

        # Remove the existing block
        $modifiedContent = $fileContent.Remove($startIndex, $endIndex - $startIndex)

        # Insert the new block after the existing block start
        $modifiedContent = $modifiedContent.Insert($startIndex, $newBlock)

        # Write the modified content back to the file
        Set-Content -Path $workFile -Value $modifiedContent

        Write-Host "Code block replaced successfully in '$workFile'."
    } else {
        Write-Host "Existing block start not found in the file." -ForegroundColor Red
    }
    #===================================================================================================

    #Add mRemoteNG required changes
    [string]$workFile = "$workFolder\windows\window.c"
    [string]$existingBlockStart = 'char *title = dupprintf("%s Error", appname);'
    [string]$existingBlockEnd = 'sfree(title);' 
    [string]$newBlock  = '    win_seat_output(seat,true,"\r\n\r\n",4);
        win_seat_output(seat,0,"------------------- ",20);
        win_seat_output(seat,0,title,strlen(title));
        win_seat_output(seat,0," ------------------\r\n",22);
        win_seat_output(seat,0,"- ",2);
        win_seat_output(seat,0,msg,strlen(msg));
        win_seat_output(seat,0,"\r\n\r\n",4);
        //show_mouseptr(wgs, true);
        //MessageBox(wgs->term_hwnd, msg, title, MB_ICONERROR | MB_OK);
        '

    # Read the content of the file
    $fileContent = Get-Content -Path $workFile -Raw
    # Find the position of the existing block start
    $startIndex = $fileContent.IndexOf($existingBlockStart) + $existingBlockStart.Length + 1;

    if ($startIndex -ge 0) {
        # Find the end of the existing block (e.g., next empty line or closing brace)
        $endIndex = $fileContent.IndexOf($existingBlockEnd, $startIndex)

        # Remove the existing block
        $modifiedContent = $fileContent.Remove($startIndex, $endIndex - $startIndex)

        # Insert the new block after the existing block start
        $modifiedContent = $modifiedContent.Insert($startIndex, $newBlock)

        # Write the modified content back to the file
        Set-Content -Path $workFile -Value $modifiedContent

        Write-Host "Code block replaced successfully in '$workFile'."
    } else {
        Write-Host "Existing block start not found in the file." -ForegroundColor Red
    }
    #===================================================================================================

    # run cmake
    Write-host "Build has been started"
    try { 
          Start-Process -FilePath "make22.cmd" -Wait 
     }
    catch {
         Write-CustomError -UserMessage 'There was an error' -ErrorObject $_ -FullDetail
    }
    Write-host "Build has been completed"
}
else
{
    Write-Host "Cloning seems not succesfull, please check internet connection"
}
write-host ""