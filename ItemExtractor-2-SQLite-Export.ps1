<#

    .SYNOPSIS
        Context: PC Gaming | Fallout76 | Tools | ItemExtractor Mod
        Exports the most recent ItemExtractor SQLite database entries to files (csv,json,itemextractor json).

    .DESCRIPTION
        Context: PC Gaming | Fallout76 | Tools | ItemExtractor Mod
        Exports the most recent ItemExtractor SQLite database entries to files (csv,json,itemextractor json).
        
        1) generate a mapping of the most recent database entries
        2) export those entries to various formats

    .EXAMPLE

        without paremeters
        .\ItemExtractor-2-SQLite-Export.ps1 

    .NOTES
        ItemExtractor Mod can be found at https://www.nexusmods.com/fallout76/mods/698

#>

[CmdletBinding()]
param ()   

# Load common statics and functions
. .\ItemExtractor-2-SQLite-CommonStatics.ps1
. .\ItemExtractor-2-SQLite-CommonFunctions.ps1

# Start

# Load the connector
Add-SQLite-Connector

# Get a connection
$Connection = $DatabaseFile | Get-SQLite-Connection

# Open the connection
$Connection.Open()

# Create a hashtable to hold the Latest TimeStamp structure
$LatestInventoryTimeStamps = @{}

# Select distinct from DB: only most recent Account, Character, TimeStamp
$StoredDataStatement = 'SELECT DISTINCT "Account","Character","TimeStamp" FROM itemextractor ORDER BY "Account","Character","TimeStamp" DESC;'
$StoredData = $StoredDataStatement | Get-SQLite-Data

# ForEach of this "table rows"
$StoredData.Tables[0] | ForEach-Object {
      
    # ShortHands
    $Account = $_.Account 
    $Character = $_.Character

    # If there is no hashtable for this account - create it
    if ( ! $LatestInventoryTimeStamps.$Account ) { $LatestInventoryTimeStamps.$Account = @{} } 

    # Account\Character=TimeStamp
    $LatestInventoryTimeStamps.$Account.$Character = $_.TimeStamp 

}

# Return the used TimeStamps as JSON
Write-Host "Account\Character:TimeStamps"
$TimeStampsUsed = $LatestInventoryTimeStamps | ConvertTo-Json 
$TimeStampsUsed | Out-File "current-inventories.timestamps.json"
$TimeStampsUsed

# Set an array to hold the output
$Output = @()

# Get all account names to loop through
$Accounts = $LatestInventoryTimeStamps.GetEnumerator().Name

# Loop through all Accounts
foreach ( $Account in $Accounts ) {

    # Get all of this accounts characters data
    $Characters = $LatestInventoryTimeStamps.$Account.GetEnumerator() 

    # ForEach of this Characters "rows"
    $Characters | ForEach-Object {

        # ShortHands
        $Character = $_.Name
        $TimeStamp = $_.Value

        # Select this characters data
        $InventoryStatement = 'SELECT * FROM itemextractor WHERE TimeStamp="' + ( $TimeStamp | Get-SQLite-SanitizedValues ) + '" AND "Character"="' + ( $Character | Get-SQLite-SanitizedValues ) + '" AND "Account"="' + ( $Account | Get-SQLite-SanitizedValues ) + '";'       
        $InventoryData = $InventoryStatement | Get-SQLite-Data

        # add this data to the the output array
        $Output += $InventoryData.Tables[0]

    }

}

# Close the connection
$Connection.Close()

# Flatten it out and export CSV
$CSV = $Output | ConvertTo-Csv -NoTypeInformation
$CSV | Out-File "current-inventories.csv"

# Take the CSV data and make it a PS Object
$PSObject = $CSV | ConvertFrom-Csv

# Create a hashtable to hold the ItemExtractor style output
$ItemExtractorObject = @{}
$ItemExtractorObject.version = 0.8
$ItemExtractorObject.modName = "ItemExtractorMod"
$ItemExtractorObject.characterInventories = @{}

# ForEach of "All Rows"
$PSObject | ForEach-Object {   

    # If Row Type is known
    if ( $Types -contains $_.Type ) {

        # ShortHand
        $Helper = ( $_.Account + " - " + $_.Character )

        # Convert from "Flat JSON"
        $_.JSON = $_.JSON | ConvertFrom-Json

        # Create a hashtable for this account - character
        if (! $ItemExtractorObject.characterInventories.$Helper ) {             
            $ItemExtractorObject.characterInventories.$Helper = @{}
        }

        # if Type is flat
        if ( $FlatTypes -contains $_.Type ) { 
            
            # just set the property
            $ItemExtractorObject.characterInventories.$Helper.($_.Type) = $_.JSON 
        
        }

        # if Type is array
        elseif ( $ArrayTypes -contains $_.Type ) {

            # create an array list
            if (! $ItemExtractorObject.characterInventories.$Helper.($_.Type) ) { $ItemExtractorObject.characterInventories.$Helper.($_.Type) = [System.Collections.ArrayList]@() }

            # add to array list
            $ItemExtractorObject.characterInventories.$Helper.($_.Type).Add( $_.JSON ) | Out-Null

        }

    }

}

# Output the PSObject as json
$PSObject | ConvertTo-Json -Depth 100 -Compress | Out-File "current-inventories.json"

# Output the ItemExtractorObject as json
$ItemExtractorObject | ConvertTo-Json -Depth 100 -Compress | Out-File "current-inventories.itemextractor.json"