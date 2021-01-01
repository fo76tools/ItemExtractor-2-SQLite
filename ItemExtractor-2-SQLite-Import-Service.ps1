<#

    .SYNOPSIS
        Context: PC Gaming | Fallout76 | Tools | ItemExtractor Mod
        Starts the ItemExtractor SQLite Import Service

    .DESCRIPTION
        Context: PC Gaming | Fallout76 | Tools | ItemExtractor Mod
        Starts the ItemExtractor SQLite Import Service

        1) start a filesystemwatcher service: monitor file changes in the given Fallout76DataDirectory
        
        If the filesystemwatcher detects changes:
        1) rename the file
        2) import the file using ItemExtractor-2-SQL-Import.ps1 in a separated process (non-blocking)

    .PARAMETER Fallout76DataDirectory
        string | ValueFromPipeline | Position 0 | Mandatory
        The complete path to the Fallout 76 Data Directory that should be watched at

    .EXAMPLE

        pipeline
        "C:\..\Steam\steamapps\common\Fallout76\Data" | .\ItemExtractor-2-SQLite-Import-Service.ps1

        single parameter
        .\ItemExtractor-2-SQLite-Import-Service.ps1 "C:\..\Steam\steamapps\common\Fallout76\Data"

        named parameter
        .\ItemExtractor-2-SQLite-Import-Service.ps1 -Fallout76DataDirectory "C:\..\Steam\steamapps\common\Fallout76\Data"

    .NOTES
        ItemExtractor Mod can be found at https://www.nexusmods.com/fallout76/mods/698

#>

param (

    [string]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( { Test-Path $(Resolve-Path $_) })]
    [Parameter( ValueFromPipeline = $true, Position = 0, Mandatory = $true )]
    $Fallout76DataDirectory

)

# statics

# the base directory (!also used in the ChangedAction)
$BaseDirectory = $PSScriptRoot

# the FileFilter used for monitoring
$FileFilter ='itemsmod.ini'

# define the action for the filechange
[scriptblock]$ChangedAction={
    
    # check again (right problems?)
    if ( Test-Path $e.FullPath ) {

        # get the SourceFile as object
        $SourceFile = Get-Item -Path $e.FullPath
    
        # get the timestamp
        $TimeStamp = ($SourceFile.LastAccessTime | Get-Date).ToUniversalTime().ToString("u") -replace (" ","-") -replace (":","-")

        # set TemporaryFile
        $TemporaryFile = $SourceFile.FullName + "." + $TimeStamp + ".json"
    
        # rename the file
        Write-Host (Get-Date) "Rename-Item: source file to temporary file:" $SourceFile.FullName "->" $TemporaryFile
        Rename-Item -Path $SourceFile -NewName $TemporaryFile -Force
     
        # send the file to DB
        Write-Host (Get-Date) "Start-Process: Sending temporary file to DB"

        # generate an argument list for Start-Process
        $ArgumentList = @( "-F", ('"'+$BaseDirectory+'\ItemExtractor-2-SQLite-Import.ps1"'), ('"'+$TemporaryFile+'"') )

        # start a separated process to import the file
        Start-Process powershell.exe -NoNewWindow -ArgumentList $ArgumentList | Out-Host  

    }

}

# start the filesystem watcher inside this environment (needs to know $BaseDirectory)
Write-Host (Get-Date) "Starting FileSystemWatcher ..."
& "$BaseDirectory\Start-FileSystemWatcher.ps1" $Fallout76DataDirectory $FileFilter -ChangedAction $ChangedAction