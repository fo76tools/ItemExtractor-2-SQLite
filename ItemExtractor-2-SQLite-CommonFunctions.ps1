# Commmon Functions used by ItemExtractor-2-SQLite
# Context: PC Gaming | Fallout76 | Tools | ItemExtractor Mod
# ItemExtractor Mod can be found at https://www.nexusmods.com/fallout76/mods/698

# SQLite specific functions
function Add-SQLite-Connector {

    param (

        [Parameter(ValueFromPipeline = $true)]    
        $ConnectorFileName = "System.Data.SQLite.dll"

    )

    $ConnectorFile = ( Get-ChildItem -Path $BaseDirectory -Filter $ConnectorFileName -Recurse | Select-Object -First 1 ).FullName    
    Add-Type -Path $ConnectorFile

}

function Get-SQLite-Connection {

    param (

        [Parameter(ValueFromPipeline = $true)]
        $SourceFile

    )

    $ConnectionString = ( "Data Source=" + $SourceFile )
    
    $Connection = New-Object -TypeName System.Data.SQLite.SQLiteConnection
    $Connection.ConnectionString = $ConnectionString

    return $Connection

}

function Get-SQLite-Data {
    
    param (

        [Parameter(ValueFromPipeline = $true)]
        $CommandText
        
    )

    $SQL = $Connection.CreateCommand()
    $SQL.CommandText = $CommandText

    $DataAdapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $SQL

    $Data = New-Object System.Data.DataSet

    $DataAdapter.Fill($Data) | Out-Null

    return $Data 

}

function Get-SQLite-SanitizedValues {

    param (
        [Parameter(ValueFromPipeline = $true)]
        $PipelineInput
    )    

    if ( $PipelineInput ) { return $PipelineInput.Replace("'", "''"); }

}

function Get-SQLite-TableExists {

    param (
        [Parameter(ValueFromPipeline = $true)]
        $Table
    )    

    $CheckTableStatement = 'SELECT name FROM sqlite_master WHERE type="table" AND name="' + $Table + '";'

    $CheckTableAnswer = $CheckTableStatement  | Get-SQLite-Data
    
    if ( ($CheckTableAnswer.Tables[0].name -contains "itemextractor") ) {
        return $true
    } 
    else {
        return $false
    }

}

function Get-ItemExtractor-DatabaseFile {
    return $PSScriptRoot + "\ItemExtractor.sqlite"
}



# General Functions
function Get-StringHash {

    param (
        [Parameter(ValueFromPipeline = $true)]
        [string]$PipelineInputString
    )    

    $stringAsStream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.StreamWriter]::new($stringAsStream)

    $writer.write($PipelineInputString)
    $writer.Flush()

    $stringAsStream.Position = 0
    $Hash = (Get-FileHash -InputStream $stringAsStream | Select-Object Hash).Hash

    return $Hash

}