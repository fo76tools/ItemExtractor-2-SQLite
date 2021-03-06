<#

    .SYNOPSIS
        Context: PC Gaming | Fallout76 | Tools | ItemExtractor Mod
        Imports a single file to a ItemExtractor SQLite database.

    .DESCRIPTION
        Context: PC Gaming | Fallout76 | Tools | ItemExtractor Mod
        Imports a single file to a ItemExtractor SQLite database.

        1) load the file
        2) interprete needed DB properties (TimeStamp, Account, Character, JSON)
        3) insert data to DB
        4) remove the file

    .PARAMETER ItemExtractorFile
        string | ValueFromPipeline | Position 0 | Mandatory
        The complete path to the ItemExtractor file that should be imported

    .EXAMPLE
        
        pipeline
        "C:\..\Steam\steamapps\common\Fallout76\Data\itemsmod.ini" | .\ItemExtractor-2-SQLite-Import.ps1 
        
        single parameter
        .\ItemExtractor-2-SQLite-Import.ps1 "C:\..\Steam\steamapps\common\Fallout76\Data\itemsmod.ini"

        named parameter
        .\ItemExtractor-2-SQLite-Import.ps1 -ItemExtractorFile "C:\..\Steam\steamapps\common\Fallout76\Data\itemsmod.ini"

    .NOTES
        ItemExtractor Mod can be found at https://www.nexusmods.com/fallout76/mods/698

#>

[CmdletBinding()]

param (
    
    [string]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( { Test-Path $(Resolve-Path $_) })]
    [Parameter( ValueFromPipeline = $true, Position = 0, Mandatory = $true )]
    $ItemExtractorFile
    
)

$BaseDirectory = $PSScriptRoot

# Load common statics and functions
. $BaseDirectory\ItemExtractor-2-SQLite-CommonFunctions.ps1

function Add-ItemExtractorItem {

    param (
        $TimeStamp,
        $Account,
        $Character,
        $Property,
        $Value
    )      

    Write-Host (Get-Date).ToUniversalTime().ToString("u") "Importing:" "Data:" $TimeStamp $Account $Character $Property "..." 
                    
    # Generate an InsertStatement and insert into DB
    $InsertStatement = 'INSERT INTO itemextractor VALUES (' + "'" + ( $TimeStamp | Get-SQLite-SanitizedValues ) + "'," + "'" + ( $Account | Get-SQLite-SanitizedValues ) + "'," + "'" + ( $Character | Get-SQLite-SanitizedValues ) + "'," + "'" + ( $Property | Get-SQLite-SanitizedValues ) + "'," + "'" + ( $Value | Get-SQLite-SanitizedValues ) + "'" + ');'
    $InsertStatement | Get-SQLite-Data | Out-Null

}

