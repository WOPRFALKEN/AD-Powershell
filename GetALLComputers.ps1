param([Parameter(Mandatory=$true)][string] $OutputFile)

$startTime = Get-Date

# Check that the Quest.ActiveRoles.ADManagement snapin is available
if (!(Get-PSSnapin Quest.ActiveRoles.ADManagement -registered -ErrorAction SilentlyContinue)) {
    
    'You need the Quest ActiveRoles AD Management Powershell snapin to use this script'
    "www.quest.com`n"
    'Please install and register this snapin. Exiting...'
    exit 0
    
}

# Add the snapin and don't display an error if it's already added.
# If it's not registered, this will be handled above, so this should succeed.
Add-PSSnapin Quest.ActiveRoles.ADManagement -ErrorAction SilentlyContinue

'Running Get-QADComputer...'

Get-QADComputer -SizeLimit 0 -IncludedProperties LastLogonTimeStamp | 
  Select-Object Name, OSName, OSVersion, OSServicePack, LastLogonTimeStamp |
  #Where-Object { ($_.OSVersion -match '^5\.1') } |
  Sort-Object @{Expression={$_.LastLogonTimeStamp};Ascending=$true} |
  Format-Table -AutoSize -Property Name, OSName, OSVersion, OSServicePack, LastLogonTimeStamp |
  Out-File $outputFile

@"
Start time:  $startTime
End time:    $(Get-Date)
Output file: $outputFile
"@