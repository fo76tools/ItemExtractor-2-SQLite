# Commmon Statics used by ItemExtractor-2-SQLite
# Context: PC Gaming | Fallout76 | Tools | ItemExtractor Mod
# ItemExtractor Mod can be found at https://www.nexusmods.com/fallout76/mods/698

$BaseDirectory = $PSScriptRoot
$DatabaseFile = $PSScriptRoot + "\ItemExtractor.sqlite"

$Types = @("playerInventory","stashInventory","AccountInfoData","CharacterInfoData")

$ArrayTypes = @("playerInventory","stashInventory")
$FlatTypes = @("AccountInfoData","CharacterInfoData")