function Add-ItemExtractorSourceFile {

    param (
        [Parameter(ValueFromPipeline = $true)]
        $SourceFile
    )      

    # If we can get SourceFile Object
    if ( $SourceFile = Get-Item -Path $SourceFile -ErrorAction SilentlyContinue ) {

        Write-Host (Get-Date).ToUniversalTime().ToString("u") "Importing:" "Source file:" $SourceFile.FullName "..."

        # Get TimeStamp
        $TimeStamp = ($SourceFile.LastAccessTime | Get-Date).ToUniversalTime().ToString("u")

        # Get SourceFile data as object
        $SourceFileData = $SourceFile | Get-Content -Raw | ConvertFrom-Json
    
        # Get a list of all included "characters" (should be only 1 since append mode is dead)
        $characterInventoriesNames = ( $SourceFileData.characterInventories | Get-Member -MemberType NoteProperty ).Name

        $characterInventoriesNames | ForEach-Object {

            $ItemName = $_           
            $ItemData = $SourceFileData.characterInventories.$_

            # Account/Character Data WORKAROUND - switched atm - 2020-12-27
            if ( $ItemData.CharacterInfoData -and $ItemData.AccountInfoData ) {

                if ( $ItemData.AccountInfoData.level ) {

                    # get real ones
                    $RealAccountInfoData = $ItemData.CharacterInfoData.PSObject.Copy()
                    $RealCharacterInfoData = $ItemData.AccountInfoData.PSObject.Copy()
    
                    # set real ones
                    $ItemData.AccountInfoData = $RealAccountInfoData
                    $ItemData.CharacterInfoData = $RealCharacterInfoData   

                }

            }

            # Workaround for priceChecks
            if ( $ItemName -like "priceCheck" ) {

                $ItemData.AccountInfoData = @{}
                $ItemData.AccountInfoData.Name = "priceCheck"

                $ItemData.CharacterInfoData = @{}
                $ItemData.CharacterInfoData.Name = $TimeStamp
                
            }

            # Account / Character
            $Account = $ItemData.AccountInfoData.Name
            $Character = $ItemData.CharacterInfoData.Name

            Write-Host (Get-Date).ToUniversalTime().ToString("u") "Importing:" "Data:" "TimeStamp:" $TimeStamp "Account:" $Account "Character:" $Character "..."
    
            # ItemExtractor "InventoryData"
            $ItemDataPropertyNames = ( $ItemData | Get-Member -MemberType NoteProperty ).Name

            $ItemDataPropertyNames | ForEach-Object {

                # FullGameData
                if ( $_ -like "fullGameData" ) {

                    $fullGameDataPropertyNames = ( $ItemData.fullGameData | Get-Member -MemberType NoteProperty ).Name
                    $fullGameDataPropertyNames | ForEach-Object {
            
                        if ( $ItemDataPropertyNames -contains $_ ) {
                            
                            Write-Host (Get-Date).ToUniversalTime().ToString("u") "Importing:" "Data:" $TimeStamp $Account $Character $_ "present in ItemExtractor - skipped"
    
                        }
    
                        else {

                            # Add to DB
                            $Value = $ItemData.fullGameData.$_ | ConvertTo-Json -Depth 100 -Compress
                            Add-ItemExtractorItem -TimeStamp $TimeStamp -Account $Account -Character $Character -Property $_ -Value $Value

                        }
            
                    }                        
                    
                }
                
                else {

                    $Value = $ItemData.$_ | ConvertTo-Json -Depth 100 -Compress

                    # Add to DB
                    Add-ItemExtractorItem -TimeStamp $TimeStamp -Account $Account -Character $Character -Property $_ -Value $Value                    

                }

            }                       
            
            Write-Host (Get-Date).ToUniversalTime().ToString("u") "Importing:" "Data:" "TimeStamp:" $TimeStamp "Account:" $Account "Character:" $Character "done"
    
        }      

    }
       
    Write-Host (Get-Date).ToUniversalTime().ToString("u") "Importing:" "Source file:" $SourceFile.FullName "done"

    # Remove the file afterwards
    Write-Host (Get-Date).ToUniversalTime().ToString("u") "Removing:" $SourceFile.FullName "..."
    $SourceFile | Remove-Item
    Write-Host (Get-Date).ToUniversalTime().ToString("u") "Removing:" $SourceFile.FullName "done"  

}

# ---

$CreateStatement = 'CREATE TABLE itemextractor(
    TimeStamp TEXT,
    Account TEXT,
    Character TEXT,
    Property TEXT,
    Value JSON
);'

# Start

# Load the connector
Add-SQLite-Connector

# Get a connection
$Connection = Get-ItemExtractor-DatabaseFile | Get-SQLite-Connection

# Open the connection
$Connection.Open()

# If the table doesnt exist: Create it
if ( ! ( Get-SQLite-TableExists -Table "itemextractor" ) ) {
    $CreateStatement | Get-SQLite-Data | Out-Null
}

# Add the file to DB
$ItemExtractorFile | Add-ItemExtractorSourceFile

# Close the connection
$Connection.Close()